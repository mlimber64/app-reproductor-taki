# Taki

Reproductor de música local para Android, hecho en Flutter.

Taki reproduce la música guardada en el teléfono. Hoy funciona 100 % en el
dispositivo: sin backend, sin cuentas, sin anuncios y sin telemetría. La
interfaz está en español y usa un tema oscuro.

## Estado

En desarrollo, sin versión publicada. La base es estable (tests, análisis
estático y build debug en verde), pero:

- **Ajustes** es una pantalla provisional.
- La build de **release** todavía se firma con la clave de debug.
- Solo se ha preparado para **Android**.

## Funcionalidades actuales

- **Biblioteca**: lee las canciones del teléfono (MediaStore). Oculta audios
  de menos de 30 s y los de carpetas como notas de voz, grabaciones o tonos.
  Pide solo el permiso de audio (`READ_MEDIA_AUDIO` en Android 13+,
  `READ_EXTERNAL_STORAGE` antes). Pull-to-refresh vuelve a escanear.
- **Reproducción** en segundo plano con notificación, controles en la
  pantalla de bloqueo y botones de auriculares/Bluetooth.
- **Mini reproductor** sobre la barra de pestañas y pantalla
  **Reproduciendo** con carátula, barra de progreso, anterior/siguiente,
  aleatorio y repetir (desactivado / todo / una).
- **Cola**: reproducir a continuación, añadir al final, reordenar
  arrastrando, quitar (con deshacer) y limpiar lo que viene.
- **Favoritos**: marcar desde el menú de una canción o desde Reproduciendo;
  pestaña propia con Reproducir y Aleatorio.
- **Playlists**: crear, renombrar, eliminar, añadir canciones, reordenar y
  quitar (con deshacer); portada en mosaico con las carátulas.
- Favoritos y playlists se guardan en una base SQLite local y reencuentran
  las canciones aunque cambie su id en MediaStore.

## Stack

| Área | Tecnología |
|---|---|
| Framework | Flutter (stable 3.41), Dart ^3.11.5 |
| Estado / inyección de dependencias | flutter_riverpod 2.6 |
| Navegación | go_router 17 |
| Audio | just_audio 0.10, audio_service, audio_session |
| Persistencia | sqflite |
| Permisos | permission_handler 12, device_info_plus |
| Lectura de la biblioteca | Canal nativo propio en Kotlin (`taki/media_store`) |
| Tests | flutter_test, mocktail, sqflite_common_ffi |

Android: `minSdk` 24 (Android 7.0), `targetSdk` 36, AGP 8.11, Kotlin 2.2,
Java 17.

## Arquitectura

Hexagonal (ports & adapters) organizada por features:

```
lib/
├── main.dart     Composition root: crea los adapters y los inyecta
├── app/          Composición: router, tema global, UI que combina features
├── core/         Compartido: dominio musical, carátulas, tokens, widgets, base de datos
└── features/     library, player, playlists, settings (cada una con domain,
                  infrastructure y presentation)
```

Dirección de dependencias: `app → features → core`. Las features no
dependen de `app` ni (salvo 6 excepciones documentadas) de otras features, y
`core` no depende de nadie. `test/architecture/dependency_rules_test.dart`
lo comprueba.

Detalle completo en [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Cómo ejecutar

Requisitos: Flutter stable con Dart 3.11.5 o superior, Android SDK y un
dispositivo o emulador Android.

```bash
flutter pub get
flutter run
```

## Tests y análisis

```bash
flutter test
flutter analyze
```

Los tests no necesitan dispositivo: los plugins se sustituyen por fakes y
SQLite corre en memoria con `sqflite_common_ffi`.

## APK de debug

```bash
flutter build apk --debug
```

Genera `build/app/outputs/flutter-apk/app-debug.apk`.

## Roadmap

Todo lo de esta sección es **FUTURO**: nada de esto está implementado.

- **FUTURO:** pantalla de Ajustes (hoy es provisional).
- **FUTURO:** búsqueda (la feature `search` es un esqueleto vacío).
- **FUTURO:** catálogo musical online junto al catálogo local (en diseño).
- **FUTURO:** firma de release propia.
