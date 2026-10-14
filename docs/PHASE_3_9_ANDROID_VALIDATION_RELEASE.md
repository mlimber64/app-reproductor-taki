# Fase 3.9 — Validación en Android y APK release

## 1. Objetivo

Validar Taki en un Android físico y generar una APK **release** instalable. Sin
funcionalidades nuevas, refactors ni actualizaciones de dependencias. **No hubo
cambios de producción ni de tests en esta fase** (no apareció ningún bug que lo
exigiera).

## 2. Dispositivo

| Dato | Valor |
|---|---|
| Modelo | Redmi Note 14 Pro+ 5G (`24115RA8EG`, id ADB `31fb56c8`) |
| Sistema | HyperOS 3.0 sobre **Android 16 (API 36)** |
| CPU | `arm64-v8a` |
| Pantalla | 1220 × 2712 |
| Bloqueo de pantalla | **sin bloqueo seguro** (al despertar no hay lockscreen) |
| Música local | ~100 canciones reales (biblioteca de Taki: 98) |

## 3. Prechecks

`flutter doctor -v`: Flutter 3.41.9 (stable), Dart 3.11.5, Android SDK 36.1 /
build-tools 36.1.0, JBR 21, licencias aceptadas (Visual Studio sin los componentes de
C++ para Windows: irrelevante para Android). AGP 8.11.1, Gradle 8.14, Kotlin 2.2.20.
`flutter analyze`: sin issues. `flutter test`: **1614 pasan, 1 saltado**.
`dependency_rules_test`: **13/13**. `flutter build apk --debug`: OK.
`JAMENDO_CLIENT_ID` salió de la variable de entorno del usuario (no se imprime) y
se pasó con `--dart-define` a los builds.

Incidencias de entorno (no de Taki): MIUI/HyperOS bloquea `input tap/keyevent`
por ADB (`INJECT_EVENTS`) salvo con «Depuración USB (ajustes de seguridad)»; tras
activarla hubo que reiniciar `adbd` (`adb tcpip` + `adb usb`), y la conexión
USB tuvo microcortes (se añadieron reintentos al asistente de pruebas). El «crash»
`FATAL EXCEPTION: UiAutomation` del log pertenece al proceso de ADB (`uiautomator
dump`), no a Taki.

## 4. Cómo se probó (y límites)

Se conduce el teléfono con ADB (toques, `uiautomator dump`, capturas) y se
verifica con `dumpsys media_session`/`notification`, logcat y capturas.
**El smoke test se ejecutó sobre el APK release instalado**; el debug solo se
observó (sesión de medios, notificación y caché de carátulas) antes de instalar el
release. Durante la prueba el usuario **también manipuló el teléfono** (p. ej.
concedió el permiso de música y arrancó una canción local en mitad de una prueba de
error), por lo que algunos pasos se repitieron; los resultados de abajo son los de
las repeticiones limpias. Las capturas de la notificación se recortaron a la
tarjeta de Taki.

## 5. Smoke test

`PASS` = visto en el teléfono; `PARTIAL` = visto a medias; `NOT VERIFIED` /
`BLOCKED` = no se pudo.

### 5.1 Biblioteca y audio local (release)
| Prueba | Resultado |
|---|---|
| Biblioteca lista las canciones locales | PASS (98 canciones, carátulas locales) |
| Reproducir, progreso | PASS (`PLAYING`, posición avanza) |
| Pausa / reanudar | PASS |
| Seek | PASS (≈18 s → ≈156 s) |
| Siguiente / anterior | PASS (siguiente cambia de pista; anterior reinicia o retrocede según 3 s) |
| MiniPlayer y Reproduciendo | PASS (carátula local) |
| Pantalla apagada: sigue sonando | PASS (la posición avanzó con `keyguard=true`) |
| Notificación | PASS (`MediaStyle`, título/artista, `largeIcon` 144×144, controles, progreso) |
| Lockscreen (UI) | **NOT VERIFIED**: el teléfono no tiene bloqueo seguro y al despertar no aparece lockscreen; sí hay sesión + metadata + bitmap |
| Botones de auriculares | PARTIAL: `KEYCODE_MEDIA_PLAY_PAUSE/NEXT/PREVIOUS` inyectados por ADB funcionan; **auriculares físicos: BLOCKED** (no había) |

### 5.2 Jamendo (release)
| Prueba | Resultado |
|---|---|
| Búsqueda ≥ 2 caracteres, resultados con carátulas remotas | PASS |
| Búsqueda sin resultados («oasisoasis») | PASS: «No encontramos música / Prueba con otro título.» |
| Reproducir una pista | PASS (sesión `PLAYING`, MiniPlayer) |
| Reproducir en segundo plano (app cerrada con Atrás) | PASS (siguió sonando; carátula remota en la isla dinámica) |
| Cambio de pista | PASS (siguiente dentro de una playlist) |
| Notificación/MediaSession remotas | PASS (título/artista, `largeIcon` bitmap, tarjeta con la carátula correcta) |
| Seek en pista remota | NOT VERIFIED (el seek se probó en local) |
| Duración/título/artista | PASS (Reproduciendo y sesión) |
| Carátula rota | no observada |
| Lockscreen remoto (UI) | NOT VERIFIED (ver 5.1) |

