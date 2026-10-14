# Fase 3.10 — Sincronización de la documentación

## 1. Objetivo

Que `README.md`, `docs/ARCHITECTURE.md` y `docs/DESIGN_SYSTEM.md` describan el
estado **actual** de Taki tras las fases 2.x, 3.x, 3.9 y 3.9B, sin contradecir el
código ni los informes de fase. Fase **solo documental**: no se modificó ningún
archivo Dart, Kotlin ni Gradle, ni dependencias, ni tests. Los informes
`docs/PHASE_*` son registro histórico y **no se reescribieron**.

## 2. Documentos auditados

`README.md`, `docs/ARCHITECTURE.md`, `docs/DESIGN_SYSTEM.md`, los 39 `docs/PHASE_*`
(solo como referencia y para buscar términos), los comentarios de código (solo
reporte) y la configuración Android (`build.gradle.kts`, manifests, `key.properties`
ignorado). No existe `android/README*`.

### Inventario previo

| Documento | Sección | Estado | Cambio necesario |
|---|---|---|---|
| `README.md` | Intro / Estado | Obsoleto | «100 % en el dispositivo, sin backend»; «firma de release con clave de debug» |
| `README.md` | Funcionalidades | Incompleto | Faltan búsqueda, Jamendo, remotas en favoritos/playlists, carátulas remotas, atribución, aviso de errores |
| `README.md` | Stack / Android | Incompleto | Falta `url_launcher`, red, permisos reales |
| `README.md` | Arquitectura | Obsoleto | features `library, player, playlists, settings`; «6 excepciones» (son 7) |
| `README.md` | Roadmap | Obsoleto | «búsqueda: esqueleto vacío», «firma de release propia» ya hechas |
| `README.md` | Build / firma | Ausente | Release y firma sin documentar |
| `ARCHITECTURE.md` | Intro | Obsoleto | «reproductor local, 100 % cliente, sin backend» |
| `ARCHITECTURE.md` | Estructura | Obsoleto | `search` «esqueleto vacío»; sin `jamendo`, `core/catalog|lookup|links`, wiring |
| `ARCHITECTURE.md` | Pestañas | Obsoleto | Falta Buscar |
| `ARCHITECTURE.md` | `core/domain` | Obsoleto | `Song` descrita con `albumId`/`contentUri` (hoy `LocalSong`); faltan `MusicIdentity`, `ArtworkReference`, `PlaybackResource`, lookups |
| `ARCHITECTURE.md` | Artwork | Obsoleto | «Solo hay carátulas locales»; sin remoto ni `ArtworkFileCache` remoto |
| `ARCHITECTURE.md` | Reproducción | Obsoleto | Sin resolvers/`PlaybackResource`, sin aviso de errores |
| `ARCHITECTURE.md` | Excepciones | Parcial | 7 correctas; nota «reevaluar cuando llegue el catálogo online» ya cumplida; faltan reglas de proveedores |
| `ARCHITECTURE.md` | Base de datos | Obsoleto | «versión 2», id de MediaStore |
| `ARCHITECTURE.md` | Test de arquitectura | Obsoleto | Listaba 5 reglas (hoy 13) |
| `ARCHITECTURE.md` | Problemas conocidos | Obsoleto | «firma de release con debug»; «canal no verificado en dispositivo» |
| `DESIGN_SYSTEM.md` | Intro, §7.1, §14, §16, estado del artwork | Parcial | Marcadores «futuro»/«local» ya cumplidos (búsqueda, remoto, 5.º destino) |
| `DESIGN_SYSTEM.md` | Menciones a `AppColors`, `SongTile`, `PlayShuffleButtons`, `MessageView`, `PlayingBars`, `PlaylistCover` | Correcto | Todas están marcadas como históricas/eliminadas: se dejan |
| `PHASE_3_9_ANDROID_VALIDATION_RELEASE.md` | Firma | Ya actualizado en 3.9B | — |

## 3. Documentos modificados

