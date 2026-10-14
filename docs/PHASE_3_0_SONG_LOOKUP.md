# Fase 3.0 — Song Lookup Architecture

Puerto de dominio `MusicIdentity → Song` que no asume que la canción sea
local. **No hay ningún proveedor, HTTP, búsqueda ni catálogo remoto.** No se
tocó SQLite, el esquema, `FavoritesRepository`, `PlaylistsRepository`, el
Player, `PlaybackResource`, `ArtworkReference`, `SongMatcher`, `SongReference`
ni la UI visual.

## 1. Problema actual

Favoritos y playlists guardan `source + external_id` (2.4), pero **resolver**
esas entradas a canciones solo sabe mirar la biblioteca local:
`GetFavoriteSongs.call(List<LocalSong>)` y `GetPlaylistSongs.call(id,
List<LocalSong>)` construyen un `SongMatcher` sobre esa lista. Una entrada de
otra fuente nunca se resolvería, y peor: el `SongMatcher` la intentaría
reencontrar por título/ruta contra canciones **locales**.

## 2. Auditoría

| Pieza | Dónde asume lo local | Qué debería ser identidad → Song |
|---|---|---|
| `GetFavoriteSongs` | `List<LocalSong>` + `SongMatcher` para **todas** las entradas | resolución por identidad de cualquier fuente |
| `GetPlaylistSongs` | ídem | ídem, conservando orden y duplicados |
| `favoriteSongsProvider`, `playlistItemsProvider` | pasan `LibraryLoaded.songs` | deben seguir pasando la biblioteca solo para el reencuentro local |
| `SongMatcher` | `List<LocalSong>`, ruta/título | **se queda local** (política de la fuente local) |
| `SongReference` (`FavoriteEntry`, `PlaylistEntry`) | `path` es un respaldo local opcional | identidad + respaldo: sigue siendo necesaria |
| `FavoritesRepository`, `PlaylistsRepository`, SQLite | ninguna (solo identidad) | sin cambios |
| Resolución actual | **contra la biblioteca filtrada** (`GetSongs`: sin audios cortos ni carpetas excluidas); un fallo de lectura de la biblioteca llega a la UI como estado de error | debe conservarse |

Dos hechos del código condicionan el diseño: (1) la resolución local es contra
la biblioteca **filtrada**, no contra MediaStore crudo; (2) hoy el reencuentro
(`SongMatcher`) también *reenlaza* (`relink`) la identidad guardada.

## 3. Contrato elegido

```dart
abstract interface class SongLookup {
  Future<SongLookupResult> findAll(Iterable<MusicIdentity> identities);
}

final class SongLookupResult {
  Map<MusicIdentity, Song> found;   // la fuente la tiene
  Set<MusicIdentity> missing;       // la fuente está, pero no la tiene
  Set<MusicIdentity> unsupported;   // ninguna fuente registrada la resuelve
}
```
Cada identidad pedida cae en **exactamente un** cubo. Un fallo transitorio
**no** es un cubo: se lanza `SongLookupFailure(source, cause)`.

## 4. Alternativas

| | A. `Future<Song?> find(id)` | B. `Future<Song> find(id)` + excepción de ausencia | C. Router por fuente (sobre A o B) | **D. Lote con resultado de 3 cubos (elegida)** |
|---|---|---|---|---|
| Ausencia | `null`: no distingue «borrada» de «fuente desconocida» ni de error | excepción por flujo normal (la ausencia es frecuente: SD desmontada) | hereda | cubo `missing` |
| Errores | o `null` (oculta fallos) o excepción mezclada con ausencia | mezcla ausencia y fallo en la misma jerarquía | hereda | `SongLookupFailure` aparte |
| Favoritos | N consultas; con `LocalSongLookup` cada una exigiría la biblioteca (N lecturas o caché oculta) | ídem + `try/catch` por entrada | — | una llamada por lote |
| Playlists | ídem | ídem | — | ídem; los duplicados se resuelven una vez |
| Proveedores futuros | N llamadas de red | ídem | permite registrar fuentes | un proveedor puede usar su API «varias pistas» |
| Fuente desconocida | indefinido (¿`null`?) | excepción: rompe la pantalla por una entrada | el router decide | `unsupported`, distinto de `missing` |
| Testabilidad | simple | simple | alta | alta (el resultado es un valor comparable) |
| Dependencia entre features | ninguna | ninguna | ninguna si el router vive en `core`/`app` | ninguna |

