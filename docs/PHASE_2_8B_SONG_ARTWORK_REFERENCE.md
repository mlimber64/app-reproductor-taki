# Fase 2.8B — Song Artwork Reference

Paso 2 de la estrategia de la Fase 2.7. `Song` gana `artwork` y la UI deja de
conocer `albumId`. No se creó `LocalSong`, no se movió ni eliminó `Song.albumId`
ni `Song.id`, y no se tocó SQLite, Player, `PlaybackResource`,
`MusicIdentity`, `ArtworkCache`, `ArtworkResolver`, HTTP ni el manifest.

## 1. Estado anterior

La UI pintaba carátulas con `AlbumArtworkBuilder(albumId: song.albumId)`:
10 llamadas de presentación + `libraryAlbumIdsProvider`. Para una canción no
local, sin `albumId`, no había cómo expresar su carátula.

## 2. Problema de albumId en la UI

`albumId` es un dato de MediaStore. Cada pantalla tenía que saber que la
carátula de una canción sale del álbum local; una carátula remota no cabía.

## 3. Song.artwork

```dart
final ArtworkReference artwork;   // required, explícito
```

- **Campo explícito y obligatorio**: la fuente que crea la `Song` decide su
  carátula (local, remota o no disponible). No se deriva de `musicIdentity` ni
  de `albumId` dentro de `Song`.
- Forma parte de la igualdad (`props`).
- **No se persiste** (ni URLs en favoritos/playlists/SQLite): es metadata de la
  fuente, no identidad. Las entradas guardadas siguen siendo `(source,
  external_id)` + respaldo.
- Es síncrona: la UI no hace consultas asíncronas por fila.

## 4. Compatibilidad local

`MediaStoreSongRepository` es quien construye la carátula local:
`artwork: localArtworkReference(albumId)` (`null` → `Unavailable`). Es la
estrategia mínima mientras no exista `LocalSong`: el dato sale de la fuente, no
de `Song`. Resultado visible idéntico: `LocalArtworkReference(albumId)` →
`ArtworkCache` → `ArtworkRepository`. Los 893 tests previos siguen verdes (solo
se adaptaron constructores).

## 5. RemoteArtworkReference

Una `Song` puede traer `RemoteArtworkReference` y la UI la pinta sin cambios:
`AlbumArtworkBuilder.reference` → `ArtworkCache` → `RemoteArtworkLoader` (si lo
hay; sin él, `null` → placeholder, sin tocar el repositorio local). Probado con
un cargador falso, sin red.

## 6. UnavailableArtworkReference

`Unavailable` entrega `null` al builder (placeholder) sin pedir nada a nadie.

## 7. Cambios de UI

- Todos los `AlbumArtworkBuilder(albumId: song.albumId)` →
  `AlbumArtworkBuilder.reference(reference: song.artwork)`: Library, Favoritos,
  Detalle de playlist (fila), Cola (tarjeta actual y fila), MiniPlayer, Now
  Playing (3 layouts, vía `_Artwork`).
- Portadas de playlist: `libraryAlbumIdsProvider` →
  `libraryArtworkProvider` (`Map<MusicIdentity, ArtworkReference>`);
  `playlistCoverAlbumIds` → `playlistCoverArtwork` (mismo comportamiento: 4
  primeras canciones, distintas, sin las no disponibles; `[]` vs `[Unavailable]`);
  `PlaylistCoverImages(artwork:)`; `AlbumArtworkMosaicBuilder(references:)`.
  Usado por la lista de playlists, el detalle y el selector «Añadir a una
  playlist».
- **`AlbumArtworkBuilder(albumId)` se eliminó**: tras la migración no quedaba
  ningún consumidor productivo (comprobado con búsqueda en `lib/`); el único
  constructor es `.reference`. Solo cambió el nombre de parámetros; la lógica de
  resolución es la misma (`_AlbumImages`).
- Sin cambios visuales.

## 8. ArtworkResolver

