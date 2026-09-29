# Arquitectura de Taki

Taki es un reproductor de música local para Android. Hoy es 100 % cliente: lee
la música guardada en el teléfono, sin backend, sin cuentas, sin anuncios y sin
telemetría.

El código sigue una **arquitectura hexagonal (ports & adapters) organizada por
features**, con tres capas a nivel de app (`app`, `features`, `core`) y tres
capas dentro de cada feature (`domain`, `infrastructure`, `presentation`).

## Estructura

Árbol real de `lib/` (se omiten los archivos `.gitkeep`):

```
lib/
├── main.dart                     Composition root: crea los adapters que deben
│                                 existir antes de runApp y los inyecta
├── app/                          Composición de la app
│   ├── app.dart                  TakiApp: MaterialApp.router, locale es, tema
│   ├── router.dart               Rutas (go_router) y shell con barra inferior
│   ├── theme/
│   │   └── app_theme.dart        AppTheme: construye el ThemeData global
│   └── widgets/
│       └── song_actions_sheet.dart   Menú de acciones de una canción
├── core/                         Piezas compartidas, sin lógica de una feature
│   ├── domain/                   Núcleo de dominio musical (Dart puro)
│   │   ├── entities/             Song, SongReference
│   │   ├── ports/                ArtworkRepository
│   │   └── services/             SongMatcher
│   ├── artwork/                  ArtworkCache y providers de carátulas
│   ├── theme/                    AppColors (tokens visuales)
│   ├── widgets/                  ArtworkImage, SongTile, PlayShuffleButtons,
│   │                             MessageView, PlaceholderPage, song_actions
│   ├── database/                 TakiDatabase (taki.db) y takiDatabaseProvider
│   ├── constants/                LibraryConstants
│   ├── utils/                    duration_format, LruCache
│   └── error/                    Vacía (solo .gitkeep)
└── features/
    ├── library/                  Biblioteca (MediaStore) y Favoritos
    │   ├── domain/               entities, ports, services, usecases
    │   ├── infrastructure/
    │   └── presentation/         pages, providers (widgets/ vacía)
    ├── player/                   Reproducción, cola, notificación
    │   ├── domain/               entities, ports, usecases
    │   ├── infrastructure/
    │   └── presentation/         pages, providers, widgets
    ├── playlists/
    │   ├── domain/               entities, ports, usecases
    │   ├── infrastructure/
    │   └── presentation/         pages, providers, widgets
    ├── settings/                 Solo SettingsPage (usa PlaceholderPage); el
    │                             resto de carpetas están vacías
    └── search/                   Esqueleto vacío: solo carpetas con .gitkeep,
                                  sin código ni ruta en la app
```

Pestañas de la app: **Biblioteca**, **Playlists**, **Favoritos** y **Ajustes**.
Favoritos vive en la feature `library` (los favoritos son una vista filtrada de
la biblioteca). **Reproduciendo** y **Cola** son pantallas completas fuera del
shell.

## Capas

### `app`: composición

- Arranca la app (`TakiApp`), fija el locale (`es`) y aplica el tema.
- Navegación: `router.dart` con `StatefulShellRoute.indexedStack` (cada
  pestaña conserva su estado) y las rutas `/now-playing` y `/queue`.
- `AppTheme` (`app/theme/app_theme.dart`) construye el `ThemeData` Material 3
  oscuro a partir de los tokens de `core/theme` (Sora para títulos, DM Sans
  para el resto). Ambas son assets locales en `assets/fonts/`, declaradas en
  la sección `fonts:` de `pubspec.yaml`: no se descargan en tiempo de
  ejecución y `google_fonts` ya no es una dependencia.
- UI que coordina varias features: `showSongActions` / `SongActionsSheet`
  (`app/widgets/song_actions_sheet.dart`) combina cola (`player`), favoritos
  (`library`) y playlists (`playlists`).
- Inyecta en las páginas lo que ellas no pueden importar: el router pasa
  `showSongActions` a `LibraryPage`, `FavoritesPage` y `PlaylistDetailPage`,
  y los callbacks de navegación (`onOpenPlaylist`, `onOpenQueue`, `onOpen`).
