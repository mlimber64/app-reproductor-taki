# Fase 2.9 — LocalSong Extraction

Refactor arquitectónico **sin cambio funcional**. `Song` queda universal y todo
lo específico de MediaStore baja a `LocalSong extends Song`. No se tocó
SQLite, `PlaybackResource`, `MusicIdentity`, `ArtworkReference`,
`ArtworkCache`, Android, `pubspec` ni la lógica del Player.

## 1. Estado anterior

`Song` (2.8B) tenía 11 campos: `musicIdentity` (derivado de `id`), `title`,
`artist`, `album`, `artwork`, `durationMs` y los locales `id`, `albumId`,
`path`, `contentUri`, `folder`, `dateAdded`. El helper `ForeignSong` tenía que
rellenar los locales con basura (`id: 0`, `path: ''`, `contentUri: ''`).

### Auditoría previa (producción) y comparación con 2.7

| Campo | Consumidores reales | Clase |
|---|---|---|
| `id` | `MediaStoreSongRepository` (construye); `get_songs` (desempate); `localMusicIdentity(id)` | A (local) |
| `albumId` | `LocalArtworkResolver`; **`ArtworkFileCache`**; repositorio | A, y **B** (`ArtworkFileCache`) |
| `path` | `SongMatcher`, `SongFilter`; **respaldo en favoritos/playlists** (repos SQLite + `playlist_usecases` al relinkar) | A, y **B** (persistencia) |
| `contentUri` | `LocalPlaybackResolver` | A |
| `folder` | `SongFilter` | A |
| `dateAdded` | nadie (solo se escribe) | **D (muerto)** |
| tests / helpers | `buildSong`, `testSong`, `Song(...)` directos, `ForeignSong` | C |

Diferencias con 2.7: **ninguna nueva**. 2.7 ya anticipaba `get_songs`,
resolvers, `SongMatcher`/`SongFilter`; las dos fugas B (`ArtworkFileCache` y el
respaldo de `path`) no estaban en la lista porque 2.7 las contaba como «local
legítimo»; aquí se resuelven.

## 2. Campos universales

`Song`: `musicIdentity`, `title`, `artist`, `album`, `durationMs`, `artwork`
(6). Igualdad por valor con **todos** ellos (`musicIdentity` y `artwork`
incluidos); Equatable compara además el tipo en ejecución, así que una `Song` no
es igual a una `LocalSong`. Constructor `const`, sin subclase por proveedor: una
fuente remota crea `Song` directamente.

## 3. Campos locales

`LocalSong`: `id`, `albumId`, `path`, `contentUri`, `folder` (+ los universales).

## 4. Diseño de LocalSong

```dart
class LocalSong extends Song {
  LocalSong({required id, title, artist, album, artwork, durationMs,
             required albumId, required path, required contentUri, folder = ''})
      : super(musicIdentity: localMusicIdentity(id));
  // props: [...super.props, id, albumId, path, contentUri, folder]
}
```

**Dónde vive**: `core/domain/entities/local_song.dart`, junto a
`local_music_identity.dart`. No puede ir en `features/library` porque quienes la
leen (`LocalPlaybackResolver`, `LocalArtworkResolver`, `SongMatcher`) están en
`core/domain`, y `core` no puede depender de una feature (lo comprueba
`test/architecture`). Es Dart puro: no importa MediaStore ni Flutter. Todo el
conocimiento de MediaStore sigue en `features/library/infrastructure`
(`MediaStoreSongRepository`, `MediaStoreArtworkRepository`).

## 5. MusicIdentity

`LocalSong` **no recibe identidad**: la fija el constructor desde `id`
(`localMusicIdentity(id)` = `("local", "42")`). Es imposible construir
`id = 42` con identidad `local/43`. `MusicIdentity` no cambió. El `externalId`
sigue siendo el `id` en decimal; `albumId` nunca interviene.

## 6. Song.id

Desaparece del modelo universal. Solo existe `LocalSong.id`, que lee el
repositorio, `get_songs` (desempate) y `localMusicIdentity`. La UI y la
persistencia usan `MusicIdentity`. No hay conversiones `externalId → int` fuera
de la frontera local.

## 7. albumId

Solo en `LocalSong` (y en `LocalArtworkReference`/MediaStore). La UI ya no lo lee
(2.8B) y ahora tampoco `ArtworkFileCache`, que usa `Song.artwork` y solo guarda
carátulas `LocalArtworkReference` (mismos archivos `album_<id>_<size>.jpg`). Para
canciones locales, comportamiento idéntico.