### 5.3 Favoritos y playlists remotos
| Prueba | Resultado |
|---|---|
| Añadir favorito desde Reproduciendo, aparece en Favoritos | PASS |
| Reinicio completo (`force-stop`) | PASS: 2 favoritos remotos persisten |
| Permiso de música revocado: Favoritos remotos visibles | PASS (fix de 3.4 en dispositivo) |
| Crear playlist desde ⋯, añadir remota, detalle | PASS |
| Carátula remota en playlist y detalle | PASS |
| Playlist mixta (3 remotas + 1 local): mosaico 2×2 y **orden** | PASS (Oasis, 11 A…, Secret Oasis, local) |
| Mixta sin permiso: remotas visibles, local oculta, **datos intactos** | PASS (al volver a conceder se recuperan las 4 en el mismo orden) |

### 5.4 Atribución y enlaces
| Prueba | Resultado |
|---|---|
| Sección en Reproduciendo: «Origen · Jamendo», «Licencia · CC BY-NC-ND 3.0» | PASS |
| «Ver canción» abre `jamendo.com` en Chrome y se vuelve a Taki | PASS (intent `VIEW https://www.jamendo.com/…`) |
| «Ver licencia» abre `creativecommons.org` y se vuelve | PASS (`http://creativecommons.org/…`) |
| Enlace imposible de abrir | NOT EXECUTED (Chrome presente) |

### 5.5 Error de reproducción
Se provocó **sin tocar producción**: con Favoritos ya cargado y **Wi-Fi/datos
apagados** (`svc`), se pulsó Reproducir.

| Prueba | Resultado |
|---|---|
| Aparece SnackBar | PASS: «No se pudo reproducir. Pasando a la siguiente.» |
| Sin stack trace/URL/HTTP | PASS |
| Continúa con la siguiente | PASS |
| No se acumulan avisos | PARTIAL (se vio uno a la vez; sin prueba de estrés) |
| Variante «sin siguiente» («No se pudo reproducir esta canción») | **NOT VERIFIED en dispositivo** (cubierta por tests unitarios) |

### 5.6 Carrera A→B y artwork sin red
| Prueba | Resultado |
|---|---|
| Dos saltos seguidos en una playlist con carátulas distintas | PASS: la notificación muestra «Secret Oasis» con **su** carátula, no la de las anteriores |
| Sin red: la notificación reutiliza la carátula remota ya guardada | PASS («11 A transparent oasis» con su arte, aun fallando el audio) |
| Archivos `remote_<fnv64>.img` en `cache/artwork` | observado en el **debug** (6 archivos); en release `run-as` no está permitido → NOT VERIFIED |

### 5.7 Reinicio y permisos
| Prueba | Resultado |
|---|---|
| `force-stop` y reabrir: sin crash; favoritos y playlists persisten | PASS |
| Reanudar la reproducción tras el reinicio | no esperado (no se persiste) |
| Cierre desde recientes / muerte por el sistema | NOT VERIFIED |
| Permiso concedido / denegado / concedido después | PASS (Biblioteca pide permiso al denegar; Favoritos y Playlists remotos siguen visibles; al conceder, la Biblioteca y lo local reaparecen) |

## 6. Problemas encontrados

Ninguno **bloqueante**; no hubo fixes (`BUG/FIX/TEST ADDED`: no aplica). Deuda
observada en el teléfono (todas ya conocidas o de UX, sin regresión):

1. Reproduciendo muestra «REPRODUCIENDO DESDE **Biblioteca**» también para una pista
   de Jamendo (texto fijo, I14).
2. Pantalla de permiso de Biblioteca: «Nada sale de tu dispositivo» deja de ser cierto
   con Jamendo configurado.
3. Favoritos queda en «Favoritos no disponibles» tras un recálculo sin red hasta
   pulsar «Reintentar» (sin reintento automático; diseño de 3.4).
4. Con el permiso denegado, la lista de playlists dice «4 canciones» y el detalle
   muestra 3, sin aviso (deuda de 3.4).
5. Los avisos de Kotlin («incremental caches») durante Gradle son no fatales.

## 7. Fixes y pruebas añadidas

Ninguno.

## 8. Configuración de release

