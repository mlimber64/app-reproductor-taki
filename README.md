# Taki

Reproductor de música para Android, hecho en Flutter.

Taki reproduce la **música guardada en el teléfono** y, si se compila con una
credencial de **Jamendo**, también puede **buscar y reproducir música en línea** de
ese catálogo. No tiene backend propio, cuentas, anuncios ni telemetría. La interfaz
está en español y usa un tema oscuro.

## Estado

En desarrollo; **no está publicado** (ni en Play Store ni en ningún otro canal).
Se generó y probó una APK de release firmada con una keystore de producción en un
Redmi Note 14 Pro+ 5G (Android 16, HyperOS 3.0). Que exista esa APK **no** significa
que esté lista para distribución comercial: las pistas de Jamendo suelen tener
licencias Creative Commons de uso no comercial.

- **Ajustes** reúne acciones de biblioteca, almacenamiento, catálogos en línea,
  privacidad y datos de la app. No guarda preferencias.
- Hay limitaciones y verificaciones pendientes: ver [Limitaciones](#limitaciones).
- Solo se ha preparado y validado para **Android**.

## Funcionalidades

- **Biblioteca local**: lee las canciones del teléfono (MediaStore). Oculta audios
  de menos de 30 s y los de carpetas como notas de voz, grabaciones o tonos. Pide
  solo el permiso de audio (`READ_MEDIA_AUDIO` en Android 13+,
  `READ_EXTERNAL_STORAGE` antes). Pull-to-refresh vuelve a escanear.
- **Catálogo remoto (Jamendo y Audius)**: pestaña **Buscar**, con búsqueda desde 2
  caracteres, paginación y sin resultados duplicados. Con más de una fuente, unos
  chips arriba eligen cuál se busca y se explora. Jamendo requiere credencial;
  Audius no.
- **Reproducción local y remota** en segundo plano, con notificación y sesión de
  medios (controles de notificación, de bloqueo y de auriculares/Bluetooth),
  mini reproductor y pantalla **Reproduciendo** (carátula, progreso, anterior/
  siguiente, aleatorio y repetir).
- **Reproduciendo con color dinámico**: el fondo toma el color dominante de la
  carátula. Desde ahí: **letra sincronizada** (LRCLIB; se consulta solo al
  abrirla, con el título y el artista), **temporizador de sueño** (15/30/45/60
  min o al terminar la canción) y **ecualizador** con presets (se guarda).
- **Escuchado recientemente**: carrusel en Biblioteca con lo último que sonó
  (local o en línea), guardado solo en este teléfono.
- **Cola**: reproducir a continuación, añadir al final, reordenar, quitar (con
  deshacer) y limpiar lo que viene. Tocar un resultado de búsqueda reproduce solo
  esa canción; desde ⋯ se puede añadir a la cola, a favoritos o a una playlist.
- **Favoritos y playlists** con canciones **locales y remotas** (también mezcladas),
  guardados en SQLite local por `source` + `external_id`. Las remotas siguen
  visibles aunque se deniegue el permiso de música.
- **Carátulas** locales y remotas (también en la notificación y la pantalla de
  bloqueo) y portadas de playlist en mosaico.
- **Atribución** del contenido de Jamendo en Reproduciendo (origen, licencia y
  enlaces a la canción y a la licencia, que se abren en el navegador).
- **Aviso discreto** cuando una canción no se puede reproducir.

No hay modo offline para las pistas remotas ni descargas.

## Jamendo

Jamendo se activa solo si se pasa la credencial al compilar:

```bash
flutter run --dart-define=JAMENDO_CLIENT_ID=<CLIENT_ID>
```

`<CLIENT_ID>` es un `client_id` de la API de Jamendo (se obtiene en su portal de
desarrolladores). **No se guarda en el repositorio**: se pasa por línea de comandos
o variable local. Sin él, Taki funciona solo con la biblioteca local y no aparece la
pestaña Jamendo en Buscar. Tenga en cuenta que el valor queda dentro de la APK
compilada.

## Audius

Audius no necesita credencial: siempre está disponible, así que Buscar existe
aunque no haya `JAMENDO_CLIENT_ID`. Es música independiente en streaming, pero
**no garantiza una licencia libre**: muchas pistas declaran «All rights reserved»
o ninguna. Reproduciendo muestra la licencia que declaró el artista y un enlace a
la pista en audius.co, sin presentarla como Creative Commons.

## Stack

| Área | Tecnología |
|---|---|
| Framework | Flutter (stable 3.41), Dart ^3.11.5 |
| Estado / inyección de dependencias | flutter_riverpod 2.6 |
| Navegación | go_router 17 |
| Audio | just_audio 0.10, audio_service, audio_session |
| Persistencia | sqflite |
| Permisos | permission_handler 12, device_info_plus |
| Enlaces externos | url_launcher |
| Lectura de la biblioteca | Canal nativo propio en Kotlin (`taki/media_store`) |
| Red (Jamendo y carátulas) | `dart:io` (`HttpClient`) |
| Tests | flutter_test, mocktail, sqflite_common_ffi |

Android: `minSdk` 24 (Android 7.0), `targetSdk` 36, `compileSdk` 36, AGP 8.11,
Kotlin 2.2, Java 17. Permisos: `INTERNET`, `READ_MEDIA_AUDIO`,
`READ_EXTERNAL_STORAGE` (≤ Android 12), `FOREGROUND_SERVICE` (+ `MEDIA_PLAYBACK`),
`WAKE_LOCK` y `POST_NOTIFICATIONS`.

## Arquitectura

Hexagonal (ports & adapters) organizada por features:

```
lib/
├── main.dart     Composition root: crea los adapters y los inyecta
├── app/          Composición: router, tema, wiring de proveedores, UI que combina features
├── core/         Compartido: dominio musical, contratos, carátulas, tokens, widgets, base de datos
└── features/     library, player, playlists, search, jamendo, settings
                  (cada una con domain, infrastructure y presentation)
```

Dirección de dependencias: `app → features → core`. Las features no dependen de
`app` ni (salvo 8 excepciones documentadas) de otras features; `core` no depende de
nadie; ni `core` ni las features genéricas (`search`, `player`, `playlists`) conocen a
Jamendo. `test/architecture/dependency_rules_test.dart` (13 pruebas) lo comprueba.

Detalle completo en [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md); sistema visual en
[docs/DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md).

## Cómo ejecutar

Requisitos: Flutter stable con Dart 3.11.5 o superior, Android SDK y un
dispositivo o emulador Android.

```bash
flutter pub get
flutter run                                              # solo biblioteca local
flutter run --dart-define=JAMENDO_CLIENT_ID=<CLIENT_ID>   # con Jamendo
```

## Tests y análisis

```bash
flutter test
flutter test test/architecture/dependency_rules_test.dart
flutter analyze
```

Los tests no necesitan dispositivo: los plugins se sustituyen por fakes y SQLite
corre en memoria con `sqflite_common_ffi`.

## Builds

```bash
flutter build apk --debug
flutter build apk --release --dart-define=JAMENDO_CLIENT_ID=<CLIENT_ID>
```

Salida: `build/app/outputs/flutter-apk/app-debug.apk` y `app-release.apk`. El
release usa R8 y es un APK único con arm64-v8a, armeabi-v7a y x86_64.

### Firma de release

La firma de producción usa una **keystore que vive fuera del repositorio**:

1. Cree su keystore (guárdela fuera del repo y haga copia de seguridad; si se pierde
   no podrá actualizar la app):
   `keytool -genkey -v -keystore <ruta-local-a-la-keystore> -keyalg RSA -keysize 2048 -validity 10000 -alias taki`
2. Cree el archivo local `android/key.properties` (ignorado por Git) con
   `storePassword`, `keyPassword`, `keyAlias=taki` y `storeFile=<ruta-local-a-la-keystore>`.
3. `buildTypes.release` usa `signingConfigs.release`. **Sin ese archivo completo, el
   build release falla** con un mensaje claro; nunca se usa la clave de debug.

La keystore y `android/key.properties` están ignorados por Git. Nunca los
versione ni los comparta. Verificación recomendada de un APK:
`apksigner verify --verbose --print-certs app-release.apk`. Historial:
`docs/PHASE_3_9B_PRODUCTION_SIGNING.md`.

## Limitaciones

Lo que **no** existe o **no** se ha verificado (no son necesariamente bugs):

- No hay segundo proveedor, modo offline ni descargas; Ajustes no guarda
  preferencias.
- No verificado en dispositivo: la UI del lockscreen (el teléfono de prueba no tiene
  bloqueo seguro), auriculares físicos, seek en pistas remotas y la muerte del
  proceso por el sistema.
- No se ha evaluado el formato AAB / Play App Signing.
- Deuda de UX observada en Android (p. ej. Reproduciendo muestra «Biblioteca» como
  origen también para pistas remotas): ver
  [docs/PHASE_3_9_ANDROID_VALIDATION_RELEASE.md](docs/PHASE_3_9_ANDROID_VALIDATION_RELEASE.md).

## Historial de fases

Cada fase tiene su informe en `docs/PHASE_*`. Estado actual:

| Fase | Contenido | Estado |
|---|---|---|
| 1.x | Design System y carátulas | Cerrada |
| 2.x | Modelo universal (`MusicIdentity`, `Song`/`LocalSong`, `PlaybackResource`, carátulas remotas) | Completada |
| 3.0–3.1 | `SongLookup` y proveedor Jamendo | Completadas |
| 3.2 | Búsqueda, atribución y acciones de canción | Completada |
| 3.3 / 3.8 | Auditorías (ciclo de vida remoto; global post-3.7B) | Informes |
| 3.4 | Favoritos y playlists remotos, aislamiento por fuente | Completada |
| 3.5 | Aviso de errores de reproducción | Completada |
| 3.6 | Portadas de playlist con canciones remotas | Completada |
| 3.7 | Carátula remota en MediaSession (3.7A auditoría, 3.7B implementación) | Completada |
| 3.9 | Validación Android y APK release | Pass con notas (no cerrada) |
| 3.9B | Firma de producción | Pass |
| 3.10 | Sincronización de documentación | Esta fase |

## Roadmap

Todo lo de esta sección es **FUTURO**: nada de esto está implementado.

- **FUTURO:** preferencias persistidas en Ajustes.
- **FUTURO:** segundo proveedor de catálogo y política multi-fuente (selector,
  mezcla, ranking).
- **FUTURO:** modo offline / descargas.
- **FUTURO:** AAB y Play App Signing.