## 8. contentUri

Solo en `LocalSong`. Flujo sin cambios:
`LocalSong.contentUri → LocalPlaybackResolver → LocalUriResource`. No se
persiste.

## 9. dateAdded

**Eliminado.** Reconfirmado con búsqueda: ningún lector en `lib/` ni en tests de
comportamiento. El canal nativo sigue enviando `dateAdded` (Android no se tocó);
el repositorio simplemente ya no lo lee. Esto prevalece sobre «conservar
`dateAdded` exactamente» del punto de conversión, que solo aplicaba si el campo
se mantenía.

## 10. Artwork

`LocalSong → Song.artwork → ArtworkReference`, como en 2.8B. El repositorio lo
construye con `localArtworkReference(albumId)`; sigue siendo un campo explícito
de `LocalSong` (un test fija `albumId ≠ artwork` para detectar lecturas del
`albumId`).
`LocalArtworkResolver` lee `LocalSong.albumId`; ante una `Song` con identidad
local pero sin datos locales devuelve `Unavailable`.

## 11. Playback

`LocalPlaybackResolver.resolve(Song)`: identidad no local → `IdentityNotFound`
(igual); identidad local y **no** `LocalSong` → `UnavailableResource`; si no,
`LocalUriResource(contentUri)`. El contrato universal sigue recibiendo `Song`
porque el player (y un futuro `SourceArtworkResolver`) tratan canciones de
cualquier fuente. `JustAudioPlayerAdapter` y `PlaybackResource` no cambiaron.

## 12. SongReference

Sin cambios de responsabilidad: identidad + respaldo de metadata (`path` es
opcional). `SongMatcher` pasa a trabajar con `List<LocalSong>` y devuelve
`LocalSong?`: **`SongReference → LocalSong`** es más apropiado que `→ Song`
porque el reencuentro usa criterios locales (ruta, título, duración) contra la
biblioteca local; una futura búsqueda por identidad en una fuente remota
(`SongLookup`) devolverá `Song`.

## 13. Favorites

Persisten `source + external_id` + respaldo (título, artista, álbum, duración,
ruta). La identidad se compara con `MusicIdentity`. `GetFavoriteSongs` recibe
`List<LocalSong>` (la biblioteca local) y devuelve `List<Song>`. El respaldo de
`path` usa `localPathOf(song)`: la ruta solo se guarda para canciones locales.

## 14. Playlists

Igual: `PlaylistEntry` se identifica por `MusicIdentity`; `GetPlaylistSongs`
recibe la biblioteca local (`List<LocalSong>`) y `PlaylistItem.song` es `Song`.
Las operaciones que añaden/relinkan aceptan `Song` universal y respaldan la ruta
con `localPathOf`.

## 15. UI

Sin cambios: toda la UI consume `Song`. `grep` en `lib/`: **ningún**
`as LocalSong` ni `as Song`. Las únicas comprobaciones de tipo son `is LocalSong`
en los dos resolvers locales y en `localPathOf` (la frontera entre el contrato
universal y los datos locales). Las pantallas que listan la biblioteca reciben
`List<LocalSong>` (covariante con `List<Song>`) pero solo usan la API universal.

## 16. ForeignSong

**Eliminado.** Ya no hacía falta: `Song` universal representa `source != local`
sin subclase. Los tests usan `buildUniversalSong(identity, …)`
(`test/helpers/universal_song.dart`), que construye una `Song` real. Los tests
de «resaltar la que suena» en Library/Favoritos/Detalle, que usaban `ForeignSong`
dentro de la biblioteca (que ahora es solo local), usan dos `LocalSong` con ids
distintos: la mutación «comparar por `id`» ya no es expresable porque `Song` no
tiene `id` (la garantiza el compilador). Los tests de cola, handler y
persistencia sí usan `Song` universal.

## 17. Migración

Código: `Song` (reducida), `LocalSong` (nueva), `SongRepository`/`GetSongs`/
`SongFilter`/`LibraryLoaded`/`SongMatcher`/`GetFavoriteSongs`/`GetPlaylistSongs`
pasan a `LocalSong`; `MediaStoreSongRepository` construye `LocalSong`;
resolvers locales y `ArtworkFileCache` ajustados; `localPathOf` en los tres
puntos de respaldo. Tests: `buildSong`/`testSong` devuelven `LocalSong`; el
contrato `Song.musicIdentity ∉ props` de 2.2 pasó a `∈ props` (se pidió que la
identidad forme parte de la igualdad); `song_test.dart` se dividió en
`test/core/domain/entities/song_test.dart` (universal) y `local_song_test.dart`.

