# Fase 2.4 — Persistencia de la identidad musical

Fase 2.2 resolvió «¿qué canción es?», 2.3 «¿cómo puede reproducirse?». Esta resuelve **«¿cómo persiste Taki esa identidad?»**. La base pasa de la versión 2 a la **3** y favoritos y playlists se identifican por `source + external_id` (texto opaco), conservando todos los datos existentes. Sin commit ni push.

## 1. Executive Summary

- **Esquema v3:** `favorites` y `playlist_songs` guardan `source TEXT` + `external_id TEXT` en lugar de `song_id INTEGER`. `favorites` tiene clave primaria `(source, external_id)`; ambas tablas tienen `CHECK` que repiten la invariante de `MusicIdentity` (ni vacío ni solo espacios).
- **Migración v2 → v3 (y v1 → v3)** con copia verificada dentro de la transacción de `onUpgrade`: crea tabla nueva, copia (`source = 'local'`, `external_id = CAST(song_id AS TEXT)`), comprueba que no se perdió ninguna fila, sustituye la tabla, recrea índices, restaura la secuencia de ids y ejecuta `PRAGMA foreign_key_check`. Un fallo a mitad deja la base en v2 (probado).
- **Dominio:** `FavoriteEntry`, `PlaylistEntry` y `SongReference` se identifican por `musicIdentity`; `FavoritesRepository`, `isFavoriteProvider`, `Playlist.coverIdentities`, `libraryAlbumIdsProvider` y `SongMatcher` trabajan con `MusicIdentity`. La UI no cambia.
- **`Song.id`** se mantiene, pero ya **no es la clave de persistencia**: es el id local para MediaStore, `contentUri`, portadas y comparaciones de la UI actual.
- No se persiste ninguna URL, `PlaybackResource` ni artwork. No hay proveedores, red ni dependencias nuevas; `pubspec.*`, Player, Artwork y manifiesto sin cambios.
- Validaciones: **831 tests** (795 + 36), `flutter analyze` limpio, arquitectura 6/6, build debug correcto.

**PHASE 2.4 READY FOR REMOTE ARTWORK**

## 2. Current database schema

Versión previa (v2), tal como la tienen las instalaciones existentes:

```sql
favorites (song_id INTEGER PRIMARY KEY, added_at INTEGER NOT NULL,
           title, artist, album, duration_ms, path)            -- + idx_favorites_added_at
playlists (id INTEGER PRIMARY KEY AUTOINCREMENT, name, created_at, updated_at)
playlist_songs (id INTEGER PRIMARY KEY AUTOINCREMENT,
                playlist_id INTEGER NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
                position INTEGER NOT NULL, song_id INTEGER NOT NULL,
                title, artist, album, duration_ms, path)       -- + idx_playlist_songs_position (playlist_id, position)
```

Historial de versiones: v1 `favorites`; v2 añade `playlists` y `playlist_songs`. `PRAGMA foreign_keys = ON` se activa en `onConfigure`.

## 3. Identity persistence problem

El entero `song_id` era la identidad y la clave. No puede representar un id externo de texto (`"abc123"`, `"007"`) ni distinguir fuentes, y `favorites.song_id INTEGER PRIMARY KEY` impedía guardar nada que no fuera un entero único global.

## 4. Existing data audit

Inventario exacto de dónde se persistía el id local (`song_id`):

| Lugar | Tipo | Rol |
|---|---|---|
| `favorites.song_id` | `INTEGER PRIMARY KEY` | Clave y rowid |
| `playlist_songs.song_id` | `INTEGER NOT NULL` | Referencia a la canción en cada entrada |
| `favorites.path`, `playlist_songs.path` | texto | Respaldo (no es un id) |
| `Playlist.coverSongIds` (derivado por consulta) | ids concatenados con `:` y `,` | **No es una columna**, pero dependía del entero; se rehízo (ver §13) |

Se comprobó que **no hay otras tablas ni almacenamiento** con ids de canción: no se usa `SharedPreferences`, la cola del reproductor no se persiste y no hay más tablas en `taki.db`.

Consumidores del id en código (todos migrados a identidad salvo los locales): repositorios SQLite, `FavoriteEntry`, `PlaylistEntry`, casos de uso de favoritos y playlists, `SongMatcher`, `favoriteIdsProvider`/`isFavoriteProvider`, `libraryAlbumIdsProvider` y las pantallas que consultaban `isFavoriteProvider(song.id)`.

