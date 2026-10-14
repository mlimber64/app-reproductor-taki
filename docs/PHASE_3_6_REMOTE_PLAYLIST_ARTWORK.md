# Fase 3.6 — Portadas de playlist con canciones remotas

Corrige el `REAL_LEAK 2` de la auditoría 3.3. Solo artwork de playlists: no se
tocó `Song`, `MusicIdentity`, Player, Cola, atribución, MediaSession, lockscreen,
Jamendo, la persistencia de playlists ni la infraestructura de artwork.

## 1. Camino anterior (auditado)

```
Playlist.coverIdentities (≤4 identidades guardadas en SQL)
  └─ libraryArtworkProvider: Map<MusicIdentity, ArtworkReference> construido SOLO con
     LibraryLoaded.songs (canciones locales: song.artwork = LocalArtworkReference(albumId))
  └─ playlists_page.dart:163 y add_to_playlist_sheet.dart:122:
        playlistCoverArtwork([ for (id in coverIdentities) libraryArtwork[id] ])
  └─ PlaylistCoverImages → AlbumArtworkBuilder / AlbumArtworkMosaicBuilder
        → ArtworkCache (local: ArtworkRepository, remota: RemoteArtworkLoader) → TakiArtwork
```

Consumidores de `libraryArtworkProvider`: solo esos dos sitios (y el propio
`playlistCoverArtwork`). El detalle de playlist ya usaba `song.artwork` de las
canciones resueltas, así que no estaba afectado.

## 2. REAL_LEAK

El mapa se construía solo desde la biblioteca local: una identidad `jamendo:<id>`
no estaba en él → `null` → pieza sin carátula en la lista y el selector, aunque su
`Song` resuelta sí traía `RemoteArtworkReference`. Todo lo demás de la cadena de
imágenes (builders, caché, loader, `TakiArtwork`) ya aceptaba referencias remotas.

## 3. Nuevo camino

`playlists_providers.dart`:

- `coverIdentitiesToResolveProvider`: las identidades de portada (de todas las
  playlists) que **no** están en la biblioteca local. Valor con igualdad por
  conjunto: solo cambia, y solo vuelve a consultar, cuando cambia el conjunto (no
  con renombrar o añadir una canción de la biblioteca).
- `remoteCoverArtworkProvider`: **una** consulta en lote al `SongLookup`
  existente (con `findAllIsolatingSources` de la 3.4, así una fuente que falla no
  anula a otra) y `identidad → Song.artwork` de las canciones resueltas. Un fallo
  de lookup da `{}`.
- `playlistCoverArtworkProvider`: mapa final = el local de siempre (con
  prioridad) + el de las demás fuentes. Lo usan la lista de playlists y el
  selector «Añadir a una playlist» (que compartían el problema); su UX y sus
  acciones no cambian.

`Song → artwork` es el contrato universal; la UI no conoce a ningún proveedor ni
descarga nada: `PlaylistCoverImages` y el resto no cambian.

## 4. Infraestructura reutilizada

`ArtworkReference` (Local/Remote/Unavailable), `SongLookup`/`SourceSongLookup`,
`findAllIsolatingSources`, `PlaylistCoverImages`, `AlbumArtworkBuilder`/
`AlbumArtworkMosaicBuilder`, `ArtworkCache`, `RemoteArtworkLoader`
(`HttpRemoteArtworkLoader` en `main.dart`), `TakiArtwork`. No hay HTTP en la UI, ni
segundo sistema de artwork, ni dependencia nueva. Dimensiones, radios y layout sin
cambios.

## 5. Fallbacks

| Caso | Resultado |
|---|---|
| Solo locales | idéntico a antes; no se consulta a otras fuentes |
| Remota con carátula | se muestra |
| Mixta (local + remota) | orden y n.º de celdas conservados (mosaico 2×2 con 4) |
| Remota `Unavailable` | pieza sin imagen; no se pide nada; se ignora y cuenta la siguiente |
| El loader falla / devuelve `null` | pieza sin imagen (ya lo hacía `ArtworkCache`) |
| El lookup de la fuente falla | pieza sin imagen; las locales siguen |
| Biblioteca local falla | las remotas se siguen mostrando |
| Playlist vacía | estado visual existente (mosaico vacío), sin consultas |
| Playlist con canciones sin carátula | pieza sin imagen (existente) |

Un fallo de artwork nunca impide mostrar o abrir una playlist (tests).

## 6. Caché y rendimiento

Las imágenes siguen en la `ArtworkCache` existente: su clave es
`(ArtworkReference, size)` con igualdad por valor, así que local y remota no
colisionan y la misma URL en dos playlists se descarga una vez (test). Los
metadatos se consultan una vez por cambio del conjunto de identidades, no por
reconstrucción del widget ni por edición de una playlist (tests). Sin precarga, sin
persistencia, sin debounce. Nota: el mapa identidad→referencia **no** se memoiza
entre cambios del conjunto: si crece, se vuelve a consultar el conjunto completo
(una llamada en lote).

## 7. AddToPlaylistSheet

Compartía el mismo mapa; ahora usa `playlistCoverArtworkProvider` (test: muestra la
portada remota y sigue añadiendo la canción a la playlist elegida).

## 8. Tests

- `test/features/playlists/presentation/playlist_cover_remote_test.dart` (17):
  A solo locales (sin consultas), B solo remotas, C/J mixta con orden y 4 celdas,
  primera canción manda, D `Unavailable`, ignorar sin carátula, E loader falla/`null`,
  lookup falla, F vacía, G una remota que falla no rompe las locales, caché compartida
  (una descarga), H editar sin cambiar el conjunto no reconsulta, crecimiento y
  cambio de contenido del conjunto, biblioteca local falla, K selector.
- `dependency_rules_test.dart` (+1): `features/playlists` no importa ni menciona
  Jamendo (I).
- Los tests existentes de portadas (locales) pasan sin cambios.

## 9. Mutation testing (12 mutantes)

- **Killed: 7** (siempre resolver, igualdad sin longitud, igualdad siempre `true`
  —sobrevivió al principio y se mató tras añadir el test de cambio de contenido—,
  sin aislar fuentes, siempre `unavailable`, página solo local, selector solo
  local).
- **Survived reales: 0.**
- **Survived esperados: 4** (equivalentes): atajo de conjunto vacío (sin él el
  resultado es igual), precedencia local/remota (el mapa remoto solo contiene
  identidades fuera de la biblioteca), relanzar el error del lookup (el consumidor
  trata `AsyncError` igual que `{}`), `hashCode` constante (Riverpod compara con `==`).
- **Compile-invalid: 1** (variantes de «ignora las remotas», que dejan código
  inalcanzable); no cuenta como killed. Ese comportamiento lo cubren B y «siempre
  `unavailable`».

## 10. Riesgos

- Una llamada en lote a la fuente remota al abrir Playlists (y cuando el conjunto
  cambia); sin red, las portadas remotas quedan vacías hasta el siguiente cambio.
- Mientras se resuelve, las remotas aparecen sin imagen y luego se rellenan.
- Si el conjunto cambia con frecuencia habría que memoizar identidad→referencia.
- No cubre lockscreen/notificación ni el detalle de playlist (este último ya
  funcionaba).

## 11. Android

Pendiente: sin dispositivo/emulador no se hizo smoke test; solo verificado con
tests automáticos.