Sin cambios. `ArtworkResolver`/`SourceArtworkResolver`/`LocalArtworkResolver`
siguen disponibles para fuentes cuyo artwork no venga con la `Song`. El flujo
normal ya no pasa por él: `Song.artwork` → builder → cache. Decisión de
eliminarlo o no: con el primer proveedor real.

## 9. ArtworkCache

Sin cambios de arquitectura; la clave sigue siendo `ArtworkReference + size`.
Tests nuevos desde la UI: local, remota (cargador falso) y `Unavailable`.

## 10. Consumidores restantes de `albumId` en `lib/`

Ninguno en presentación. Todos legítimos y de fuente local:

| Sitio | Motivo |
|---|---|
| `Song.albumId` (campo) | Dato de MediaStore; se mueve a `LocalSong` en 2.9 |
| `MediaStoreSongRepository` | Lo lee de MediaStore y construye `Song.artwork` |
| `MediaStoreArtworkRepository.getAlbumArtwork(albumId)` | Adaptador local |
| `ArtworkRepository` (puerto local) | Contrato local por álbum |
| `ArtworkCache._fetch` (`LocalArtworkReference(:albumId)`) | Despacho a la fuente local |
| `LocalArtworkReference`, `localArtworkReference()` | Modelo de la carátula local |
| `LocalArtworkResolver` (`song.albumId`) | Resolvedor local (2.6) |
| `ArtworkFileCache` (`song.albumId`) | Notificación/lockscreen, hoy solo local (archivos `album_<id>_<size>.jpg`) |
| Comentarios | Documentación |

## 11. Impacto en fases futuras

Un proveedor remoto solo tiene que crear `Song` con `RemoteArtworkReference` y
registrar un `RemoteArtworkLoader`; no toca UI, cache ni modelos de artwork.

## 12. Preparación para LocalSong (Fase 2.9)

`albumId`, `id`, `path`, `contentUri`, `folder`, `dateAdded` ya solo los leen
resolvers/políticas locales y `ArtworkFileCache`. Al separar `LocalSong`:
`MediaStoreSongRepository` construirá `LocalSong`; `Song.artwork` se queda en la
base; `ArtworkFileCache` pasará a recibir la referencia (o un `LocalSong`) y
`LocalArtworkResolver` podrá leer `song.artwork`.

## Mutation testing — primer intento (interrumpido; superado por la sección final)

Se preparó un lote de 17 mutaciones (`Song.artwork` fuera de `props`; repositorio
local con artwork siempre `Unavailable` o `Local(0)`; cada sitio de UI leyendo
`albumId` directamente, incluida `libraryArtworkProvider` y la portada del
detalle; selección de portada sin filtrar `Unavailable`, sin deduplicar, con
`[]`/`[Unavailable]` confundidos o pidiendo la última; el builder tratando la
remota o la local como no disponible).

**El lote se interrumpió a mitad de ejecución** porque el sistema se quedó sin
memoria y Claude Code detuvo el proceso en segundo plano; **no se registraron
resultados y no se ha relanzado**. Una mutación (U7, Now Playing) quedó aplicada
en disco al detenerse; se detectó y se restauró (comprobado con búsqueda y con
`analyze` + suite completa en verde). Por tanto, **la detección de estas
mutaciones no está verificada en esta fase**. Lo que sí hay son los tests que
las apuntan (cada pantalla con una canción de `albumId` ≠ carátula, `Song`
con/ sin `artwork` en igualdad, repositorio MediaStore, selección de portada con
remotas); relanzar el lote queda pendiente.

## Mutation testing — final

Se ejecutó el mismo lote de 17 mutaciones (sin añadir ninguna), en tandas de
4–5 en primer plano, con `flutter test --concurrency=2` sobre `test/core` y
`test/features`, y el resultado guardado tras cada mutación. No hubo falta de
memoria.

**Total 17 · KILLED 17 · SURVIVED 0 · NOT APPLICABLE 0 · NOT EXECUTED 0.**