Observación sobre el orden (verificada con una prueba): en v2 `song_id` **era** el rowid (`INTEGER PRIMARY KEY`), así que el desempate `ORDER BY added_at DESC, rowid DESC` equivalía a `song_id DESC`. La migración copia por rowid ascendente; el desempate da el mismo orden que antes.

## 5. Alternatives

| | A. Columnas `source`, `external_id` en cada tabla | B. Tabla `music_identities` con id numérico y FK | C. Una sola columna de texto compuesta (`source:id`) |
|---|---|---|---|
| Ventajas | Sin joins; consultas simples; cada fila es autocontenida (como hoy con el respaldo de metadata); clave compuesta natural en favoritos; igualdad binaria de texto | Integridad referencial central; una identidad = un id pequeño | Una columna |
| Desventajas | Repite los textos en cada fila | Joins en todas las consultas; hay que crear/limpiar filas de identidad huérfanas; migración más compleja; cada escritura toca dos tablas; Riverpod/repositorios necesitan resolver id↔identidad | Hay que construir y partir la cadena; ambigüedad si la fuente o el id contienen el separador; no permite filtrar por fuente con índice |
| Migración | Reconstruir `favorites` y `playlist_songs` | Crear tabla de identidades, poblarla y reconstruir ambas tablas con FK | Reconstruir ambas tablas |
| FK / índices / unicidad | FK ya existente a `playlists`; `PRIMARY KEY (source, external_id)` en favoritos; sin unicidad en `playlist_songs` (las entradas se repiten) | FK nuevas; `UNIQUE (source, external_id)` en la tabla de identidades | `PRIMARY KEY` de una columna |
| Compatibilidad futura | Soporta cualquier fuente sin cambios de esquema | Igual, más rígido | Frágil |
| Impacto en consultas / Riverpod | Bajo: `MusicIdentity` ↔ dos columnas en el repositorio; `MusicIdentity` ya es clave de `Set`/`family` | Alto: joins y mapeos | Medio |

**Elegida: A.** El código actual ya guarda cada fila de forma autocontenida (con copia de respaldo de la canción) y nunca consulta «todas las filas de una identidad»; una tabla de identidades añadiría complejidad sin beneficio hoy, y C reintroduce un formato que hay que interpretar, contra la decisión de 2.0 de que identidad = dos valores opacos. No se eligió por tener menos columnas.

## 6. Selected schema

```sql
favorites (
  source TEXT NOT NULL CHECK (length(trim(source)) > 0),
  external_id TEXT NOT NULL CHECK (length(trim(external_id)) > 0),
  added_at INTEGER NOT NULL,
  title, artist, album, duration_ms, path,
  PRIMARY KEY (source, external_id)
)                                                     -- idx_favorites_added_at (added_at)

playlist_songs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  playlist_id INTEGER NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
  position INTEGER NOT NULL,
  source TEXT NOT NULL CHECK (length(trim(source)) > 0),
  external_id TEXT NOT NULL CHECK (length(trim(external_id)) > 0),
  title, artist, album, duration_ms, path
)                                                     -- idx_playlist_songs_position (playlist_id, position)
```

`playlists` no cambia. `external_id` es **texto** y nunca se convierte a número ni se normaliza; la comparación de SQLite es binaria, así que `"ABC"` ≠ `"abc"` y `"007"` ≠ `"7"`.

## 7. Identity uniqueness

- **Favoritos:** `PRIMARY KEY (source, external_id)` garantiza una fila por identidad. `("a","123")` y `("b","123")` son favoritos distintos. `add` usa `ConflictAlgorithm.ignore` (se conserva la fecha original).
- **Playlists:** **sin** `UNIQUE` sobre la identidad a propósito: la misma canción puede estar varias veces (cada entrada tiene su `id`).
- La unicidad se comprueba con pruebas contra la base real (§18).

## 8. Favorites migration

`favorites` → `favorites_v3` (nombre temporal): `INSERT … SELECT 'local', CAST(song_id AS TEXT), added_at, título, artista, álbum, duración, ruta FROM favorites ORDER BY rowid`; se verifica el número de filas; se borra la tabla antigua, se renombra la nueva y se recrea `idx_favorites_added_at`. `'local'` es una constante **congelada** dentro de la migración (`_migratedLocalSource`): una migración debe escribir siempre lo mismo aunque `localMusicSource` cambiara algún día.

Comportamiento preservado: `add`/`remove`/`relink`, el stream (ahora de `MusicIdentity`), el orden y `isFavoriteProvider(song.musicIdentity)`.

## 9. Playlists migration

