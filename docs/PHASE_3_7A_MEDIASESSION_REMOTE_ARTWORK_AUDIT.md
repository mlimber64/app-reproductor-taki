# Fase 3.7A — Auditoría de artwork remoto hacia MediaSession / lockscreen

Fase **solo de auditoría y documentación**: no se modificó producción, tests,
dependencias ni configuración Android. Cubre el `REAL_LEAK 3` de la auditoría 3.3.
Todo lo afirmado sale de leer el código de Taki y el código fuente de
`audio_service 0.18.19` (pub cache); nada se ha probado en dispositivo (no hay
Android conectado).

## 1. Resumen ejecutivo

- **Dónde se pierde:** en un único `if`:
  `ArtworkFileCache.artUriFor` (`features/player/infrastructure/artwork_file_cache.dart:35`)
  hace `if (artwork is! LocalArtworkReference) return null;`. Para una
  `RemoteArtworkReference` devuelve `null` **sin intentar nada**; el handler
  publica el `MediaItem` sin `artUri`.
- **Todo lo demás ya es genérico:** `TakiAudioHandler` solo llama a
  `artUriFor(song)`, adjunta el `artUri` con guarda contra carreras y no sabe de
  albumes; el plugin acepta `file://` (el camino que usa Taki) y se encarga de
  decodificar y pasar el bitmap a la sesión.
- **Cambio mínimo:** hacer que `ArtworkFileCache` (ya existe, ya escribe archivos
  y los reutiliza) resuelva también `RemoteArtworkReference` usando el
  `RemoteArtworkLoader` **existente** (`HttpRemoteArtworkLoader`, que ya valida
  esquema, tamaño, timeout y formato) y escriba los bytes en un archivo con nombre
  derivado de la URL. No hace falta segundo cache, ni segundo cliente HTTP, ni
  tocar `TakiAudioHandler`, `Song` ni el manifest.
- **Estado:** READY FOR IMPLEMENTATION (3.7B).

## 2. Flujo actual local (funciona)

| Paso | Archivo / símbolo | Entrada → salida | Local | Remota | `albumId` | Ruta FS | MediaStore |
|---|---|---|---|---|---|---|---|
| 1 | `Song.artwork` (`song.dart`) | `Song` → `ArtworkReference` | sí | sí | no | no | no |
| 2 | `TakiAudioHandler._publishMediaItem` (`taki_audio_handler.dart:124`) | `Song?` → `MediaItem` | agnóstico | agnóstico | no | no | no |
| 3 | `_toMediaItem` (`:150`) | `Song` → `MediaItem(id, title, artist, album, duration)` **sin** `artUri` | agnóstico | agnóstico | no | no | no |
| 4 | `ArtworkFileCache.artUriFor` (`artwork_file_cache.dart:33`) | `Song` → `Uri?` (`file://…`) | **sí** | **no (`return null`)** | **sí** | **sí (escribe)** | indirecto (vía `ArtworkRepository`) |
| 5 | `ArtworkRepository.getAlbumArtwork(albumId, size)` (`MediaStoreArtworkRepository`) | `albumId` → bytes JPEG/PNG | sí | no | **sí** | no | **sí** |
| 6 | `mediaItem.add(item.copyWith(artUri: …))` (handler `:136`) | `MediaItem` + `Uri` | agnóstico | agnóstico | no | no | no |
| 7 | `AudioService` (Dart, `audio_service.dart:1031-1110`) | `mediaItem` stream → plataforma | `file` → `artCacheFile` | `http(s)` → ver §4 | no | lee ruta | no |
| 8 | `AudioService.java` `setMetadata` / `loadArtBitmap` (`:786`, `:175`) | `artCacheFile` → `Bitmap` → `METADATA_KEY_ALBUM_ART` y `DISPLAY_ICON` | sí | sí (si es archivo) | no | **lee archivo** | no |
| 9 | `MediaSession` → notificación → lockscreen | metadata + bitmap | — | — | — | — | — |