- `TakiApp` mantiene vivo `favoriteSongsProvider` para que los favoritos se
  resuelvan cada vez que la biblioteca se carga o se refresca.

### `core`: piezas compartidas

`core` contiene solo lo que usan varias features o la app entera: el dominio
musical compartido, los tokens visuales, los widgets reutilizables, la
abstracción de carátulas y la base de datos local.

**`core` no debe contener lógica específica de una feature.** Algo entra en
`core` cuando lo necesitan varias features y puede expresarse sin conocer a
ninguna de ellas. Lo propio de una feature (sus casos de uso, sus
repositorios, sus páginas) se queda en la feature.

### `features`: funcionalidad

Cada feature se divide en tres capas:

- `domain/`: `entities/`, `ports/` (`abstract interface class`),
  `usecases/` (una acción del negocio cada uno) y, cuando hace falta,
  `services/` (lógica de dominio sin estado, p. ej. `SongFilter`).
- `infrastructure/`: adapters que implementan los ports con paquetes externos
  o canales nativos.
- `presentation/`: `pages/`, `widgets/` propios y `providers/` de Riverpod.

## Reglas de dependencia

### Entre capas de la app

```
app ──────► features ──────► core ──────► paquetes externos permitidos
 └──────────────────────────► core
```

Permitido:

- `app → features`
- `app → core`
- `features → core`
- `core → paquetes externos` (Flutter, Riverpod, equatable, sqflite…, según
  la carpeta; ver `core/domain` más abajo)

Prohibido:

- `features → app`
- `core → features`
- `core → app`
- `feature → otra feature`, salvo las excepciones documentadas abajo.

### Dentro de una feature

1. **`domain` es Dart puro.** No importa `package:flutter/*` ni paquetes
   externos; la única excepción es `package:equatable`. Puede importar
   `core/domain` y `core/constants`.
2. **`infrastructure` implementa los ports del dominio.** Aquí viven
   `just_audio`, `audio_service`, `audio_session`, `sqflite`,
   `permission_handler`, `device_info_plus`, `path_provider` y el canal nativo
   `taki/media_store`. No expone tipos de esos paquetes: los traduce a
   entidades de dominio. (Excepción conocida: `audioHandlerProvider` expone
   `TakiAudioHandler`; ver "Problemas conocidos".)
3. **`presentation` usa los casos de uso mediante providers de Riverpod.**
   Páginas y widgets no instancian adapters ni llaman a paquetes de
   infraestructura.
4. **La dirección es hacia adentro:**

   ```
   presentation ──► domain ◄── infrastructure
   ```

   El cableado (qué adapter implementa qué port) se hace en
   `presentation/providers/*_providers.dart`, el único lugar de presentation
   que importa `infrastructure`. Lo que debe existir antes de `runApp` se crea
   en `main.dart` (ver "Composition root").

### Excepciones feature → feature

Son 6 imports, todos hacia `presentation/providers` de otra feature (su API
pública) y desde la `presentation` de la feature que los usa. Ninguna feature
importa el `domain`, la `infrastructure`, las páginas ni los widgets de otra.

| # | Origen | Destino | Qué usa | Motivo |
|---|---|---|---|---|
| 1 | `library/presentation/pages/library_page.dart` | `player/presentation/providers/player_providers.dart` | `playSongsProvider`, `currentSongProvider`, `notificationPermissionProvider` | Tocar una canción reproduce la lista desde ahí, la fila que suena se resalta y, tras empezar a reproducir, se pide el permiso de notificaciones |
| 2 | `library/presentation/pages/favorites_page.dart` | `player/presentation/providers/player_providers.dart` | `playSongsProvider`, `playSongsShuffledProvider`, `currentSongProvider`, `notificationPermissionProvider` | Lo mismo para Favoritos, más Reproducir/Aleatorio |
| 3 | `player/presentation/pages/now_playing_page.dart` | `library/presentation/providers/favorites_providers.dart` | `isFavoriteProvider`, `toggleFavoriteProvider` | El corazón de Reproduciendo marca/desmarca la canción; los favoritos viven en `library` |
| 4 | `playlists/presentation/providers/playlists_providers.dart` | `library/presentation/providers/songs_notifier.dart` | `songsProvider`, `LibraryLoaded` | Las entradas de una playlist se resuelven contra las canciones escaneadas (`playlistItemsProvider`), los mosaicos de portada usan sus `albumId` y "Reintentar" reescanea la biblioteca si falló |
| 5 | `playlists/presentation/pages/playlist_detail_page.dart` | `library/presentation/providers/songs_notifier.dart` | `songsProvider`, `LibraryNeedsPermission` | El detalle muestra el mismo estado de permiso que la biblioteca (pedir acceso / abrir ajustes) y pull-to-refresh reescanea |
| 6 | `playlists/presentation/pages/playlist_detail_page.dart` | `player/presentation/providers/player_providers.dart` | `playSongsProvider`, `playSongsShuffledProvider`, `currentSongProvider`, `notificationPermissionProvider` | Reproducir, mezclar y resaltar la canción que suena |

