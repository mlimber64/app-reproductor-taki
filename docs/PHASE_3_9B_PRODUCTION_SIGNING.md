# Fase 3.9B — Firma de producción del release

## 1. Objetivo

Firmar el APK release con la keystore de producción creada por el usuario (fuera
del repositorio), proteger los secretos, verificar la firma criptográficamente e
instalarlo en el Redmi validado en la 3.9. Sin cambios de funcionalidad, UX,
dependencias ni arquitectura; las deudas de la 3.9 **no** se tocaron.

## 2. Keystore externa

Keystore JKS/PKCS12 con el alias `taki`, almacenada **fuera del repositorio** (no se
copió ni se creó otra). El alias se comprobó con `keytool` leyendo las contraseñas
desde el archivo local, sin imprimirlas. Huella SHA-256 de la keystore:
`BE:F6:1F:6A:F6:BB:2E:AD:98:BB:30:44:67:AF:A2:DF:F4:D1:E2:60:F8:0F:2B:D0:D3:B9:00:19:1E:83:C5:4C`.

## 3. Configuración de signing

`android/app/build.gradle.kts` (único archivo de build modificado):
- carga `android/key.properties` (si existe) con `java.util.Properties`;
- `signingConfigs.create("release")` con `keyAlias`, `keyPassword`, `storeFile` y
  `storePassword` leídos de ese archivo;
- `buildTypes.release` usa `signingConfigs.getByName("release")` (**ya no** la de debug);
- `gradle.taskGraph.whenReady`: si se construye un release y faltan datos de firma,
  falla con «Firma de release: falta android/key.properties o está incompleto…»
  (comprobado: sin el archivo, el release falla con ese mensaje y no cae en debug).
  Debug y tests no necesitan el archivo.

No cambió ningún valor de versión, `applicationId`, SDK ni R8.

## 4. Protección de secretos

- `android/key.properties` está ignorado (`android/.gitignore:13`), igual que
  `**/*.keystore` y `**/*.jks` (comprobado con `git check-ignore`; no hizo falta añadir
  reglas).
- La contraseña **solo existe** en `android/key.properties`: se buscó su valor en todo
  el árbol (sin `.git`, `build`, `.dart_tool`, `.gradle`) y solo apareció ahí; `git grep`
  sobre lo versionado: sin coincidencias; `build.gradle.kts` no contiene literales
  secretos; no hay keystores ni `key.properties` en el índice ni dentro del repo.
- `git status --short` no muestra `key.properties`, `*.jks` ni `*.keystore`.
- Las contraseñas no se imprimieron en logs ni en este documento. Nota operativa: el
  asistente llegó a ver el contenido del archivo cuando el usuario lo editó (el entorno
  muestra los cambios de archivo); si eso es un problema, conviene **rotar la
  contraseña** de la keystore.

## 5. Build

```
flutter clean && flutter pub get
flutter analyze            -> sin issues
flutter test               -> 1614 pasan, 1 saltado
flutter test test/architecture/dependency_rules_test.dart -> 13/13
flutter build apk --release --dart-define=JAMENDO_CLIENT_ID=<CLIENT_ID>   (el id sale del entorno; no se imprime)
```
Resultado: OK. R8 sigue activo (`mapping.txt` ≈15,6 MB).

## 6. Firma (`apksigner verify --verbose --print-certs`)

`Verifies`; esquema **v2** (v1, v3, v3.1 y v4: no); un firmante; certificado
`CN=Limber, OU=TakiCorp, O=TakiCorp, L=Salerno, ST=Salerno, C=IT`. **No es Android
Debug** (la clave de debug era `e761f5e0…e3ca9`).

## 7. SHA-256 del certificado

`bef61f6af6bb2ead98bb304467afa2dff4d1e260f80f2bd0d3b900191e83c54c`
(coincide con la huella de la keystore del §2, comparada byte a byte, no solo por el
nombre). Clave pública SHA-256: `e5d9f9ac7351a66ed19e9b3e8997a0c660665130a55294909ec8ddf9b6ded3de`.

## 8. APK

| Dato | Valor |
|---|---|
| Ruta | `build/app/outputs/flutter-apk/app-release.apk` |
| Tamaño | 57 192 423 bytes (54,54 MB) |
| SHA-256 del APK | `8661F0477DA7E815DCFFB14677A11519938FD785AFDF59CBE6AFA573062017FF` |
| Versión | 1.0.0 (versionCode 1), `com.limbermendoza.taki`, minSdk 24 / targetSdk 36 |
| ABIs | arm64-v8a, armeabi-v7a, x86_64 (APK único) |