Detalles de `ArtworkFileCache` (única pieza acoplada a lo local):
- Ruta: `getTemporaryDirectory()/artwork/album_${albumId}_${size}.jpg` (`size` = 512).
- Reutiliza el archivo si existe (`file.exists()`); si no, pide bytes al repositorio y
  escribe con `flush`. Los bytes se guardan **tal como llegan** (JPEG/PNG) con
  extensión `.jpg`; el plugin decodifica con `BitmapFactory`, que no mira la extensión.
- `null`/vacío → recuerda el `albumId` como «sin carátula» **solo en memoria** (sesión).
- Cualquier excepción → `null` («sin carátula antes que sin notificación»); el fallo
  **no** se memoiza.
- **Sin limpieza ni límite de tamaño/cantidad:** vive en el cache dir de Android
  (el sistema puede vaciarlo). Sobrevive reinicios de la app.
- Construcción: `initPlayer` crea `ArtworkFileCache(artwork)` con el
  `MediaStoreArtworkRepository`; **no recibe** ningún `RemoteArtworkLoader`.

## 3. Flujo actual remoto (cómo se pierde)

`Song(artwork: RemoteArtworkReference('https://…/x.jpg?width=300'))`:

1. `Song.artwork` conserva la referencia (correcto).
2. `_publishMediaItem` publica el `MediaItem` **sin** `artUri` (siempre se hace
   primero, para no retrasar la notificación) → título, artista, álbum y duración
   aparecen (los remotos sí son universales).
3. `artUriFor(song)` → `artwork is! LocalArtworkReference` → **`return null`**.
4. El handler no adjunta nada (`if (artUri != null …)`).
5. El plugin recibe un `MediaItem` con `artUri == null` →
   `setMediaItem` sin `artCacheFile` → `setMetadata` pone `artBitmap = null`.
6. Notificación/lockscreen/auriculares: metadata sin carátula.

Respuestas concretas:
- **¿Dónde se descarta?** Solo en `artwork_file_cache.dart:35`.
- **¿Dónde se ignora / pasa a `null`?** Mismo punto; el handler lo trata como «sin
  carátula».
- **¿Dónde se espera exclusivamente `LocalArtworkReference`?** Ese `is!` y la lectura
  `artwork.albumId` de la línea siguiente. Nada más en `features/player`.
- **¿Hay código que ya acepte una URL remota?** `HttpRemoteArtworkLoader` (core) y
  el propio `audio_service` (§4); el handler no.
- **¿Hay razón técnica para exigir archivo local?** Sí para el camino de Taki: el
  plugin solo pasa un **archivo** (`artCacheFile`) al lado nativo, y `AudioService.java`
  lo decodifica; un `http` lo descarga antes el lado Dart del plugin (§4). No hay
  razón para exigir que sea de MediaStore.

## 4. `MediaItem` y `audio_service` (lo que acepta `artUri`)

Código leído en `audio_service-0.18.19/lib/audio_service.dart` y `android/.../AudioService.java`:

| `artUri` | Qué hace el plugin |
|---|---|
| `null` | `setMediaItem` sin carátula |
| `content://` | Android la abre con `ContentResolver` y la decodifica |
| `file://` | `sendToPlatform(artUri.toFilePath())` → `artCacheFile` → `BitmapFactory.decodeFile` |
| `http(s)://` | **el plugin la descarga él mismo** con `AudioService.cacheManager` (`DefaultCacheManager` de `flutter_cache_manager`, dependencia transitiva ya presente), manda primero la metadata sin carátula y luego la reenvía con el archivo; lleva su propia guarda `artFetchOperationId` |

Hay por tanto **una alternativa de una línea** (`artUri: Uri.parse(remote.url)`),
que funcionaría, pero se **descarta**: crea un segundo stack HTTP (`http` +
`flutter_cache_manager`) que **se salta** las validaciones de Taki (timeout 10 s,
tope 5 MB, firma de imagen, esquema/host), un segundo caché con su propio ciclo de
vida (stale period por defecto) y no pasa por el `RemoteArtworkLoader`. La opción
elegida mantiene un solo camino de descarga.

