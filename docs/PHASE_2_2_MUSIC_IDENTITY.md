# Fase 2.2 — Identidad musical

Introduce la identidad musical en el dominio de forma **aditiva**. La aplicación se comporta exactamente igual. Sin commit ni push.

## 1. Executive Summary

- Nuevo value object `MusicIdentity` (`core/domain/entities/music_identity.dart`): `source` (etiqueta opaca) + `externalId` (cadena opaca). Dart puro, inmutable, igualdad por valor, sin URL ni proveedores.
- La conversión «id local entero → `MusicIdentity`» vive en **un único sitio** (`local_music_identity.dart`): fuente `"local"`, `externalId = id.toString()`.
- `Song` gana un getter `musicIdentity` **derivado** de `Song.id`; no hay campo nuevo, así que **no puede haber dos identidades independientes**. `Song.id` pasa a estar documentado como id local/legacy y clave de persistencia.
- `SongReference` **mantiene su responsabilidad** (id local + respaldo para reencontrar la canción) y gana `musicIdentity` mediante una extensión derivada de `songId`. `SongMatcher` no cambia.
- SQLite, Player, Artwork, UI y navegación: **sin cambios**.
- Validaciones: 759 tests (729 + 30 nuevos), `flutter analyze` limpio, arquitectura 6/6, build debug correcto.

**PHASE 2.2 READY FOR PLAYBACK RESOURCE**

## 2. Estado anterior

- Identidad = `Song.id` (`int`, `_ID` de MediaStore) en todo Taki.
- `SongReference` (interfaz: `songId`, `title`, `artist`, `durationMs`, `path`) la implementan `FavoriteEntry` y `PlaylistEntry`.
- `SongMatcher` (core/domain/services) reencuentra referencias en la biblioteca local: id → ruta → título+artista+duración.
- SQLite v2: `favorites.song_id INTEGER PRIMARY KEY`, `playlist_songs.song_id INTEGER NOT NULL`.

## 3. Problema de identidad actual

Un entero de MediaStore no puede representar `fuente + id externo` (cadena) y su tipo está grabado en persistencia, matching, providers de Riverpod y comparaciones de UI. Antes de que exista ninguna fuente remota hacía falta un concepto de identidad en el dominio que no dependa de MediaStore ni de una URL, sin romper nada de lo actual.

## 4. Auditoría de consumidores de `Song.id`

Inspección previa a los cambios (`lib/`, búsqueda de `song.id`, `songId` y colecciones `int`):

| Consumidor | Qué hace con el id | Depende de int | Depende de MediaStore | Decisión |
|---|---|---|---|---|
| `sqflite_favorites_repository`, `sqflite_playlists_repository` | Clave de persistencia (`song_id`) | Sí (SQLite) | Indirecto (id local) | Sin cambios; migración en fase de persistencia |
| `FavoriteEntry`, `PlaylistEntry` (`songId`) | Referencia guardada | Sí | Indirecto | Sin cambios; ganan `musicIdentity` derivada |
| `favorites_usecases`, `playlist_usecases` | Alternar, reencontrar, `relink`, duplicados | Sí | No (usan `SongMatcher`) | Sin cambios; siguen con `id` |
| `SongMatcher` | Índice por `song.id`, por ruta y por título | Sí | Sí (ruta) | **Sin cambios** (política local) |
| `FavoritesRepository.watchFavoriteIds` (`Set<int>`), `favoriteIdsProvider`, `isFavoriteProvider.family<bool, int>` | Estado de favorito | Sí | No | Sin cambios |
| `library_page`, `favorites_page`, `playlist_detail_page` | Comparan `song.id` con la canción que suena | Sí | No | Sin cambios |
| `now_playing_page`, `song_actions_sheet` | `isFavoriteProvider(song.id)` | Sí | No | Sin cambios |
| `queue_page` | `ValueKey((song.id, n))` para duplicados | Sí | No | Sin cambios |
| `playlists_providers` (`libraryAlbumIdsProvider: Map<int, int?>`) | songId → albumId | Sí | Sí (`albumId`) | Sin cambios |
| `ArtworkFileCache`, `AlbumArtworkBuilder` | `albumId` (no `Song.id`) | Sí | Sí | Sin cambios (Artwork) |
| `JustAudioPlayerAdapter`, `TakiAudioHandler` | `contentUri`, `MediaItem.id` | No (`String`) | Sí (URI) | Sin cambios (Player) |