**Diferencia con el release de la 3.9 (59,47 MB):** el APK anterior incluía
`libsqlite3.so` (≈1,7 MB por ABI) y este no. Comparado con la copia extraída del
teléfono, es la única librería nativa que falta. Taki usa `sqflite` (SQLite de la
plataforma); `sqflite_common_ffi` es solo de tests y en `lib/` solo aparece en un
comentario. No se investigó por qué la anterior la incluía (probablemente un artefacto
del grafo de dependencias de desarrollo). El smoke test (favoritos y playlists con
SQLite) confirma que no hace falta.

## 9. Instalación en el Redmi

Dispositivo: Redmi Note 14 Pro+ 5G (`24115RA8EG`), Android 16 / API 36.

1. `adb install -r` sobre la versión anterior: **falla** con
   `INSTALL_FAILED_UPDATE_INCOMPATIBLE: signatures do not match` (conflicto de firma
   esperado: la anterior estaba firmada con la clave de debug).
2. Se **desinstaló explícitamente** la versión anterior (`adb uninstall`), lo que
   **borró sus datos locales** (2 favoritos y la playlist «Prueba Jamendo» de la 3.9).
   Esto **no** se presenta como prueba de persistencia.
3. `adb install`: HyperOS pidió confirmar «Instalar vía USB» en el teléfono y el
   asistente pulsó «Instalar» (la instalación la había iniciado el propio asistente).
   Resultado: **Success**.
4. La copia instalada, extraída del teléfono, es **idéntica** al APK construido
   (mismo SHA-256) y `apksigner` confirma el certificado de producción.

## 10. Smoke test mínimo (release firmado con la clave de producción)

| # | Prueba | Resultado |
|---|---|---|
| 1 | Arranca (instalación limpia, sin permisos) | PASS (sin crash; pantalla «Taki necesita acceso a tu música») |
| 2 | Biblioteca tras conceder el permiso | PASS (98 canciones) |
| 3 | Reproducción local | PASS (`PLAYING`, notificación con carátula) |
| 4 | Pestaña Buscar visible | PASS |
| 5 | Búsqueda Jamendo (`oasis`) | PASS (resultados con carátulas remotas) |
| 6 | Reproducción Jamendo | PASS (`PLAYING`) |
| 7 | MiniPlayer | PASS |
| 8 | Notificación | PASS (`largeIcon` 144×144, título/artista de la pista remota) |
| 9 | Carátula remota | PASS (filas, MiniPlayer y Reproduciendo) |
| 10 | Favorito | PASS (corazón relleno; aparece en Favoritos) |
| 11 | Playlist | PASS (creada desde ⋯, «Añadida a «Firma prod»») |
| 12 | Atribución | PASS (Origen · Jamendo, CC BY-NC-ND 3.0) |
| 13 | Enlaces externos | PASS («Ver canción» y «Ver licencia» abren Chrome y se vuelve a Taki) |
| 14 | `force-stop` y reabrir | PASS (sin crash; Biblioteca, Favoritos y la playlist nuevas persisten) |

Notas: la prueba se hizo con el asistente conduciendo la UI por ADB. El permiso de
notificaciones no se examinó por separado. No se repitieron lockscreen ni auriculares
físicos (siguen pendientes de la 3.9).

## 11. Estado final

**PASS.** Release firmado con la keystore de producción, verificado e instalado; sin
regresiones en el smoke mínimo; sin secretos en el repositorio. Las notas de la 3.9
(lockscreen sin bloqueo seguro, auriculares físicos) siguen abiertas.

## 12. Pendientes

1. **Copia de seguridad** de la keystore y de su contraseña fuera del equipo (perderla
   impide actualizar la app en cualquier tienda). Considerar rotar la contraseña (§4).
2. Las deudas y bloqueos de la 3.9 (lockscreen, auriculares físicos, textos de UX).
3. Sin commits de 2.x–3.9B; `build.gradle.kts` y `docs/` están sin versionar.
4. Si se publica en una tienda: firma de la app por Play App Signing / AAB
   (`flutter build appbundle`) no se evaluó en esta fase.
