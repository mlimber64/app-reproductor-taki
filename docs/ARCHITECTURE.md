# Arquitectura de Taki

Taki es un reproductor de música local para Android, 100 % cliente: sin backend,
sin anuncios, sin telemetría. El código sigue una **arquitectura hexagonal
(ports & adapters) organizada por features**.

## Estructura

```
lib/
  main.dart              Punto de entrada: ProviderScope + TakiApp
  app/                   Composición de la app (MaterialApp.router, rutas, tema)
    app.dart
    router.dart
    theme/
  core/                  Código transversal, sin lógica de negocio de una feature
    error/               Failures compartidos
    utils/
    constants/
    widgets/             Widgets genéricos reutilizables
  features/
    <feature>/
      domain/
        entities/        Modelos inmutables del negocio
        ports/           Interfaces (abstract interface class) que el dominio necesita
        usecases/        Casos de uso: una acción del negocio cada uno
      infrastructure/    Adapters que implementan los ports
      presentation/
        pages/           Pantallas
        widgets/         Widgets propios de la feature
        providers/       Providers de Riverpod (inyección + estado de UI)
```

Features actuales: `library`, `player`, `playlists`, `search`, `settings`.
La pestaña **Favoritos** vive en `library` (los favoritos son una vista filtrada
de la biblioteca).

## Reglas de dependencia

1. **`domain` es Dart puro.** No importa `package:flutter/*` ni paquetes
   externos. La única excepción permitida es `package:equatable`.
2. **`infrastructure` implementa los ports definidos en `domain`.** Aquí viven
   `just_audio`, `audio_service`, `sqflite`, `permission_handler`, los canales
   nativos propios (`taki/media_store`), etc. Nunca expone tipos de esos paquetes hacia afuera:
   los traduce a entidades de dominio.
3. **`presentation` usa los casos de uso mediante providers de Riverpod.** Los
   widgets no instancian adapters ni llaman a paquetes de infraestructura
   directamente.
4. **La dirección de las dependencias es siempre hacia adentro:**

   ```
   presentation ──► domain ◄── infrastructure
   ```

   `domain` no conoce a nadie. El cableado (qué adapter implementa qué port) se
   hace en `presentation/providers/<feature>_providers.dart`: es el único
   archivo de presentation que importa `infrastructure` (composition root).
   Páginas y widgets solo ven ports, casos de uso y providers. Lo que debe
   existir antes de `runApp` (el reproductor) se crea en `main.dart` y se
   inyecta con overrides.
5. **Entre features**, una feature puede importar el `domain` de otra (por
   ejemplo, `player` usa la entidad `Song` de `library`) y, desde su
   `presentation`, los providers de `presentation/providers` de otra (su API
   pública; p. ej. la Biblioteca usa `playSongsProvider`). Nunca su
   `infrastructure` ni sus páginas o widgets. Lo que combina varias features
   (p. ej. el menú de acciones de una canción: cola + favoritos + playlists)
   vive en `app/widgets/`, la capa que compone la app.
6. **`core`** no depende de ninguna feature.

## Fuente de audio intercambiable

La fuente de canciones es un **port**, no una implementación concreta:

```dart
// features/library/domain/ports/song_repository.dart
abstract interface class SongRepository {
  Future<List<Song>> getSongs();
}
```

- Adapter actual: `MediaStoreSongRepository`, que consulta MediaStore a través
  de nuestro canal nativo `taki/media_store`
  (`android/app/src/main/kotlin/.../MediaStoreChannel.kt`, un `FlutterPlugin`
  ligado al engine para que funcione también con la app cerrada). Las carátulas usan
  el port `ArtworkRepository` con el adapter `MediaStoreArtworkRepository`.
- Adapters futuros posibles: `NavidromeSongRepository` (Subsonic API),
  carpetas SAF, otro plugin, etc.

El adapter activo se elige en un provider:

```dart
final songRepositoryProvider = Provider<SongRepository>(
  (ref) => MediaStoreSongRepository(),
);
```

Sumar una fuente nueva = crear un adapter en `infrastructure/` y cambiar (o
combinar) ese provider. Ni el dominio ni la UI cambian.

## Reproducción

```
Biblioteca ──PlaySongs──► AudioPlayerPort ◄── JustAudioPlayerAdapter (just_audio)
                                ▲
notificación / bloqueo /        │ refleja estado y reenvía comandos
auriculares ──► audio_service ──► TakiAudioHandler
```

- `AudioPlayerPort` (domain) es el motor. La UI lo usa mediante casos de uso.
- `TakiAudioHandler` (infrastructure) es un `BaseAudioHandler` que publica
  `MediaItem` y `PlaybackState` en audio_service y reenvía los comandos del
  sistema al port. No tiene lógica propia de reproducción.
- `initPlayer()` configura `AudioSessionConfiguration.music()` e
  `AudioService.init`. `MainActivity` extiende `AudioServiceActivity` para
  compartir el FlutterEngine con el servicio.
- Las carátulas de la notificación se guardan como archivo en la caché de la
  app (`ArtworkFileCache`), reutilizando el port `ArtworkRepository`.

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
  `PRAGMA foreign_keys = ON` en cada conexión. `main.dart` la
  abre antes de `runApp` y la inyecta en `takiDatabaseProvider`. Si falla, la
  app arranca igual, los favoritos se muestran como no disponibles y
  "Reintentar" vuelve a abrirla.
- Migraciones: subir `TakiDatabase.version`, añadir un bloque
  `if (oldVersion < N)` en `_onUpgrade` y crear lo mismo en `_onCreate`.
  Historial: v1 `favorites`; v2 `playlists` y `playlist_songs` (entradas con
  posición contigua, la misma canción puede repetirse, borrado en cascada).
- `favorites` y `playlist_songs` guardan el id de MediaStore y una copia de
  respaldo (título, artista, álbum, duración, ruta). El servicio de dominio
  `SongMatcher` (library) reencuentra la canción por id → ruta → título +
  artista + duración ±1 s; `GetFavoriteSongs` y `GetPlaylistSongs` guardan el
  id nuevo si cambió y ocultan (sin borrar) lo que no está en la biblioteca.
- Los favoritos se resuelven cada vez que la biblioteca se carga o se
  refresca (`TakiApp` mantiene vivo `favoriteSongsProvider`).
- Tests con la base real en memoria vía `sqflite_common_ffi`.

## Testing

- `domain`: tests unitarios puros.
- `presentation`: widget tests sobrescribiendo providers
  (`ProviderScope(overrides: [...])`) con fakes o mocks de `mocktail`.
- `infrastructure`: tests de integración en dispositivo cuando dependan de
  plugins de plataforma.

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