| Documento | Modificado | Motivo |
|---|---|---|
| `README.md` | **Sí** (reescrito) | Producto actual: local + Jamendo, búsqueda, remoto, atribución, build, firma, requisitos, limitaciones y estado de fases |
| `docs/ARCHITECTURE.md` | **Sí** (reescrito conservando lo vigente) | Arquitectura actual: modelo universal/local, identidad, reproducción, lookup, artwork, búsqueda, atribución, Jamendo, Android, firma, 13 tests, limitaciones |
| `docs/DESIGN_SYSTEM.md` | **Sí** (5 ediciones puntuales) | Quitar «local/futuro» ya cumplidos; principios y tokens intactos |
| `docs/PHASE_3_10_DOCUMENTATION_SYNC.md` | **Sí** (nuevo) | Este informe |
| `docs/PHASE_1_*` … `PHASE_3_9B_*` (39) | No | Registro histórico |
| `android/app/build.gradle.kts` | No en esta fase | Cambió en la 3.9B; aquí no se tocó ningún código ni configuración |

## 4. Contradicciones encontradas (y corregidas)

1. **«Reproductor local, 100 % en el dispositivo, sin backend»** (README,
   ARCHITECTURE): falso con Jamendo configurado y `INTERNET` en el manifest →
   descrito como local + catálogo remoto opcional, sin backend propio.
2. **`search` «esqueleto vacío»** (ARCHITECTURE, README roadmap): la feature existe
   con dominio, infraestructura, presentación, ruta y tests.
3. **`Song` con `albumId`/`path`/`contentUri`** (ARCHITECTURE): desde la 2.9 son de
   `LocalSong`; `Song` es universal.
4. **«Solo hay carátulas locales»** (ARCHITECTURE): hay `RemoteArtworkReference`,
   carga remota y `ArtworkFileCache` remota.
5. **Firma de release con clave de debug** (README, ARCHITECTURE): desde la 3.9B usa
   `signingConfigs.release` con una keystore externa.
6. **«6 excepciones»** (README) / **«versión 2»** de la BD / **5 reglas** del test:
   hoy 7 excepciones, v3 y 13 pruebas.
7. **Pestañas sin Buscar** (ARCHITECTURE).
8. **«`MediaStoreChannel` no verificado en dispositivo»**: funciona en el Redmi (3.9).
9. **DESIGN_SYSTEM:** «reproductor local», origen «remoto (futuro)», filas «búsqueda
   (futuro)» y «Futuro: si llegan Buscar…» ya cumplidos.

## 5. Arquitectura documentada

`ARCHITECTURE.md` cubre: estructura real de `lib/`; capas y reglas (incluidas las
reglas de proveedores y las **7** excepciones, con el test de **13** pruebas leído
del código); `core/domain` (`Song` universal vs `LocalSong`, `MusicIdentity`
`(source, externalId)`, `SongReference`, `ArtworkReference`, `PlaybackResource` y sus
4 variantes); identidad y persistencia; reproducción
(`Song → PlaybackResolver → PlaybackResource → adapter`); lookup y **aislamiento por
fuente**; artwork (UI, playlists y MediaSession, local vs remoto); catálogo y
búsqueda (`CatalogSearch`, `CatalogSources`, `CatalogSearchNotifier`,
`CatalogSearchState`); atribución (`ProviderAttribution`, `AttributionLookup`,
`ExternalLinkOpener`); composition root; base de datos v3; Android; testing.

## 6. Jamendo documentado

Credencial por `--dart-define` (sin valor real en ningún documento), activación
condicional, API HTTPS con reintentos y lotes, decodificación de entidades HTML,
reproducción remota con caché de URLs **solo en memoria** (TTL 10 min) y sin audio
persistido ni offline, carátulas remotas, atribución, wiring solo desde `app/` y la
regla de que `core` y las features genéricas no nombran al proveedor.

## 7. Build y release documentados