**Por qué son aceptables por ahora:** son dependencias de composición entre
providers, no de modelo ni de UI. Reproducir, consultar favoritos o leer la
biblioteca son capacidades que ya tienen una API pública en su feature, y
envolverlas en ports/commands de `core` solo para cumplir la regla añadiría
una capa sin comportamiento propio. `test/architecture/dependency_rules_test.dart`
las enumera una a una; cualquier import nuevo entre features hace fallar el
test.

> **Estas excepciones deberán reevaluarse cuando Taki incorpore el catálogo
> musical online**, en particular la 4 y la 5: hoy las playlists dependen de
> la biblioteca local escaneada.

## `core/domain`: núcleo de dominio compartido

| Elemento | Archivo | Qué es |
|---|---|---|
| `Song` | `entities/song.dart` | Canción de la biblioteca: id, título, artista, álbum, `albumId`, duración, ruta, `contentUri`, fecha y carpeta |
| `SongReference` | `entities/song_reference.dart` | Referencia guardada a una canción (id + copia de respaldo de título, artista, duración y ruta). La implementan `FavoriteEntry` (`library`) y `PlaylistEntry` (`playlists`) |
| `SongMatcher` | `services/song_matcher.dart` | Reencuentra una `SongReference` en la biblioteca: id → ruta → título + artista con duración ±1 s |
| `ArtworkRepository` | `ports/artwork_repository.dart` | Port de carátulas: `getAlbumArtwork(albumId, size)` → bytes o `null` |

Reglas:

- Es **Dart puro**: no depende de Flutter, de Riverpod, de ninguna
  infraestructura ni de ninguna feature. Solo usa `package:equatable` (y
  `dart:*`).
- Lo usan `library`, `player` y `playlists`.

## `core/artwork`: carátulas compartidas

- **Port:** `ArtworkRepository` (en `core/domain/ports`).
- **`ArtworkCache`** (`artwork_cache.dart`): caché LRU en memoria de bytes de
  carátula por `(albumId, size)`, con deduplicación de peticiones en curso;
  también recuerda los álbumes sin carátula.
- **`artworkRepositoryProvider`** (`artwork_providers.dart`): no tiene
  implementación por defecto; lanza `UnimplementedError` si nadie lo
  sobrescribe.
- **`artworkCacheProvider`**: `ArtworkCache` sobre el repositorio anterior.
  `SongsNotifier.rescan` la vacía al reescanear.
- **Implementación concreta:** `MediaStoreArtworkRepository`
  (`features/library/infrastructure/`), que lee las miniaturas de MediaStore
  por el canal `taki/media_store`. `main.dart` crea **una instancia** y la usa
  para el reproductor (`initPlayer`) y para sobrescribir
  `artworkRepositoryProvider`. Solo hay carátulas locales.

En el reproductor, `ArtworkFileCache` (`features/player/infrastructure/`)
reutiliza el mismo port para guardar las carátulas como archivo, porque la
notificación y la pantalla de bloqueo necesitan una URI.

## `core/theme` y `core/widgets`

**`core/theme/app_colors.dart`**: `AppColors`, la paleta "Medianoche + ámbar"
(superficies, texto, acento, acentos alternativos y colores del reproductor).
Son tokens: no construye temas. `AppTheme` (en `app/`) compone el
`ThemeData` con ellos.