C no es una alternativa excluyente: **D + un router por fuente**. A/B se
descartaron por (a) N lecturas de la biblioteca, (b) colapsar «borrada»,
«fuente desconocida» y «fallo» en `null` o en una excepción. La razón es del
código (lecturas de biblioteca y relink), no estética.

## 5. LocalSongLookup

`features/library/domain/services/local_song_lookup.dart`. Recibe un
`LibraryLoader` (`Future<List<LocalSong>> Function()`) que entrega la
biblioteca **ya cargada y filtrada**; no conoce MediaStore ni duplica
`MediaStoreSongRepository`. Se cablea sobre `songsProvider`, así que hereda el
filtro, la caché de escaneo y la invalidación al reescanear.

- Compara **identidad exacta** (`source` y `externalId` carácter a carácter):
  `("local","007")` no es `("local","7")`.
- Otra fuente → `unsupported` (sin leer la biblioteca).
- Local que no está en la biblioteca → `missing`.
- Biblioteca ilegible → `SongLookupFailure(source: local)`; nunca `missing`.
- La biblioteca se lee una vez por lote.

## 6. Router

`SourceSongLookup(Map<String, SongLookup>)` en `core/domain/services`. Reparte
las identidades por `identity.source` (una llamada por fuente, en paralelo) y
hace cumplir el contrato:
- fuente sin lookup → `unsupported` (no se trata como local);
- identidad no contabilizada por un lookup → `missing`;
- canción devuelta bajo otra identidad → `SongLookupFailure`;
- lo no pedido se ignora;
- un fallo de una fuente **propaga** y falla el lote (ver riesgos).

Cableado: `songLookupProvider` (en `core/lookup`, se sobrescribe como
`artworkRepositoryProvider`) y `lib/app/song_lookup_wiring.dart`, **el único
sitio donde se registra cada fuente**. `main.dart` y `libraryOverrides` de los
tests usan `songLookupOverride()`.

## 7. Favoritos

`GetFavoriteSongs(favorites, lookup)`:
1. `lookup.findAll` de todas las identidades guardadas (un lote).
2. Solo a los favoritos **locales** declarados `missing` se les aplica además
   `SongMatcher` (ruta → título + artista + duración) sobre la biblioteca; si
   aparece con otra identidad se guarda la nueva (`relink`), como antes.
3. Se ocultan (sin borrar) los no resueltos; sin repetidos; más recientes
   primero.
Sin cambios en `FavoritesRepository` ni en el esquema.

## 8. Playlists

`GetPlaylistSongs(playlists, lookup)`: igual, recorriendo **cada entrada
guardada** (no el conjunto de identidades): se conservan **orden y
duplicados**, y cada repetición mantiene su propia entrada (id/posición). Las
no resueltas se ocultan sin borrarse.

## 9. Canción eliminada y semántica de los casos

| Caso | Resultado | Efecto en favoritos/playlists |
|---|---|---|
| Local borrada o SD desmontada | `missing` | oculta, conservada; si el reencuentro local la halla con otro id, `relink` |
| Identidad persistida pero fuera de la biblioteca filtrada | `missing` | igual |
| Fuente desconocida / aún no integrada | `unsupported` | oculta, conservada, **sin** reencuentro local |
| Fallo temporal (biblioteca ilegible, red futura) | `SongLookupFailure` | llega a la UI como error y se puede reintentar (como antes) |

## 10. Fuente desconocida

Se evaluó `null`, excepción tipada y `unavailable`. Se eligió un cubo propio
`unsupported`: (a) `null`/`missing` la confundiría con una canción borrada;
(b) una excepción rompería la pantalla entera por una entrada (p. ej. tras
desactivar un proveedor); (c) el cubo es visible y comprobable (los tests
fallan si se convierte en local o en `missing`) y permite a una UI futura
mostrar «fuente no disponible». Para no ocultar el error de configuración,
los casos de uso **no** aplican el reencuentro local a una identidad
`unsupported`, ni siquiera si es local (lookup local sin registrar).