`playlist_songs` → `playlist_songs_v3`: copia `id`, `playlist_id`, `position`, respaldo, con `source = 'local'`, `external_id = CAST(song_id AS TEXT)`, `ORDER BY id`; se conservan **el id de cada entrada, la posición, la playlist y el orden**; se verifica el conteo; se sustituye la tabla; se recrea `idx_playlist_songs_position`; se **restaura la secuencia AUTOINCREMENT** (un id de entrada borrado no se reutiliza). Después se ejecuta `PRAGMA foreign_key_check`; cualquier violación aborta la migración.

Operaciones revisadas (todas conservan la identidad): añadir, quitar (posiciones contiguas), deshacer (`reinsertEntry`), mover, borrar playlist (cascada), `relink`, portada. La consulta de portada ya **no** usa `group_concat` con `:`/`,` (ids opacos podrían contener esos caracteres): ahora son dos consultas y se agrupa en Dart.

## 10. Database migration strategy

Versión `2 → 3` (y `1 → 3`):

1. `onUpgrade` (sqflite lo ejecuta en **una transacción**): si `oldVersion < 2`, crea las playlists con el **esquema congelado de v2**; si `oldVersion < 3`, ejecuta `_migrateToIdentity`.
2. `_migrateToIdentity`: migra `favorites`, migra `playlist_songs`, ejecuta `PRAGMA foreign_key_check`.
3. Cualquier excepción (tabla ya existente, conteo distinto, clave foránea inválida) deshace todo: **la base queda en v2 intacta** (probado con un fallo forzado a mitad de la migración).
4. Instalación nueva: `onCreate` crea directamente el esquema v3 con sus índices.
5. No se definió `onDowngrade`: una app anterior no abre una base v3 (comportamiento estándar de sqflite). Es una base local por usuario.

Requisitos de SQLite usados: `CHECK`, `trim`, `ALTER TABLE … RENAME`, `CAST`, `PRAGMA foreign_key_check`, `sqlite_sequence`, `MAX(a, b)`. Se evitó `DROP COLUMN` (no disponible en las versiones de SQLite de Android 7). `minSdk` es 24.

## 11. Existing installation strategy

| Caso | Cubierto por prueba |
|---|---|
| A. Instalación nueva | Sí (esquema v3, índices, FK activadas, PK compuesta) |
| B. Existente con favoritos | Sí (uno, varios, 2000) |
| C. Existente con playlists | Sí (vacía, con canciones, varias, una vacía intercalada, 3000 entradas) |
| D. Favoritos + playlists | Sí |
| E. Existente sin datos | Sí |
| v1 → v3 (sin playlists previas) | Sí |
| Migración no aplicable (base ya en v3) | Sí (reabrir no cambia nada) |
| Fallo a mitad | Sí (rollback a v2) y reintento posterior |

## 12. Domain model impact

- `SongReference`: `songId` se sustituye por `MusicIdentity get musicIdentity` (la extensión derivada de 2.2 desaparece); mantiene el respaldo (`title`, `artist`, `durationMs`, `path`).
- `FavoriteEntry` y `PlaylistEntry`: `musicIdentity` en lugar de `songId`.
- `Playlist`: `coverIdentities: List<MusicIdentity>` en lugar de `coverSongIds: List<int>`.
- Las filas SQLite no se filtran al dominio: el repositorio traduce `source`/`external_id` ↔ `MusicIdentity`.
- Sin cambios en `Song`, `MusicIdentity`, `PlaybackResource`.

## 13. Repository impact

- `FavoritesRepository`: `watchFavoriteIdentities(): Stream<Set<MusicIdentity>>`, `remove(MusicIdentity)`, `relink(MusicIdentity, Song)`.
- `SqfliteFavoritesRepository` y `SqflitePlaylistsRepository` leen/escriben `source` + `external_id`; `SongMatcher` indexa por `musicIdentity` (sigue siendo la política de la fuente local: ruta y título siguen siendo criterios locales).
- Casos de uso (`ToggleFavorite`, `GetFavoriteSongs`, `AddSongsToPlaylist`, `GetPlaylistSongs`) comparan identidades.
- Providers: `favoriteIdentitiesProvider`, `isFavoriteProvider` (`family<bool, MusicIdentity>`), `libraryAlbumIdsProvider` (`Map<MusicIdentity, int?>`).
- Coste: la portada pasa de una subconsulta correlacionada con índice a una consulta que recorre `playlist_songs` con `position < 4` (sin índice por `position`). Con los volúmenes probados (3000 entradas) es irrelevante; con muchísimas entradas habría que reevaluarlo.

## 14. Provider compatibility