| Dato | Valor |
|---|---|
| `applicationId` | `com.limbermendoza.taki` |
| `versionName` / `versionCode` | `1.0.0` / `1` (de `pubspec.yaml: 1.0.0+1`) |
| `minSdk` / `targetSdk` / `compileSdk` | 24 / 36 / 36 |
| Keystore / `key.properties` | *(3.9)* no existían; **desde la 3.9B** hay keystore externa y `android/key.properties` local (ambos ignorados por Git) |
| Secretos hardcodeados | ninguno; el `client_id` solo viaja por `--dart-define` |
| `release` en `build.gradle.kts` | *(3.9)* `signingConfigs.getByName("debug")`; **desde la 3.9B** `signingConfigs.getByName("release")` |
| `src/release/` | no existe |
| Manifest | `INTERNET`, `READ_MEDIA_AUDIO`, `READ_EXTERNAL_STORAGE` (≤32), `FOREGROUND_SERVICE(_MEDIA_PLAYBACK)`, `WAKE_LOCK`, `POST_NOTIFICATIONS`; las librerías añaden `ACCESS_NETWORK_STATE` y un permiso interno `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` |
| `allowBackup` | por defecto (`true`) |

## 9. Estado de la firma

**Actualizado en la Fase 3.9B** (`PHASE_3_9B_PRODUCTION_SIGNING.md`): la firma de
producción **ya está configurada**. Keystore externa (fuera del repositorio) con el
alias `taki`, `android/key.properties` ignorado por Git y `build.gradle.kts` con
`signingConfigs.release`; el release ya no usa la clave de debug. APK final firmado:
esquema v2, certificado SHA-256
`bef61f6af6bb2ead98bb304467afa2dff4d1e260f80f2bd0d3b900191e83c54c`
(APK SHA-256 `8661F047…2017FF`, 54,54 MB), instalado en el Redmi tras desinstalar la
versión firmada con debug y con smoke test mínimo PASS.

*Estado original de esta fase (histórico):* el release se firmaba con la clave de
DEBUG (`CN=Android Debug`, solo v2, certificado `e761f5e0…e3ca9`), válido para
instalar en un teléfono pero **no para publicar**; entonces no existía keystore y no
se creó ninguna sin autorización.

## 10. Estado de R8

Activo en `release`: se generaron `mapping.txt` (≈15,6 MB), `usage.txt` y
`configuration.txt` (minificación y reducción). **No se añadió ninguna regla**: en
el release funcionaron `audio_service`/MediaSession/notificación, `just_audio`,
`sqflite` (favoritos y playlists), `url_launcher` (Chrome), Jamendo (red, parser) y
el canal nativo de MediaStore. El log no contiene `MissingPluginException`,
`ClassNotFoundException`, `NoSuchMethodError` ni excepciones fatales de Taki.

## 11. Comandos de build

```
flutter clean && flutter pub get
flutter analyze && flutter test && flutter test test/architecture/dependency_rules_test.dart
flutter build apk --release --dart-define=JAMENDO_CLIENT_ID=<CLIENT_ID>
```
Sin `--dart-define`, el APK funciona pero **sin Jamendo ni pestaña Buscar**.

## 12. APK

| Dato | Valor |
|---|---|
| Ruta | `D:\taki\build\app\outputs\flutter-apk\app-release.apk` |
| Tamaño | 62 360 713 bytes (**59,47 MB**), APK único |
| ABIs | `arm64-v8a`, `armeabi-v7a`, `x86_64` |
| SHA-256 | `6597AEA1FEDCA41250FE7FE3B0C6C5DAEF0036279D75F2AAABAC55854B109BA7` (idéntico en dos builds) |
| `apksigner verify` | `Verifies` (v2), firmante debug |

## 13. Instalación

`adb install -r` sobre el debug (misma clave): **Success**. El paquete instalado no
es depurable (`run-as` rechazado), `versionName 1.0.0`, abre sin crash ni ANR.

## 14. Resultado final

**PASS WITH NOTES — la fase NO se declara CLOSED.**

Checklist de cierre: analyze PASS · tests PASS · debug build PASS · dispositivo
detectado PASS · release build PASS · release instalada PASS · abre PASS · audio
local PASS · Jamendo PASS · notificación PASS · remote artwork PASS · favoritos
PASS · playlists PASS · atribución PASS · enlaces PASS · reinicio de proceso PASS
(`force-stop`) · sin regresiones conocidas PASS · **lockscreen: NOT VERIFIED**
(el teléfono no tiene bloqueo seguro) · **auriculares físicos: BLOCKED** ·
**firma de producción: resuelta en la 3.9B**.

## 15. Validación final de la fase

`flutter analyze` sin issues; `flutter test` 1614 + 1 saltado; arquitectura 13/13;
`flutter build apk --debug` y `--release` OK.

## 16. Bloqueos pendientes

1. ~~Firma de release real (keystore del usuario).~~ **Resuelto en la 3.9B.**
2. Lockscreen: requiere configurar un bloqueo de pantalla en el teléfono y repetir la
   comprobación (la sesión de medios y el bitmap ya están correctos).
3. Auriculares Bluetooth/cableados físicos.
4. Cierre desde recientes / muerte del proceso por el sistema; persistencia de la
   caché `remote_*.img` entre reinicios en el release; seek en pistas remotas;
   variante «sin siguiente» del aviso de error; enlace que no puede abrirse.

## 17. Deuda descubierta

Ver §6 (1-4). Además, el repositorio sigue **sin commits** de las fases 2.x–3.9 (ver
3.8).