Construcción actual de `MediaItem` (`taki_audio_handler.dart`):
- `id` = `Uri.encodeComponent(source)/Uri.encodeComponent(externalId)`; `title`,
  `artist`, `album`, `duration` (`null` si `durationMs <= 0`). Sin `artUri` inicial.
- Se crea/publica **una vez por cambio de `Song`**: `currentSong` =
  `playbackState.map(currentSong).distinct()`, con `Song` igual por valor (incluye
  `artwork`). Cambios de posición y de cola no republican el `MediaItem` (solo
  `playbackState`). El handler **no** publica `queue` de audio_service.
- Tras `artUriFor`, si el `MediaItem` actual sigue siendo el mismo `id`, se publica
  `item.copyWith(artUri: …)` (segunda emisión, misma canción). Hay test de la carrera
  A→B («una carátula tardía de la canción anterior no se pega a la actual»).
- `artUriFor` se espera **después** de publicar la metadata: no bloquea el cambio de
  canción ni la reproducción.

## 5. Android / MediaSession

- `AndroidManifest.xml`: servicio `com.ryanheise.audioservice.AudioService`
  (`foregroundServiceType="mediaPlayback"`), `MediaButtonReceiver`, permisos
  `INTERNET`, `FOREGROUND_SERVICE(_MEDIA_PLAYBACK)`, `WAKE_LOCK`,
  `POST_NOTIFICATIONS`; config en `initPlayer` (canal, icono, sin
  `artDownscaleWidth`).
- El bitmap lo **decodifica el propio proceso de la app** desde un archivo del cache
  dir y lo coloca en `METADATA_KEY_ALBUM_ART` y `DISPLAY_ICON` (la razón explícita del
  plugin: lockscreen en Android < 11). Por eso **no hace falta** `FileProvider`, permisos
  nuevos ni exponer URIs a SystemUI.
- Para el camino por archivo no hay que tocar el manifest. `INTERNET` ya existe (la
  descarga la hace Dart con `dart:io`, que no se rige por el cleartext policy de Java).
- Sin `artDownscale*`, se decodifica el bitmap completo: aceptable con 300–512 px.

## 6. `ArtworkFileCache`: ¿puede ser genérico?

| Pregunta | Respuesta |
|---|---|
| A. ¿acepta bytes genéricos? | No hoy: pide bytes a `ArtworkRepository.getAlbumArtwork(albumId)` |
| B. ¿solo artwork local? | Sí (por el `is!` y por no recibir un loader remoto) |
| C. ¿acoplado a `albumId`? | Sí: nombre de archivo, `_withoutArtwork: Set<int>` y la petición |
| D. ¿puede ampliarse sin segundo cache? | **Sí**: la lógica «archivo si existe, si no bytes → escribir → `Uri`» es independiente del origen de los bytes |

`RemoteArtworkLoader.load(reference, size:)` devuelve bytes de imagen ya
validados (JPEG/PNG/GIF/WebP, ≤ 5 MB, https/http con host, timeout 10 s, redirecciones
seguidas por `HttpClient`) o lanza `ArtworkLoadException`. `size` se ignora (la URL
de Jamendo ya lleva `width=300`). **Los bytes que ya acepta son suficientes** para
generar el archivo de MediaSession: todos esos formatos los decodifica
`BitmapFactory` (GIF, primer fotograma).

Validaciones existentes (no se duplican): esquema `http/https` y host
(`HttpRemoteArtworkLoader` y también en el mapper de Jamendo), tope de bytes
(`IoArtworkHttpClient` y loader), timeout (cliente y loader), firma de formato,
estado 2xx. No hay validación de dimensiones.

## 7. Lifecycle (hoy y para remoto)