Conclusión: **nadie necesita la identidad nueva todavía**. Todos los consumidores actuales pueden y deben seguir usando `Song.id`/`songId` hasta las fases de resolución y persistencia.

## 5. Decisión sobre `MusicIdentity`

- **Nombre:** `MusicIdentity`, coherente con la terminología de las fases 2.0/2.1. Se comprobó que `SongReference` no cubre este concepto (su clave es un `int` local y mezcla identidad con respaldo heurístico), así que no se duplica.
- **Ubicación:** `lib/core/domain/entities/music_identity.dart`; sin imports (ni siquiera `equatable`).
- **API mínima:** `source`, `externalId`, `==`, `hashCode`, `toString` (solo depuración; no es un formato de serialización). Sin `resolve`, `fetch`, `stream`, `artwork`, `download` ni `toUrl`.
- **Invariantes** (lanzan `ArgumentError` con el nombre del parámetro):
  - `source` y `externalId` no pueden estar vacíos **ni ser solo espacios en blanco** (no identificarían nada).
  - Sin más restricciones: sin límite de longitud, cualquier carácter (especiales, Unicode, separadores, `:` `/`).
  - **Sin normalizar**: no se recorta (`" id "` ≠ `"id"`), las mayúsculas importan (`"ABC"` ≠ `"abc"`), los ids numéricos son texto (`"007"` ≠ `"7"`) y un valor con forma de URL es solo texto.
- **Igualdad/hash:** por valor, carácter a carácter; `hashCode = Object.hash(source, externalId)`.
- No es `const` porque valida en tiempo de ejecución (no solo con `assert`).
- Sin enum de fuentes ni nombres de proveedores (verificado: 0 coincidencias en `lib/core/domain`).

## 6. Decisión sobre `SongReference`

Opción elegida: **B/D — mantiene su responsabilidad y expone la identidad derivada, sin fusión física.**

- Su responsabilidad (id local + respaldo de metadata para reencontrar la canción) es distinta de la de `MusicIdentity` (solo identificar) y la usan favoritos y playlists; fusionarlas ahora obligaría a migrar SQLite y cuatro implementaciones.
- Se añade, como **extensión** (`SongReferenceMusicIdentity.musicIdentity`), la identidad derivada de `songId`. No cambia la interfaz ni a sus implementadores (`FavoriteEntry`, `PlaylistEntry`), y hay un único punto de derivación.
- Cuando la persistencia guarde `source` + `externalId`, esta extensión pasará a ser la identidad real de la referencia; ese cambio pertenece a la fase de persistencia.

## 7. Decisión sobre `SongMatcher`

**Sin cambios.** Sigue siendo la política de reencuentro **de la fuente local** (id → ruta → título+artista+duración). No depende de `MusicIdentity` ni de ningún proveedor. Las fuentes remotas, cuando existan, reencontrarán por igualdad exacta de identidad (decisión de Fase 2.0), sin pasar por este matcher.

## 8. Representación de identidad local

- Fuente: `localMusicSource = 'local'` (etiqueta opaca; no es un proveedor ni un enum).
- Id: `localMusicIdentity(int localId)` → `MusicIdentity('local', localId.toString())`. Ejemplo: `42` → `("local", "42")`.
- Aislamiento: `MusicIdentity` no sabe de enteros ni de MediaStore; la conversión es una función de `local_music_identity.dart`. No existe ninguna clase específica de MediaStore.
- `id.toString()` es determinista y reversible, y no produce ceros a la izquierda; las identidades locales de dos canciones son iguales **si y solo si** sus `id` son iguales.

## 9. Compatibilidad temporal

```text
Song
├── id                 ← id local de la fuente (MediaStore `_ID`): LEGACY/compatibilidad local
│                        y clave de persistencia; lo siguen usando SQLite, UI, matching y use cases
├── musicIdentity      ← getter derivado de `id` (no es un campo): la identidad nueva
├── title, artist, album, albumId, durationMs, path, contentUri, dateAdded, folder
```