**`core/widgets/`**: widgets reutilizables que no dependen de ninguna feature
(solo de `core` y de Flutter/Riverpod):

| Widget | Uso |
|---|---|
| `ArtworkImage` | Carátula con esquinas redondeadas; lee `artworkCacheProvider`. Recibe `albumId`, `size`, `borderRadius` |
| `SongTile` | Fila de canción (carátula, título, artista, duración), alto fijo 64. Recibe `song`, `isCurrent`, `onTap`, `onLongPress`, `trailing` |
| `PlayShuffleButtons` | Botones Reproducir/Aleatorio; recibe los callbacks |
| `MessageView` | Estado vacío/error/permiso con acción y pull-to-refresh opcionales |
| `PlaceholderPage` | Pantalla provisional (la usa Ajustes) |
| `song_actions.dart` | `ExtraSongAction` (acción extra de una pantalla) y el typedef `ShowSongActions`, la firma del menú de canción que implementa `app/` |

Un widget de `core/widgets` no debe importar ninguna feature ni `app/`. Si
necesita datos de una feature, los recibe por parámetro o mediante un port de
`core/domain`.

## Composition root

**`main.dart`** crea, antes de `runApp`, lo que debe existir desde el arranque
y lo inyecta con overrides de `ProviderScope`:

| Qué crea | Clase concreta | Provider que sobrescribe |
|---|---|---|
| Carátulas | `MediaStoreArtworkRepository` | `artworkRepositoryProvider` |
| Motor de reproducción (`initPlayer`) | `JustAudioPlayerAdapter` (`AudioPlayerPort`) | `audioPlayerPortProvider` |
| Handler del sistema (`initPlayer`) | `TakiAudioHandler` (vía `AudioService.init`) | `audioHandlerProvider` |
| Base de datos (`TakiDatabase.tryOpen`) | `Database` de sqflite | `takiDatabaseProvider` (solo si abrió) |

`initPlayer()` (`features/player/infrastructure/player_bootstrap.dart`)
configura `AudioSessionConfiguration.music()` e inicia `AudioService`.

El resto de adapters se cablean en el composition root de cada feature, con
un valor por defecto que los tests sobrescriben:

| Archivo | Port → adapter |
|---|---|
| `library/presentation/providers/library_providers.dart` | `SongRepository` → `MediaStoreSongRepository`; `MediaPermissionPort` → `PermissionHandlerMediaPermission` |
| `library/presentation/providers/favorites_providers.dart` | `FavoritesRepository` → `SqfliteFavoritesRepository` |
| `playlists/presentation/providers/playlists_providers.dart` | `PlaylistsRepository` → `SqflitePlaylistsRepository` |
| `player/presentation/providers/player_providers.dart` | `NotificationPermissionPort` → `PermissionHandlerNotificationPermission` |

`app/router.dart` completa la composición de UI: inyecta `showSongActions` y
los callbacks de navegación en las páginas.

## Fuente de canciones

La fuente de canciones es un port de `library`:

```dart
// features/library/domain/ports/song_repository.dart
abstract interface class SongRepository {
  Future<List<Song>> getSongs();
}
```

- Adapter actual (el único): `MediaStoreSongRepository`, que consulta
  MediaStore por el canal nativo `taki/media_store`
  (`android/app/src/main/kotlin/com/limbermendoza/taki/MediaStoreChannel.kt`).
  El canal es un `FlutterPlugin` que `MainActivity.configureFlutterEngine`
  registra en el engine compartido con el servicio de audio.
- `GetSongs` aplica `SongFilter`: descarta audios de menos de 30 s y los que
  están en carpetas excluidas (`LibraryConstants`).
- Para sumar otra fuente basta con otro adapter de `SongRepository` y cambiar
  (o combinar) `songRepositoryProvider`. **Hoy no existe ninguna otra
  fuente.**

## Reproducción

```
Biblioteca ──PlaySongs──► AudioPlayerPort ◄── JustAudioPlayerAdapter (just_audio)
                                ▲
notificación / bloqueo /        │ refleja estado y reenvía comandos
auriculares ──► audio_service ──► TakiAudioHandler
```

- `AudioPlayerPort` (`player/domain`) es el motor. La UI lo usa mediante
  casos de uso (`player_usecases.dart`).