| Cuestión | Hoy (local) | Remoto (con la propuesta) |
|---|---|---|
| Cuándo se escribe | primera vez que suena una canción de ese álbum | primera vez que suena una canción con esa URL |
| Cuándo se reutiliza | `file.exists()` | igual, nombre por URL |
| Cuándo se elimina | nunca (lo purga Android al limpiar cache) | igual |
| Cambia la canción | handler publica el `MediaItem` nuevo; guarda por `id` | igual |
| URL distinta | n/a | otro archivo (clave = URL) |
| Fallo de descarga | `null`, sin memo | `null`, sin memo (fallo transitorio) |
| Archivo borrado | se vuelve a pedir y escribir | igual; si se borra tras entregar la `Uri`, el plugin no pinta carátula sin crash (`try/catch` en `loadArtBitmap`) |
| Reinicio de la app | el archivo sigue (si el SO no lo purgó) | igual: debe sobrevivir al reinicio (barato y evita redescargar); no hace falta persistencia nueva |

## 8. Cache / performance

- `artUriFor` se invoca **una vez por cambio de `Song`**, no por evento de playback.
- El archivo evita descargas repetidas entre canciones y entre sesiones; **no hay
  deduplicación de peticiones en vuelo**: dos llamadas simultáneas con la misma URL
  descargarían dos veces y escribirían el mismo archivo (hoy lo mismo para locales,
  pero la lectura local es barata).
- Trabajo async existente: `_publishMediaItem` es `async`; varias invocaciones pueden
  coexistir (saltos rápidos) sin bloquear; las respuestas viejas se descartan por
  `id`.
- Hay un riesgo latente: `writeAsBytes` no es atómico y `exists()` podría ver un
  archivo a medio escribir (§12).

## 9. Fallbacks (comportamiento actual según el código)

| Caso | Hoy |
|---|---|
| A. Local con carátula | `file://` → carátula en notificación/lockscreen |
| B. Local sin carátula | bytes `null`/vacíos → `null`, recordado en sesión → sin carátula |
| C. Remota con carátula | **`null`** (no se intenta) → sin carátula |
| D. Remota `Unavailable` | `null` |
| E. Loader remoto falla | no aplica hoy (no se llama) |
| F. Archivo ausente | local: se regenera; si desaparece después de entregar la URI, sin carátula y sin crash |
| G. Canción sin carátula | `null` |

## 10. Propuesta de mínimo cambio (no implementada)

1. **¿Reutilizar `ArtworkFileCache`?** Sí.
2. **API mínima:** `ArtworkFileCache({RemoteArtworkLoader? remoteLoader, …})`.
   `artUriFor(Song)` sigue igual de firma y despacha por `song.artwork`:
   `LocalArtworkReference` → camino actual **sin cambios**; `RemoteArtworkReference`
   → camino nuevo; `Unavailable` → `null`. Sin loader → remotas devuelven `null`
   (comportamiento actual).
3. **Dónde se resuelve `Remote → file`:** dentro de `ArtworkFileCache`
   (`features/player/infrastructure`): `remoteLoader.load(ref, size: size)` → bytes →
   `…/artwork/remote_<hash(url)>.img` (hash estable FNV-1a de 64 bits sobre la URL;
   **no** `String.hashCode`), escrito en archivo temporal y renombrado (atómico).
4. **Quién espera la operación:** el handler, como ahora, **después** de publicar la
   metadata y fuera del camino de reproducción (sin cambios en `TakiAudioHandler`).
5. **`MediaItem.artUri`:** `file.uri` (`file://`), igual que lo local; el handler lo
   adjunta con `copyWith` si el `id` sigue siendo el actual.
6. **Fallback si falla:** `null` → metadata sin carátula (hoy), sin error visible, sin
   reintento automático, sin memoizar el fallo.
7. **Evitar descargas repetidas:** archivo existente (entre sesiones) + `Map<String,
   Future<Uri?>>` de peticiones en vuelo por URL.
8. **Archivos a modificar:** `artwork_file_cache.dart`, `player_bootstrap.dart`
   (parámetro opcional `remoteArtworkLoader` → `ArtworkFileCache`), `main.dart`
   (crear **una** instancia `HttpRemoteArtworkLoader(http)` antes de `initPlayer` y
   reutilizarla en el override de `remoteArtworkLoaderProvider`). Si se quiere,
   `docs/`.