## 18. Tests

929 → 958 (+29). Nuevos: `LocalSong` (construcción, identidad derivada,
igualdad campo a campo, `localPathOf`), `Song` universal sin campos locales,
`ArtworkFileCache` (antes sin test propio), respaldo de `path` local vs
universal en ambos repositorios SQLite, resolvers con `Song` base, desempate de
`get_songs` independiente del orden de entrada.

## 19. Mutation testing

Lotes de 4 en primer plano, `--concurrency=2`, clasificando fallo de
compilación (`INVALID`) aparte de fallo de test. Resultado: **22 ejecutadas, 22
KILLED**, 0 SURVIVED, 0 INVALID.

Una (X5, `get_songs` sin desempate por `id`) **sobrevivió** al principio: el
test existente ya recibía los ids en orden; se añadió un test con entrada
desordenada y pasó a KILLED.

| Id | Mutación | Resultado |
|---|---|---|
| L1 | identidad de LocalSong = `local(id+1)` | KILLED |
| L2 | identidad de LocalSong con otra fuente | KILLED |
| L3 | `albumId` fuera de props | KILLED |
| L4 | `contentUri` fuera de props | KILLED |
| L5 | `...super.props` omitido | KILLED |
| S1 | `Song.artwork` fuera de props | KILLED |
| S2 | `Song.musicIdentity` fuera de props | KILLED |
| P1 | `localPathOf` siempre null | KILLED |
| P2 | `localPathOf` vacío para no locales | KILLED |
| R1 | repo: `id + 1` | KILLED |
| R2 | repo: `albumId` null | KILLED |
| R3 | repo: artwork eliminado | KILLED |
| R4 | repo: `contentUri` vacío | KILLED |
| R5 | repo: `path` vacío | KILLED |
| R6 | repo: `folder` vacío | KILLED |
| X1 | PlaybackResolver: `Song` base lanza en vez de `Unavailable` | KILLED |
| X2 | ArtworkResolver: usa `song.artwork` en vez de `albumId` | KILLED |
| X3 | ArtworkResolver: `Song` base devuelve su artwork | KILLED |
| X4 | ArtworkFileCache: `albumId` fijo | KILLED |
| X5 | `get_songs` sin desempate por id | KILLED (tras añadir test) |
| X6 | `SongFilter` ignora `folder` | KILLED |
| X7 | `SongMatcher` sin índice por ruta | KILLED |

**No aplicables (garantizados por el compilador, sin mutación posible):**
«usar `Song.id` como identidad», «`albumId`/`contentUri` en `Song`», «eliminar
campos locales de `LocalSong`» y «construir `Song` donde debe haber `LocalSong`»
(`SongRepository` devuelve `List<LocalSong>`; `SongMatcher`, `SongFilter` y
`GetSongs` solo aceptan `LocalSong`). Quitar un campo de `LocalSong` o añadirlo a
`Song` rompe la compilación de sus consumidores; un test comprueba además que
`Song.props` tiene exactamente 6 elementos.

## 20. Riesgos / deuda

- `localPathOf` y el respaldo de `path` en persistencia siguen siendo la única
  lectura de un dato local desde código de persistencia universal. A medio plazo
  conviene un respaldo propio de la fuente local (p. ej. una `LocalSongReference`).
- Los resolvers locales usan `is LocalSong`; si más tarde la biblioteca local se
  sirve como `Song` base (p. ej. desde caché), degradarán a «sin recurso/sin
  carátula» en lugar de fallar.
- `SongMatcher`, `GetFavoriteSongs` y `GetPlaylistSongs` están tipados a la
  biblioteca **local**; las entradas guardadas de otra fuente no se resuelven aún
  (necesitan `SongLookup`).
- El canal nativo sigue enviando `dateAdded`; sin uso.
- La `ArtworkFileCache` y el lockscreen siguen siendo solo locales.

## 21. Próxima fase

Un puerto `SongLookup` (identidad → `Song`) por fuente para resolver favoritos y
playlists de fuentes no locales, o la fase del primer proveedor
(resolver de reproducción y de artwork registrados, cargador remoto, `INTERNET`
en el manifest). Decidir también si `ArtworkResolver` sigue haciendo falta.