- `TakiAudioHandler` (`player/infrastructure`) es un `BaseAudioHandler` que
  publica `MediaItem` y `PlaybackState` en audio_service y reenvía los
  comandos del sistema al port. No tiene lógica propia de reproducción.
- `MainActivity` extiende `AudioServiceActivity` para compartir el
  FlutterEngine con el servicio.
- Si una canción falla, se emite por `errors` y se salta a la siguiente
  (hasta 10 seguidas; después pausa).

### Cola

- `PlaybackState.queue` es la **cola real**: el orden de reproducción (con
  aleatorio, el mezclado). Todos los índices del port se refieren a ella; la
  UI traduce los suyos (p. ej. "A continuación" empieza en `upcomingStart`).
- Regla de dominio: solo se edita lo que viene después de la canción actual
  (`PlaybackState.isUpcoming`). `AddToQueue` y `PlayNext` empiezan a
  reproducir si no suena nada.
- El adapter mantiene dos órdenes: el de las fuentes de just_audio (original)
  y el de reproducción. Con aleatorio usa `QueueShuffleOrder`, un
  `ShuffleOrder` propio que controla dónde quedan las canciones insertadas
  (just_audio envía ese orden a ExoPlayer en cada add/insert/move/remove, sin
  recargar la cola). "Mover" con aleatorio solo reordena la reproducción.

## Base de datos local

- `core/database/taki_database.dart` abre `taki.db` (sqflite), versión 2, con
  `PRAGMA foreign_keys = ON` en cada conexión. `main.dart` la abre antes de
  `runApp` y la inyecta en `takiDatabaseProvider`. Si falla, la app arranca
  igual, favoritos y playlists se muestran como no disponibles y
  "Reintentar" vuelve a abrirla.
- Migraciones: subir `TakiDatabase.version`, añadir un bloque
  `if (oldVersion < N)` en `_onUpgrade` y crear lo mismo en `_onCreate`.
  Historial: v1 `favorites`; v2 `playlists` y `playlist_songs` (entradas con
  posición contigua, la misma canción puede repetirse, borrado en cascada).
- `favorites` y `playlist_songs` guardan el id de MediaStore y una copia de
  respaldo (título, artista, álbum, duración, ruta). `SongMatcher`
  (`core/domain`) reencuentra la canción; `GetFavoriteSongs` y
  `GetPlaylistSongs` guardan el id nuevo si cambió y ocultan (sin borrar) lo
  que no está en la biblioteca.

## Testing

`test/` replica la estructura de `lib/` (`app/`, `core/`, `features/`) y
añade `helpers/` (fakes compartidos) y `architecture/`.

- `domain`: tests unitarios puros.
- `presentation`: widget tests sobrescribiendo providers
  (`ProviderScope(overrides: [...])`) con fakes o mocks de `mocktail`.
  `libraryOverrides()` (`test/helpers/library_fakes.dart`) sobrescribe los
  ports de uso común, incluido `artworkRepositoryProvider`.
- `infrastructure`: tests sin dispositivo. `JustAudioPlayerAdapter` con un
  reproductor falso (`test/helpers/fake_just_audio_player.dart`),
  `MediaStoreSongRepository` con un `MethodChannel` simulado, y los
  repositorios sqflite y `TakiDatabase` con la base real en memoria vía
  `sqflite_common_ffi`.
- Sin tests automáticos: el código Kotlin (`MediaStoreChannel`) y el
  comportamiento real de audio_service (notificación, pantalla de bloqueo).

### Test de arquitectura

`test/architecture/dependency_rules_test.dart` lee los `import`/`export` de
todos los archivos `.dart` de `lib/` (resuelve las rutas relativas y las
`package:taki/...`; ignora `dart:`) y comprueba:

1. **core no depende de app ni de features**: ningún archivo de `lib/core/`
   importa `lib/app/` ni `lib/features/`.
2. **Las features no dependen de app**: ningún archivo de
   `lib/features/<x>/` importa `lib/app/`.
3. **Sin imports entre features salvo las excepciones**: un import de
   `features/<a>/…` a `features/<b>/…` (con `a ≠ b`) solo pasa si el par
   exacto archivo → archivo está en su lista `_allowedCrossFeature` (las 6
   de la tabla anterior).