9. **Archivos que NO se modifican:** `TakiAudioHandler`, `Song`, `LocalSong`,
   `MusicIdentity`, `ArtworkReference`, `ArtworkCache`, `RemoteArtworkLoader` /
   `HttpRemoteArtworkLoader`, `AndroidManifest.xml`, `pubspec.yaml`,
   `JustAudioPlayerAdapter`, Search/Favoritos/Playlists.
10. **Tests necesarios** (en `artwork_file_cache_test.dart`, con loader falso y
    directorio temporal): remota con carátula → archivo y `Uri`; segunda llamada no
    vuelve a cargar; URL distinta → archivo distinto; mismo URL concurrente → una
    sola carga; loader lanza → `null` y reintenta en la siguiente; loader `null`/vacío
    → `null`; `Unavailable` → `null`; sin loader → `null`; local sin cambios; archivo
    borrado → se regenera; escritura atómica (sin archivo parcial visible); nombre
    estable. En `taki_audio_handler_test.dart`: una `Song` remota adjunta el `artUri`
    que devuelve la caché y la carrera A→B sigue funcionando con remotas.

### Arquitectura de la solución

`core/domain` sin Flutter (`RemoteArtworkLoader` ya es un puerto ahí);
`features/player/infrastructure` usa `dart:io`/`path_provider` como ya hace y depende
solo del puerto de `core` (no de Jamendo ni de `core/artwork`). `core/artwork` no
cambia. Sin nuevas excepciones en `dependency_rules_test`.

## 11. Riesgos

| Riesgo | Nivel | Detalle |
|---|---|---|
| Bloqueo del playback | LOW | La carátula se espera después de publicar la metadata; el timeout del loader es 10 s |
| Carrera A→B / carátula vieja en canción nueva | LOW | Ya mitigado por guarda de `id` (+ la del plugin); hay test |
| Descarga repetida (mismo URL en vuelo) | MEDIUM | Sin dedupe en vuelo hoy; se resuelve con un mapa de `Future` por URL |
| Archivo parcial visible (`exists()` durante la escritura) | MEDIUM | Escritura no atómica; temp + rename |
| Archivos huérfanos | LOW | Sin limpieza ya hoy; ~decenas de KB por carátula en el cache dir que el SO purga; crece con el uso de Search |
| Cache incorrecto | LOW | Clave por URL completa (incluye `width`); no por `externalId` |
| Fallo de red → notificación sin carátula | LOW | Degradación existente; sin reintento, la carátula no aparece en esa sesión de la canción |
| Lockscreen sin carátula (Android 11+) | LOW/informativo | Android 11+ puede ignorar el arte en lockscreen según OEM; no depende de Taki |
| Tamaño/formato incompatible | LOW | Formatos aceptados por el loader decodifican con `BitmapFactory`; 300 px suficiente para notificación |
| Dos stacks HTTP si se usa `artUri` http | MEDIUM | Por eso se descarta esa vía (§4) |
| Instancia duplicada del loader en `main` | LOW | Mantenerla stateless/compartida |

## 12. Archivos afectados (propuesta 3.7B)

Producción: `lib/features/player/infrastructure/artwork_file_cache.dart`,
`player_bootstrap.dart`, `lib/main.dart`.
Tests: `test/features/player/infrastructure/artwork_file_cache_test.dart`,
`taki_audio_handler_test.dart`. Docs: nuevo `PHASE_3_7B_…`.

## 13. Plan propuesto para PHASE 3.7B

1. Ampliar `ArtworkFileCache` (loader opcional, rama remota, nombre FNV-1a por URL,
   escritura atómica, dedupe en vuelo); sin tocar la rama local.
2. Cablear en `initPlayer`/`main.dart` compartiendo una instancia del loader.
3. Tests listados (§10.10) + mutation testing de la rama nueva.
4. Documento 3.7B y **smoke test en Android real** (notificación y lockscreen con una
   pista de Jamendo, cambio rápido A→B, sin red).

## 14. Validación de esta fase

Sin cambios de código. Resultado de `flutter analyze`, `flutter test`, la prueba de
arquitectura y `flutter build apk --debug`: ver el reporte de entrega. Android: **sin
dispositivo; no se hizo smoke test**.