## 11. SongMatcher

**No cambia** y sigue siendo política de la fuente local (reencuentro por ruta
y título). No se usa como lookup ni para fuentes remotas: solo lo aplican los
casos de uso a entradas **locales** `missing`. El lookup no hace búsqueda por
título ni coincidencias aproximadas.

## 12. SongReference

Sigue siendo necesaria: es identidad + respaldo de metadata de lo persistido, y
es exactamente lo que el reencuentro local consume (`path`, `title`, `artist`,
`durationMs`). Sin cambios.

## 13. Futuro proveedor

```
MusicIdentity("proveedor", "abc") → ProviderSongLookup → Song
```
1. Una feature de proveedor implementa `SongLookup` (decide con la identidad y
   su cliente; devuelve `Song` universal con `ArtworkReference` remota y
   transforma sus errores en `SongLookupFailure`).
2. Se registra **una línea** en `buildSongLookup` (`lib/app`):
   `'proveedor': ProviderSongLookup(...)`.
3. Favoritos y playlists lo resuelven sin cambios. No se crearon clases de
   proveedor.

## 14. Arquitectura

- `core/domain`: `SongLookup` (puerto), `SongLookupResult`, `SongLookupFailure`,
  `SourceSongLookup`.
- `core/lookup`: `songLookupProvider` (solo Riverpod).
- `features/library/domain/services`: `LocalSongLookup`.
- `lib/app`: composición (`song_lookup_wiring.dart`); `app` puede depender de
  features, las features no dependen de `app` ni entre sí: no se añadieron
  excepciones feature → feature. `test/architecture` 6/6.

## 15. Tests

958 → 1014 (+56): router (enrutado, fuente desconocida, errores, contrato),
`LocalSongLookup` (encontrada, inexistente, otra fuente, identidad exacta,
fallo de lectura, una lectura por lote), cableado real (biblioteca filtrada,
sin permiso, error), y favoritos/playlists con varias fuentes (local + remota
ficticia, ausentes, fuente sin lookup, no reencuentro de entradas remotas,
reenlace local, orden, duplicados, fallo). Los 958 anteriores siguen verdes;
los constructores de los casos de uso ganan el lookup.

## 16. Mutation testing

28 mutaciones, en tandas de 4, con clasificación compilación/test:
**28 KILLED, 0 SURVIVED, 0 INVALID**. Una (P2, playlists aplicando el
reencuentro local a una identidad `unsupported`) **sobrevivió** al principio: el
test equivalente solo existía en favoritos; se añadió el de playlists y pasó a
KILLED. Cubren: router (ignorar source, fuente desconocida→primer lookup o
`missing`, tragar fallos, no validar identidad, no rellenar `missing`, no
filtrar a lo pedido, `merge`), `LocalSongLookup` (ignorar source/externalId,
Song incorrecta, fallo→`missing`, lookup por título, leer sin locales),
favoritos y playlists (matcher para todas las fuentes o `unsupported`, ignorar
el lookup, sin dedupe/relink, orden, duplicados, ausente lanza), y el
cableado (biblioteca vacía, etiqueta de fuente).

## 17. Riesgos

- **Un fallo de una fuente falla el lote**: con una segunda fuente real, una
  caída de red dejaría sin resolver también las locales. Aislar fallos por
  fuente exige que la UI muestre resultados parciales; se decidirá entonces.
- Los casos de uso siguen recibiendo `List<LocalSong>` solo para el reencuentro
  local (la biblioteca se lee una vez en el provider y el lookup la reutiliza).
- `unsupported` hoy se oculta sin avisar; una UI futura podría mostrarlo.
- El respaldo `path` de la persistencia sigue siendo un dato local
  (`localPathOf`), pendiente de 2.9.

## 18. Próxima fase

Primer proveedor real de solo lectura: `ProviderSongLookup` +
`ProviderArtworkResolver`/`RemoteArtworkLoader` + resolver de reproducción,
registrados en `lib/app`; decidir con él el aislamiento de fallos por fuente y
cómo mostrar `unsupported`/`missing` en la UI.