El esquema ya almacena `("local", "42")` y cualquier identidad futura (`("otra-fuente", "abc123")`) **sin cambios de esquema**; los tests lo comprueban con identidades de otras fuentes (vía una subclase de `Song` de prueba, sin implementar ninguna fuente). No se añadió ningún proveedor, enum de fuentes ni nombre de proveedor.

## 15. Player impact

Ninguno: no se tocó `PlaybackResource`, `PlaybackResolver`, `JustAudioPlayerAdapter`, `MediaItem` ni `audio_service`. **No se persiste** `PlaybackResource`, `AudioSource`, URL, URL firmada ni estado de SDK.

## 16. Artwork impact

Ninguno: `ArtworkRepository`, `ArtworkCache`, `AlbumArtworkBuilder`, `TakiArtwork` y `ArtworkFileCache` sin cambios; no se persiste artwork. Las portadas locales siguen indexadas por `albumId` (`Song.albumId`), y `libraryAlbumIdsProvider` ahora se indexa por identidad. La generalización de artwork es la Fase 2.5.

## 17. Indexes/constraints

| Elemento | Decisión |
|---|---|
| `favorites` PK `(source, external_id)` | Unicidad + búsqueda por identidad (índice implícito) |
| `idx_favorites_added_at` | Se mantiene (orden de favoritos) |
| `idx_playlist_songs_position (playlist_id, position)` | Se mantiene (orden de una playlist, `move`, conteo) |
| Índice por `(source, external_id)` en `playlist_songs` | **No** se crea: ninguna consulta actual filtra por identidad; se añadirá con una consulta que lo necesite |
| `FOREIGN KEY … ON DELETE CASCADE` | Sin cambios |
| `CHECK` de identidad no vacía | Repite la invariante de dominio; garantiza que leer nunca lance |
| Transacciones | La migración completa es una transacción; las escrituras de playlists siguen siendo transacciones serializadas |

## 18. Tests

36 tests nuevos en total (795 → 831), además de adaptar los existentes sin eliminar ninguno:

- **`test/core/database/taki_database_test.dart`** (24 tests, contra bases reales con `sqflite_common_ffi`, con esquemas v1/v2 **congelados** como fixtures): instalación nueva; base v2 vacía; un favorito; varios favoritos y orden (incluido el desempate); playlist vacía; playlist con canciones (ids de entrada, posiciones, respaldo); ids de entrada con huecos; varias playlists; favoritos + playlists; secuencia de ids (con y sin entradas restantes); 2000 favoritos y 3000 entradas; reabrir una base v3; v1 → v3; **rollback ante fallo** y reintento tras repararlo; restricciones tras migrar (PK, misma cadena en otra fuente, ids opacos con ceros y mayúsculas, `CHECK`, FK, cascada, `foreign_key_check`); repositorios reales sobre datos migrados.
- **`sqflite_favorites_repository_test.dart`** y **`sqflite_playlists_repository_test.dart`**: adaptados a identidades y ampliados con ids alfanuméricos/con ceros/con `:` y `,`, misma cadena en otra fuente, mayúsculas, `CHECK`, unicidad, FK, reordenar/quitar/deshacer/`relink` con identidades ajenas.
- Adaptados a la nueva API: pruebas de casos de uso, `SongMatcher`, resolución de favoritos, páginas de Biblioteca/Favoritos/Reproduciendo/Playlists y los fakes; nuevo helper `ForeignSong`.
- **Mutaciones comprobadas:** se rompió a propósito la PK, el `CHECK`, la restauración de secuencia, la conservación de ids de entrada y otras; las pruebas fallaron. Dos mutaciones **no** fallan: quitar `CAST(song_id AS TEXT)` (equivalente: la afinidad `TEXT` de la columna ya convierte el entero a texto) y desactivar la comprobación de conteo de filas (**no se puede provocar** un conteo distinto con datos válidos; es una red de seguridad defensiva no ejercitada por tests).

## 19. Risks

| Riesgo | Mitigación |
|---|---|
| Migración sobre datos reales de usuarios | Copia verificada, conteos, `foreign_key_check`, transacción; probada con fixtures congelados de v1/v2 |
| Solo probada con `sqflite_common_ffi`, no en un dispositivo Android | El esquema usa SQL estándar; la capa Dart de `openDatabase`/`onUpgrade` es la misma. **No verificado en dispositivo**: conviene probar una actualización v2 → v3 en un teléfono con datos reales antes de publicar |
| Sin `onDowngrade` | Una app anterior no abrirá una base v3 |
| Regresión de rendimiento de la consulta de portadas con muchísimas entradas | Medida con 3000 entradas sin problema; reevaluar con volúmenes mucho mayores |
| Ids locales MediaStore no estables | El respaldo y `SongMatcher` siguen funcionando igual (identidad local → ruta → título) |
| `Song` sigue comparando todos sus campos, no la identidad | Sin cambio deliberado |