`README.md`: `flutter run` (con y sin `--dart-define=JAMENDO_CLIENT_ID=<CLIENT_ID>`),
`flutter test`, test de arquitectura, `flutter analyze`, `flutter build apk --debug` y
`--release`, rutas de salida y requisitos Android (SDKs, AGP, Kotlin, Java,
permisos). R8 activo y APK único con tres ABIs.

## 8. Firma de producción documentada (sin secretos)

La keystore vive **fuera del repositorio**; `android/key.properties` es local; ambos
están ignorados por Git; `buildTypes.release` usa `signingConfigs.release`; un release
sin esos datos **falla**; nunca se usa la clave de debug. Solo se documentan
conceptos (`storeFile=<ruta-local-a-la-keystore>`); se comprobó que ningún documento
contiene la contraseña ni el `client_id`.

## 9. Limitaciones actuales (documentadas, no convertidas en bugs)

- UI del lockscreen sin verificar (teléfono sin bloqueo seguro) y auriculares físicos.
- Seek en pistas remotas y muerte del proceso por el sistema sin verificar.
- Persistencia de `remote_*.img` entre reinicios en el release sin verificar.
- Segunda fuente, offline/descargas, localización, Ajustes reales: no implementados.
- AAB / Play App Signing: no evaluado.
- Deuda UX vista en Android (origen «Biblioteca» para pistas remotas, texto del
  permiso, Favoritos en error tras recálculo sin red, conteo de playlists con el
  permiso denegado).
- Licencias NC de Jamendo: no afirmar disponibilidad comercial.

## 10. Estado de fases (coherente con los informes)

| Fase | Estado |
|---|---|
| 1.x | CLOSED |
| 2.x | Completada (2.0–2.9) |
| 3.0 | Completada |
| 3.1 | Jamendo implementado |
| 3.2 | Búsqueda, atribución y acciones implementadas |
| 3.3 | Auditoría |
| 3.4 | Favoritos/playlists remotos |
| 3.5 | Aviso de errores de reproducción |
| 3.6 | Portadas de playlist remotas |
| 3.7 | 3.7A auditoría, 3.7B carátula remota en MediaSession |
| 3.8 | Auditoría |
| 3.9 | Validación Android + release: **PASS WITH NOTES, no CLOSED** (lockscreen y auriculares sin verificar) |
| 3.9B | Firma de producción: PASS |
| 3.10 | Esta fase |

## 11. DOCUMENTATION FOLLOW-UP / TECHNICAL DEBT (no se corrigió nada)

Comentarios de código obsoletos (no se modificó código):
- `core/artwork/artwork_providers.dart:20-31` («Hoy solo la local… Aún no lo consume la
  UI», «Hoy no hay ninguno»).
- `core/domain/entities/artwork_reference.dart:13` («hoy ninguna fuente produce una
  `RemoteArtworkReference`»).
- `core/domain/entities/playback_resource.dart:50` («Hoy no hay ninguna fuente que la
  produzca» — Jamendo produce `RemoteUriResource`).
- `core/domain/ports/remote_artwork_loader.dart:7` («hoy no hay ningún adaptador» —
  existe `HttpRemoteArtworkLoader`).

Otros: los informes históricos (`PHASE_3_3`, `PHASE_3_8`, parte de `PHASE_3_9`) citan
hallazgos ya resueltos como estado de su momento (se dejan); `ARCHITECTURE.md` ya no
lista los widgets legacy reemplazados (siguen en `DESIGN_SYSTEM.md` como histórico);
15 `.gitkeep` residuales; deuda técnica de código descrita en `ARCHITECTURE.md` y en
`PHASE_3_8`.

## 12. Validación final

`flutter analyze`, `flutter test` y `flutter test test/architecture/dependency_rules_test.dart`
(ver resultados en el reporte de entrega). **Archivos de producción modificados en
esta fase: 0.** Sin dependencias nuevas, sin commits ni push; no se generó APK
(no hubo cambios de código).