- Hoy `id` es a la vez: **ID local de la fuente**, **clave de compatibilidad de persistencia** y, en el código actual, **identidad efectiva**. `musicIdentity` es la identidad **conceptual** y se deriva de él.
- Un solo origen de verdad: al no almacenarse `musicIdentity`, no pueden divergir.
- `Song` es `Equatable` por todos sus campos (`props` sin cambios); dos canciones con el mismo `id` pero metadata distinta comparten `musicIdentity` y no son `==` (test).
- Qué consumidor usa cada uno: **todos** siguen con `id`/`songId`; nadie consume aún `musicIdentity`.

## 10. Impacto en SQLite (no migrado)

Sin cambios de esquema, versión, `favorites.song_id` ni `playlist_songs.song_id`. Lo que tendrá que hacer la fase de persistencia (2.4):
- Guardar `source` y `externalId` (dos columnas o una cadena compuesta; decisión de esa fase) y migrar las filas existentes a `source = 'local'`, `externalId = song_id`.
- `favorites.song_id INTEGER PRIMARY KEY` exige **reconstruir la tabla** (clave compuesta); `playlist_songs` admite columnas nuevas de forma aditiva.
- `FavoritesRepository.watchFavoriteIds` (`Set<int>`), `isFavoriteProvider` (`family<bool, int>`), `Playlist.coverSongIds` (`List<int>`) y `libraryAlbumIdsProvider` (`Map<int, int?>`) deberán pasar a identidades.
- La extensión `SongReferenceMusicIdentity` se sustituye entonces por la identidad almacenada.

## 11. Impacto en Player (no migrado)

Sin cambios en `JustAudioPlayerAdapter`, `AudioSource`, `MediaItem`, `contentUri`, ni `audio_service`. El Player sigue recibiendo `Song` y usando `contentUri`. Para la Fase 2.3: `_toSource(song)` y `MediaItem.id` (hoy `song.contentUri`) deberían obtener el recurso por el puerto resolvedor a partir de la identidad; `PlaybackError` no distingue aún fallo de red; la cola no se persiste.

## 12. Impacto en Artwork (no migrado)

Sin cambios en `ArtworkRepository`, `ArtworkCache`, `AlbumArtworkBuilder`, `TakiArtwork` ni `ArtworkFileCache`. El artwork remoto **no podrá depender exclusivamente de `albumId: int`** (clave local de MediaStore); la generalización es la Fase 2.5. `MusicIdentity` no contiene ninguna referencia de artwork.

## 13. Tests

30 tests nuevos (todos verdes), con comprobación por mutación (se cambió `_isBlank`, la igualdad y la normalización; cada mutación hizo fallar tests y el archivo se restauró):

- `test/core/domain/entities/music_identity_test.dart` (19): igualdad, desigualdad por `source` y por `externalId`, `source`/`id` no intercambiables, `hashCode`, uso como clave de `Set`/`Map`, valores válidos, ids numéricos como texto (`"007"` ≠ `"7"`, enteros grandes), alfanuméricos, id con forma de URL sin tratarlo como URL, caracteres especiales/Unicode/longitud, sin normalizar (mayúsculas, espacios laterales), invariantes (vacío, solo espacios, nombre del parámetro) y `toString`.
- `test/core/domain/entities/local_music_identity_test.dart` (11 en tres grupos): `localMusicIdentity`, `Song.musicIdentity` (derivada de `id`, no forma parte de `props`, misma identidad con metadata distinta) y `SongReference.musicIdentity` (derivación, coincidencia con `Song`, favoritos y entradas de playlist).
- Ningún test existente fue modificado ni eliminado; los 729 previos siguen pasando (`SongMatcher`, favoritos, playlists, player, etc.).

## 14. Cambios realizados