## 20. Deferred work

- **2.5** Artwork generalizado (referencia de artwork no entera).
- Decidir si se degrada o elimina `Song.id` (hoy lo usan MediaStore, `contentUri`, portadas por `albumId` y comparaciones de la UI como `song.id != currentSongId`).
- Índice por identidad en `playlist_songs` cuando haya una consulta que lo use.
- `onDowngrade` si se quiere una política de retroceso.
- Persistencia de la cola (aún inexistente): guardará identidades, nunca recursos.
- Fuentes remotas, catálogo y proveedores (fases posteriores).

## 21. Migration verification

Comprobado con pruebas sobre bases reales antes/después: número de filas, identidad (`('local', '<id>')` con `external_id` de tipo texto), `added_at` y orden de favoritos, `id`/`position`/`playlist_id` de cada entrada, respaldo de metadata, secuencia de ids, índices, PK, FK activadas y `foreign_key_check` vacío, reapertura sin cambios, y rollback completo ante un fallo. **No** se verificó en un dispositivo físico ni con una base real de un usuario.

## 22. Criteria for Phase 2.5

1. La persistencia ya identifica canciones por `MusicIdentity` (cumplido).
2. Definir una **referencia de artwork** que no sea un `albumId` entero (URL + política de tamaño o identidad de artwork), sin tocar la identidad de canción.
3. Decidir cómo encaja en `ArtworkRepository`/`ArtworkCache`/`AlbumArtworkBuilder` y qué hacer con `ArtworkFileCache` (lockscreen) según las restricciones de caché de cada fuente (UNKNOWN en 2.1B).
4. Las portadas de playlist (`libraryAlbumIdsProvider`, `coverIdentities`) deberán poder resolverse para identidades que no sean locales.
5. Mantener 6/6 en arquitectura y `core/domain` sin dependencias de tecnología.

## Validaciones

- `flutter test`: **831 pasan**. `flutter analyze`: sin problemas. `test/architecture`: **6/6**. `flutter build apk --debug`: correcto.
- Sin dependencias nuevas (`pubspec.*` sin cambios), sin HTTP ni SDK de proveedor, sin nombres de proveedor en `lib/`, sin nuevas excepciones entre features (los 6 imports permitidos son los mismos).
- Búsqueda de `song_id` en `lib/`: solo aparece en la migración (código que lee el esquema antiguo).

### Git status

- **Propios de 2.4 (modificados):** `lib/core/database/taki_database.dart`, `lib/core/domain/entities/song_reference.dart`, `lib/core/domain/entities/local_music_identity.dart`, `lib/core/domain/services/song_matcher.dart`, `lib/core/domain/entities/song.dart` (solo documentación), `favorite_entry.dart`, `favorites_repository.dart`, `favorites_usecases.dart`, `sqflite_favorites_repository.dart`, `favorites_providers.dart`, `playlist.dart`, `playlist_entry.dart`, `playlist_usecases.dart`, `sqflite_playlists_repository.dart`, `playlists_providers.dart`; UI solo en una línea cada una (`song_actions_sheet.dart`, `now_playing_page.dart`, `playlists_page.dart`, `add_to_playlist_sheet.dart`, `playlist_detail_page.dart` y `playlist_cover_albums.dart`, este último y `playlist_detail_page.dart` solo comentarios).
- **Propios de 2.4 (nuevos):** `test/helpers/foreign_song.dart`, este informe; y tests modificados: `taki_database_test.dart`, repositorios SQLite, casos de uso, `SongMatcher`, páginas y fakes.
- **De la Fase 2.3:** `just_audio_player_adapter.dart` y su test, `playback_resource.dart`, `playback_resolution_exception.dart`, `playback_resolver.dart`, `local_playback_resolver.dart` y sus tests.
- **De la Fase 2.2:** `music_identity.dart`, `local_music_identity.dart` (creado en 2.2, editado aquí) y sus tests.
- **Acumulados de las fases 1.8–1.9:** UI, tema, artwork, tests asociados e informes `PHASE_1_8*`/`PHASE_1_9*`; más los informes `PHASE_2_0`, `PHASE_2_1`, `PHASE_2_1B`.
- Sin commit ni push.