4. **Las excepciones siguen existiendo**: falla si alguna entrada de
   `_allowedCrossFeature` ya no se usa, para que la lista no quede obsoleta.
5. **`core/domain` es Dart puro**: sus imports de paquetes externos solo
   pueden ser `package:equatable/`.

Además comprueba que encontró imports (para no pasar en vacío).

No comprueba (siguen siendo reglas de revisión manual): que el `domain` de
cada feature sea Dart puro, que solo los `*_providers.dart` importen
`infrastructure`, ni qué partes de `core` importa `core/domain`.

**Añadir una excepción** requiere actualizar `_allowedCrossFeature` en el
test y la tabla de este documento.

## Decisiones

- **Persistencia: `sqflite`** en lugar de `isar`. La última versión estable de
  isar (3.1.0+1) no se mantiene desde 2023, falla con Android Gradle Plugin 8+
  (falta `namespace`) y su generador de código entra en conflicto con versiones
  recientes de `analyzer`/`build_runner`. `sqflite` es estable, mantenido y
  suficiente para playlists, favoritos y ajustes.
- **Lectura de la biblioteca: canal nativo propio (MediaStore)** en lugar de
  `on_audio_query`. El paquete original (2.9.0) está abandonado desde 2023 y no
  compila con AGP 8+ (falta `namespace`). Su fork mantenido
  (`on_audio_query_pluse`) compila, pero su código nativo exige además
  `READ_MEDIA_IMAGES` (Android 13+) o `WRITE_EXTERNAL_STORAGE` (≤12) y falla
  sin ellos. Pedir acceso a fotos no tiene sentido en un reproductor y Google
  Play lo restringe. Los plugins de este tipo se abandonan con facilidad, así
  que mantenemos ~200 líneas de Kotlin propias. Solo pedimos
  `READ_MEDIA_AUDIO` (13+) y `READ_EXTERNAL_STORAGE` (≤12, `maxSdkVersion 32`).
  El port `SongRepository` sigue siendo intercambiable.
- **`permission_handler` fijado en 12.x.** La 13.x arrastra
  `permission_handler_android` 14.x, que requiere Android Gradle Plugin 9; el
  proyecto usa AGP 8.11. Subir cuando migremos a AGP 9.
- **`device_info_plus`** para conocer la versión de Android y elegir el permiso
  correcto (`Permission.audio` en 13+, `Permission.storage` antes).
- **Cola con `AudioPlayer.setAudioSources`** (`ConcatenatingAudioSource` está
  deprecado en just_audio 0.10) con `useLazyPreparation`. La cola completa no
  se publica en la MediaSession: con miles de canciones puede superar el
  límite de Binder de Android. Solo se publica la canción actual.
- **Estado / DI: Riverpod.** **Navegación: go_router** con
  `StatefulShellRoute.indexedStack` (cada pestaña conserva su estado).
- **Dominio compartido en `core/domain`** (Fase 0.3): `Song` y lo que la
  rodea lo usan todas las features; tenerlo en `library` obligaba a `player`
  y `playlists` a depender de otra feature.
- **Menú de canción inyectado por constructor** (Fase 0.3): combina tres
  features, así que vive en `app/`; las páginas reciben un `ShowSongActions`
  para no depender de `app/`.

## Problemas conocidos

Detectados en la auditoría (Fase 0.1) y aún sin resolver:

- `audioHandlerProvider` expone el tipo de infraestructura `TakiAudioHandler`
  y ningún código lo lee.
- `core/database` depende de `sqflite` y crea las tablas de `favorites` y
  `playlists`: `core` conoce el esquema de dos features.
- `core/constants/library_constants.dart` contiene constantes que solo usa
  `library`.
- `MediaStoreChannel` se registra desde `MainActivity`; si el engine se
  creara sin la Activity, el canal no existiría (no verificado en
  dispositivo).
- `addToQueue` y `playNext` comprueban si la cola está vacía fuera de la
  serialización de operaciones del adapter.
- La firma de release usa la clave de debug.
- `core/error` y `features/search` son carpetas vacías; `settings` solo tiene
  una pantalla provisional.