| Archivo | Cambio |
|---|---|
| `lib/core/domain/entities/music_identity.dart` | **Nuevo**: value object |
| `lib/core/domain/entities/local_music_identity.dart` | **Nuevo**: `localMusicSource`, `localMusicIdentity(int)`, extensión `SongReferenceMusicIdentity` |
| `lib/core/domain/entities/song.dart` | Getter `musicIdentity` derivado; documentación de `id` como legacy/local y de la relación entre ambos. `props` y constructor **intactos** |
| `lib/core/domain/entities/song_reference.dart` | Solo documentación |
| `test/core/domain/entities/music_identity_test.dart`, `local_music_identity_test.dart` | **Nuevos** |

Sin cambios en: `SongMatcher`, SQLite (`taki_database.dart`, repositorios), Player, Artwork, UI, navegación, `pubspec.*`, Android. Sin imports nuevos entre features ni de infraestructura hacia domain; `MusicIdentity` no tiene imports y `local_music_identity.dart` solo importa archivos de `core/domain`. Búsqueda de proveedores concretos en `lib/core/domain`: ninguno.

## 15. Riesgos

| Riesgo | Mitigación |
|---|---|
| Dos identidades ambiguas (`id` y `musicIdentity`) | `musicIdentity` se **deriva** de `id`, no se almacena; documentado en `Song` y en §9 |
| Que nuevo código use `musicIdentity` mientras la persistencia sigue en `int` | Nada lo usa todavía; la fase de persistencia decidirá la transición |
| La regla «solo espacios» rechaza un id que una fuente real pudiera entregar así | Improbable; una identidad en blanco no identifica nada. Es la única restricción añadida y está documentada |
| `musicIdentity` de `SongReference` es solo local | Esperado: hoy las referencias solo conocen ids locales; se sustituirá con la persistencia |
| `Song` compara todos sus campos, no la identidad | Sin cambio deliberado; decidir en una fase posterior si «es la misma canción» debe usar la identidad |

## 16. Trabajo aplazado

- **2.3** Recurso reproducible: puerto resolvedor; `_toSource`/`MediaItem.id`; resultado más rico que una URL.
- **2.4** Persistencia: `source` + `externalId`, migración SQLite, `Set<int>`/`family<bool,int>`/`coverSongIds`/`libraryAlbumIdsProvider` a identidades.
- **2.5** Artwork generalizado.
- Decidir si `Song.id` se elimina o se degrada formalmente a «local source id» una vez migrada la persistencia.
- Identidad de fuentes con id compuesto (p. ej. ítem + archivo): cabe como cadena opaca; el formato lo fija cada fuente.

## 17. Criterios para Phase 2.3

1. `MusicIdentity` estable y probada (cumplido).
2. Decidir el contrato del **resultado de resolución** (URL renovable, motor del proveedor, no disponible) con un único consumidor inicial: el adaptador de `just_audio`.
3. Identidad como entrada del resolvedor: el puerto recibe `MusicIdentity` (o `Song`), no una URL.
4. El resolvedor local debe reproducir exactamente el comportamiento actual (`contentUri`), sin cambios visibles.
5. `PlaybackError` debería poder distinguir tipos de fallo antes de añadir fuentes remotas (decisión de 2.3).
6. Mantener 6/6 en arquitectura, `core/domain` sin Flutter y sin nombres de proveedores.

## Validaciones

- `flutter test`: **759 pasan**.
- `flutter analyze`: sin problemas.
- `test/architecture`: **6/6**.
- `flutter build apk --debug`: correcto.
- `pubspec.yaml`/`pubspec.lock`: sin cambios (sin dependencias nuevas).

### Git status

- **Propios de 2.2:** `M lib/core/domain/entities/song.dart`, `M lib/core/domain/entities/song_reference.dart`, `?? lib/core/domain/entities/music_identity.dart`, `?? lib/core/domain/entities/local_music_identity.dart`, `?? test/core/domain/` (directorio nuevo con `entities/music_identity_test.dart` y `entities/local_music_identity_test.dart`), `?? docs/PHASE_2_2_MUSIC_IDENTITY.md`.
- **Acumulados de fases 1.8–1.9 (sin tocar):** modificaciones y eliminaciones de UI/tema/artwork, tests asociados, y los informes `PHASE_1_8*`, `PHASE_1_9*`, más los informes `PHASE_2_0`, `PHASE_2_1`, `PHASE_2_1B`.
- Sin commit ni push.