| Id | Mutación | Archivo | Resultado |
|---|---|---|---|
| S1 | `Song.artwork` fuera de `props` | `song.dart` | KILLED |
| S2 | repo MediaStore: artwork siempre `Unavailable` | `media_store_song_repository.dart` | KILLED |
| S3 | repo MediaStore: artwork `Local(0)` fijo | `media_store_song_repository.dart` | KILLED |
| U1 | Library lee `albumId` directo | `library_page.dart` | KILLED |
| U2 | Favoritos lee `albumId` directo | `favorites_page.dart` | KILLED |
| U3 | Detalle de playlist (fila) lee `albumId` | `playlist_detail_page.dart` | KILLED |
| U4 | Detalle de playlist (portada) lee `albumId` | `playlist_detail_page.dart` | KILLED |
| U5 | Cola (tarjeta y fila) lee `albumId` | `queue_page.dart` | KILLED |
| U6 | MiniPlayer lee `albumId` | `mini_player.dart` | KILLED |
| U7 | Now Playing lee `albumId` | `now_playing_page.dart` | KILLED |
| U8 | `libraryArtworkProvider` lee `albumId` | `playlists_providers.dart` | KILLED |
| C1 | portada: no filtra `Unavailable` | `playlist_cover_albums.dart` | KILLED |
| C2 | portada: no deduplica | `playlist_cover_albums.dart` | KILLED |
| C3 | portada: `[]` y `[Unavailable]` confundidos | `playlist_cover_albums.dart` | KILLED |
| C4 | portada simple: pide la última | `playlist_cover_images.dart` | KILLED |
| B1 | builder: la remota como no disponible | `album_artwork_builder.dart` | KILLED |
| B2 | builder: la local como no disponible | `album_artwork_builder.dart` | KILLED |

**Rigor de la clasificación.** Una pasada intermedia dio las 17 como «matadas»,
pero el clasificador aceptaba también fallos de compilación, y U1–U6 **no
compilaban** (los archivos de UI no importan `artwork_reference.dart`), así que
esa pasada no se tomó como válida. El runner final (a) añade el import como parte
de esas mutaciones, y (b) separa fallo de compilación (`Failed to load` /
`Compilation failed` / `*.dart:l:c: Error:`) de fallo de test. Una primera
versión de (b) confundía tests llamados «error: …» con errores de compilación y
marcó U1–U4 como inválidas; se comprobó a mano con `flutter analyze` (la
mutación U1 compila y la mata el test `la fila usa song.artwork, no albumId`) y
se corrigió el patrón. Resultado final con el clasificador corregido: 17
KILLED, todas por fallo real de test.

**Restauración.** Tras cada mutación el archivo se restaura en un `finally`.
Al terminar: búsqueda de los patrones mutados (solo quedan dos usos originales
legítimos: `LocalArtworkResolver` y el retorno `[Unavailable]` de la selección de
portada), `git diff --check` sin errores de espacios, `analyze` limpio y suite
completa verde.

### Intento anterior (se conserva)

El primer intento se interrumpió por falta de memoria del sistema (el proceso en
segundo plano fue detenido por Claude Code) sin producir resultados y dejó
aplicada la mutación U7 en `now_playing_page.dart`; se detectó y restauró.

## Riesgos

- `Song.artwork` es obligatorio: toda fuente nueva debe fijarlo (el compilador lo
  exige). Un valor incoherente con `albumId` (p. ej. `Unavailable` con `albumId`)
  es posible a propósito en tests; en producción solo el repositorio lo fija.
- `ArtworkFileCache` y la notificación siguen usando `albumId`: una canción con
  carátula remota no tendrá carátula en el lockscreen hasta la fase que lo
  conecte (documentado desde 2.6).
- La carátula remota en la UI depende de `remoteArtworkLoaderProvider`, hoy
  `null`: hasta que un proveedor lo registre, una carátula remota se verá como
  placeholder.
- `Song.==` ahora incluye `artwork`: dos `Song` con distinta carátula ya no son
  iguales.
