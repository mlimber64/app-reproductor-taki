# Fase 3.8 — Auditoría global post-3.7B

Fase **solo de auditoría y documentación**. El único archivo creado es este. No se
modificó producción, tests, dependencias, manifest ni configuración, y no se
corrigió nada de lo encontrado. Todo hallazgo cita archivo/símbolo o test; lo que
no se pudo comprobar figura como **UNKNOWN / BLOCKED**, no como hecho.

Alcance de la evidencia: lectura del código (`lib/`, `android/`, `test/`), de los
`docs/`, búsquedas estáticas sobre el árbol y las cuatro validaciones de §20.
**No se ejecutó nada en Android** (no hay dispositivo/emulador) ni un build `release`.

Convenciones: `A` = dependencia intencional; `B` = legítima/provisional;
`C` = sospechosa; `D` = violación. Hallazgos: `REAL LEAK`, `POTENTIAL LEAK`,
`KNOWN DEBT`, `NO ISSUE`.

---

## 1. Executive Summary

- **Código: sólido y coherente.** Capas hexagonales respetadas (13/13 tests de
  arquitectura), dominio sin Flutter/SQLite/audio, ningún `core → feature`, ningún
  `player/search/playlists → jamendo`. El modelo universal (`Song`,
  `MusicIdentity`, `PlaybackResource`, `ArtworkReference`) está limpio: los datos
  locales (`id`, `albumId`, `path`, `contentUri`, `folder`) solo se leen en código
  local. Los tres `REAL_LEAK` de la auditoría 3.3 están corregidos (3.4, 3.6, 3.7B).
- **Calidad de pruebas alta:** 1614 tests (+1 saltado por falta de `JAMENDO_CLIENT_ID`),
  mutation testing manual en cada fase con 0 survivors reales.
- **Lo que NO está demostrado:** nada de lo hecho desde la 3.2F (acciones desde
  Search, atribución en Reproduciendo, enlaces externos, aviso de errores,
  portadas remotas de playlist, carátula en notificación/lockscreen) se ha visto
  funcionando en un Android. **Smoke test acumulado: BLOCKED — no Android
  device/emulator available.**
- **Bloqueadores de una primera release:** (1) la build `release` se firma con la
  clave de debug; (2) validación Android acumulada pendiente; (3) build `release`
  (R8/shrink) nunca ejecutada en estas fases; (4) **todo el trabajo de las fases
  2.x–3.7B está sin commit** (201 entradas en `git status`; último commit
  `a6f4cd6`, de la 1.9).
- **Deuda real documentable:** documentación de alto nivel (`README.md`,
  `ARCHITECTURE.md`) describe una app 100 % local y sin búsqueda: es **falsa hoy**;
  caché de carátulas del sistema sin limpieza; resolución masiva de URLs al
  encolar; reintentos de Jamendo en búsquedas vacías; fallo parcial silencioso en
  Favoritos/Playlists.
- **Siguiente paso claro:** no es una función nueva sino **validar en Android y
  cerrar la higiene de release** (§19).

---

## 2. Current Architecture

### 2.1 Inventario

`lib/`: **154 archivos**, ≈12.4 k líneas; `test/`: **105 archivos Dart** (91 `*_test.dart`);
`docs/`: 39 documentos; `android/`: `MainActivity.kt`, `MediaStoreChannel.kt`, 3 manifests.

| Directorio | Archivos | Contenido |
|---|---|---|
| `lib/main.dart` | 1 | Composition root: arma adapters y overrides |
| `lib/app` | 6 | `app.dart` (MaterialApp + `PlaybackErrorListener`), `router.dart`, wiring (`jamendo_wiring`, `song_lookup_wiring`), `song_actions_sheet` |
| `lib/core` | 73 | `domain` (entidades, puertos, servicios), `artwork`, `catalog`, `lookup`, `links`, `database`, `theme`, `widgets`, `utils` |
| `lib/features` | 74 | `library`, `player`, `playlists`, `search`, `settings`, `jamendo` |

### 2.2 Features

| Feature | Responsabilidad | Domain | Infra | Presentation | Estado |
|---|---|---|---|---|---|
| `library` | MediaStore, permiso de audio, favoritos | `Song` filtros, `LocalSongLookup`, `GetFavoriteSongs`, puertos | `MediaStoreSongRepository`, `SqfliteFavoritesRepository`, `PermissionHandlerMediaPermission` | `LibraryPage`, `FavoritesPage`, `songsProvider`, `favorites_providers` | Terminada |
| `player` | Cola, reproducción, MediaSession, aviso de errores, atribución | `PlaybackState`, `AudioPlayerPort`, casos de uso | `JustAudioPlayerAdapter`, `TakiAudioHandler`, `ArtworkFileCache`, `initPlayer` | `NowPlayingPage`, `MiniPlayer`, `QueuePage`, `AttributionSection`, `PlaybackErrorListener` | Terminada (Android sin validar) |
| `playlists` | CRUD de playlists y entradas | `Playlist`, `GetPlaylistSongs`, usecases | `SqflitePlaylistsRepository` | `PlaylistsPage`, `PlaylistDetailPage`, `add_to_playlist_sheet`, `playlist_cover_*` | Terminada |
| `search` | Búsqueda de catálogo (Jamendo vía contrato) | `CatalogSearchState`, `SearchCatalog`, política | `TimerSearchScheduler` | `SearchPage`, `CatalogSearchNotifier`, `SearchTexts` | Terminada (D6 diferido) |
| `jamendo` | Proveedor remoto (única fuente) | `JamendoApi`, `JamendoTrack`, lookups, resolver, `CatalogSearch` | `HttpJamendoApi`, parser, `html_entities`, credenciales | — (sin UI) | Terminada |
| `settings` | Ajustes | vacío | vacío | `SettingsPage` provisional | **Provisional** |

`core` aporta contratos: `SongLookup`, `AttributionLookup`, `CatalogSearch`,
`CatalogSources`, `PlaybackResolver`, `ArtworkResolver`, `RemoteArtworkLoader`,
`ArtworkHttpClient`, `ExternalLinkOpener`, y los servicios `Source*`.

### 2.3 Dependencias (comprobadas con `dependency_rules_test` y búsqueda de imports)

| Relación | Resultado | Clase |
|---|---|---|
| `core → app/features` | 0 imports | NO ISSUE |
| `features → app` | 0 imports | NO ISSUE |
| `core/domain` y `features/*/domain` → Flutter/Riverpod/sqflite/just_audio/audio_service/path_provider/permission_handler | **0 imports** (solo `equatable` permitido) | NO ISSUE |
| `player/search/playlists → features/jamendo` y mención textual | 0 (tests de arquitectura) | NO ISSUE |
| `app → features` | `app.dart`, `router.dart`, `song_actions_sheet`, wirings | **A** (la composición vive en `app/`) |
| `presentation → infrastructure` (mismo feature) | 7 imports, todos en `*_providers.dart` (instancian su adapter) | **A/B** (patrón de composición por feature; no hay DI externa) |
| Excepciones feature → feature | **7**, todas `presentation → presentation(providers)`: `library_page→player_providers`, `favorites_page→player_providers`, `now_playing_page→favorites_providers`, `playlists_providers→songs_notifier`, `playlist_detail_page→songs_notifier`, `playlist_detail_page→player_providers`, `search_page→player_providers` | **A** documentadas; las de `playlists → library` son **B** (provisionales: dependen de la biblioteca escaneada) |
| `player → library` (`now_playing_page → favorites_providers`) | corazón de favoritos | **B** |
| `search → player` | solo `player_providers` | **A** |
| `playlists → library` | solo `songsProvider` (reencuentro local) | **B** |

No se encontró ninguna **C** ni **D** con evidencia. Las excepciones del test
(`_allowedCrossFeature`, 7) **no coinciden** con el `README.md` («6 excepciones»);
`ARCHITECTURE.md` sí lista 7 (ver §13).

### 2.4 Congelar (no refactorizar)

`MusicIdentity` / persistencia `source+external_id` (esquema v3), contrato
`SongLookup`/`SongLookupResult`, la separación `Song`/`LocalSong`,
`PlaybackResource`, `ArtworkReference`, `SourcePlaybackResolver`,
`findAllIsolatingSources`, el id del `MediaItem`
(`encode(source)/encode(externalId)`), y la guarda de carreras del handler. Todos
tienen tests de regresión y ya son consumidos por varias capas.

---

## 3. Music Model Audit

| Pregunta | Evidencia |
|---|---|
| ¿Quién crea `Song`? | Fuentes remotas (`songFromJamendoTrack`) y `LocalSong extends Song` (`MediaStoreSongRepository._toSong`) |
| ¿Quién usa `LocalSong`? | `library` (filtros, lookup, repo), `SongMatcher`, `LocalPlaybackResolver`, `LocalArtworkResolver`, `localPathOf`, y los providers de favoritos/playlists **solo** como lista de reencuentro |
| `is LocalSong` / `as LocalSong` | solo `is!` en `LocalPlaybackResolver` y `LocalArtworkResolver`, y `localPathOf` (límites correctos); **0 `as LocalSong`** |
| `albumId` | `LocalSong`, `MediaStoreSongRepository`, `MediaStoreChannel.kt`, rama local de `ArtworkCache` y de `ArtworkFileCache` → todo local |
| `contentUri` | `LocalSong`, `LocalPlaybackResolver`, repo/canal → local |
| `path`/`folder` | `LocalSong`, `SongFilter`, `SongMatcher`, respaldo SQLite (`path` null para remotas) → local |
| `Song.id` como identidad universal | **ninguno**: solo `GetSongs` (orden estable de `LocalSong`) y tests |
| Conversión `MusicIdentity → int` / parseo de `externalId` | **ninguno** (solo `int.tryParse` en `html_entities` y la ruta de la playlist) |
| Persistencia con claves antiguas | v3 `PRIMARY KEY(source, external_id)`; `song_id INTEGER` solo en el esquema v2 **congelado** para la migración |
| Código que asume `source == local` | `GetFavoriteSongs`/`GetPlaylistSongs` (reencuentro **solo** si local y `missing`), `JustAudioPlayerAdapter` default `LocalPlaybackResolver` (ver §4) |

Clasificación: **SAFE_LOCAL_SPECIFIC** el código anterior; sin `REAL LEAK` restante
en el modelo. `POTENTIAL`: el default `LocalPlaybackResolver` del adaptador
(`just_audio_player_adapter.dart:46`) — producción siempre inyecta el resolver
(`main.dart:28`).

---

## 4. Playback Audit

Flujo: UI → `PlaySongs`/`PlayNext`/`AddToQueue` → `AudioPlayerPort` →
`JustAudioPlayerAdapter._toSources` → `SourcePlaybackResolver` →
`Local|Jamendo PlaybackResolver` → `PlaybackResource` → `AudioSource.uri` →
`TakiAudioHandler` (`MediaItem`, `playbackState`) → audio_service → MediaSession.

| Aspecto | Estado | Evidencia |
|---|---|---|
| Recursos | `Local/RemoteUriResource` → `AudioSource.uri`; `Provider/Unavailable` y fallos de resolución → fuente `taki-unplayable` que falla y salta | `_toSource` |
| Salto por error | emite `PlaybackError` y salta (máx. 10 seguidos, luego pausa) | `_onError`, `_maxConsecutiveSkips` |
| Consumidor de errores | `PlaybackErrorListener` (3.5) | tests + app test |
| Cola con duplicados | sin dedupe; clave de `Cola` = identidad + n.º de repetición | `queue_page.dart:45` |
| Identidad | `MediaItem.id` opaco por identidad | tests del handler |
| Carrera A→B (carátula) | guarda por `id` + guarda del plugin | tests |
| Fuera de serialización | `addToQueue`/`playNext` comprueban `_sources.isEmpty` **antes** de `_serialized` (líneas 232, 244) | **POTENTIAL LEAK** (ya anotado en `ARCHITECTURE.md`); sin test que lo provoque |
| Resolución masiva | `setQueue`/`addToQueue`/`playNext` resuelven **todas** las canciones con `Future.wait`; en frío, Jamendo hace una consulta por canción | **POTENTIAL (MEDIUM)**; mitigado por `JamendoAudioCache` (TTL 10 min, 500) rellena por búsqueda/lookup |
| URL de audio fijada al encolar | caduca ≥20 min según 3.1B; canciones muy posteriores podrían fallar al llegar su turno | **KNOWN DEBT** (D7), caducidad no medida |
| `RemoteUriResource` | solo exige URI no vacía; **no** valida `http(s)` ni el parser de Jamendo valida el campo `audio` | **POTENTIAL LEAK (LOW)** (API de confianza; ExoPlayer abriría `file://` o `content://`) |
| `RemoteUriResource.expiresAt` | ningún productor lo usa | **KNOWN DEBT** (campo previsto) |
| Estados obsoletos / eventos perdidos | `errors` es un `StreamController.broadcast`: un evento emitido antes de suscribirse se pierde; el listener se suscribe en el primer frame de la app | **POTENTIAL (LOW)** |
| Segundo plano / MediaSession | metadata y controles verificados en tests; **no en Android** | ver §8 |

---

## 5. Artwork Audit

| Camino | Piezas | Estado |
|---|---|---|
| UI local | `LocalArtworkReference` → `ArtworkCache` (LRU 200, dedupe de peticiones en vuelo) → `ArtworkRepository` (canal MediaStore) → `AlbumArtworkBuilder` → `TakiArtwork` | NO ISSUE |
| UI remota | `RemoteArtworkReference` → `ArtworkCache` → `HttpRemoteArtworkLoader` (https/http+host, 10 s, 5 MB, firma JPEG/PNG/GIF/WebP) → mismo builder | NO ISSUE; fallo remoto **no se memoiza** (reintentable) |
| MediaSession local | `ArtworkFileCache` → `album_<id>_512.jpg` → `file://` → `MediaItem.artUri` | NO ISSUE en código/tests |
| MediaSession remota (3.7B) | `ArtworkFileCache` + `RemoteArtworkLoader` → `remote_<fnv64>.img` (escritura atómica + dedupe) | NO ISSUE en código/tests; **no probado en Android** |
| Mosaicos de playlist | `playlistCoverArtworkProvider` (local + remota vía `SongLookup`) | NO ISSUE |

Comparación de cachés (no hay duplicación de **descarga**; sí tres niveles con
propósitos distintos):

| Caché | Dónde | Clave | Límite | Limpieza |
|---|---|---|---|---|
| `ArtworkCache` | memoria (UI) | `(ArtworkReference, size)` | 200 entradas LRU | `clear()` en `rescan` |
| `ArtworkFileCache` | disco (cache dir `artwork/`) | `album_<id>_<size>` / `remote_<fnv64>` | **ninguno** | **ninguna** (el SO purga el cache dir) |
| `JamendoAudioCache` | memoria | `MusicIdentity` | 500, TTL 10 min | por TTL |

Hallazgos:
- **KNOWN DEBT (MEDIUM a largo plazo):** `ArtworkFileCache` crece sin tope (una pista
  de Jamendo = un archivo ≈ decenas de KB); sin limpieza propia.
- **POTENTIAL (LOW):** una descarga **simultánea** entre la UI (`ArtworkCache`) y la
  notificación (`ArtworkFileCache`) de la misma URL baja la imagen **dos veces**
  (dos cachés independientes; los dos comparten una sola instancia del loader pero
  no estado). Aceptable: tamaño pequeño y una vez por URL.
- **NO ISSUE:** la carrera A→B está cubierta (handler y archivo).
- `artworkResolverProvider` / `buildArtworkResolver`: cableado, **sin consumidor**
  (ver §11).
- Fondos de archivo huérfanos: un temporal `*.tmp` solo si el proceso muere a mitad
  de escritura (**LOW**).
- `size`: el loader ignora `size`; la URL de Jamendo ya trae `width=300`; el archivo
  de notificación remoto es de 300 px frente a 512 px del local (diferencia sin
  impacto probado).

---

## 6. Search / Catalog Audit

Evidencia: `catalog_search_providers.dart`, `search_catalog.dart`,
`jamendo_catalog_search.dart`, tests de `features/search` (5 archivos, ≈1.9 k líneas).

| Aspecto | Resultado |
|---|---|
| Ciclo de vida de la consulta | `Idle → Typing → Loading → Results/Empty/Failed`; mínimo 2 caracteres; volver a la consulta asentada no relanza |
| Debounce | `SearchScheduler` (puerto) + `ManualSearchScheduler` en tests; sin timers reales en tests |
| Cancelación / carreras | token de **generación** (`_generation`), respuestas viejas se descartan; el puerto no se cancela (solo se ignora) — **NO ISSUE** |
| Paginación | `nextOffset` avanza por `pageSize` (no por lo visible); `hasMore` del catálogo; página vacía ⇒ fin; página toda repetida no es fin |
| Deduplicación | por `MusicIdentity`, primera aparición gana; nunca por título/URL |
| Fallos | `CatalogSearchFailure` ⇒ `SearchFailed`/`loadMore failed`; sin reintento automático |
| Múltiples proveedores | `sources.available.first` (**provisional**, D6 diferido); `CatalogSources`/`CatalogProviderInfo` neutrales |
| Atribución | resultado la trae en memoria; `AttributionLookup` por identidad para el resto; sin persistir |
| Credencial | `client_id` solo por `--dart-define`; formato validado (4–64 `[A-Za-z0-9_-]`); sin él, Jamendo no se registra y la pestaña Buscar no existe |
| Persistencia de secretos/URLs | ninguna (ver §9) |
| Reintentos en búsqueda vacía | `HttpJamendoApi` reintenta hasta **3 veces** una respuesta vacía (300 ms): una búsqueda **legítimamente sin resultados** cuesta 4 peticiones y ≈0,9 s extra (**POTENTIAL, MEDIUM** frente a la cuota de 10 req/s y 500 000/mes de 3.1A; motivo: intermitencia observada en 3.1B) |

**¿Preparada para un segundo proveedor sin acoplar features?** Sí en arquitectura:
`CatalogSources.searchIn(source)`, `SourceSongLookup`, `SourcePlaybackResolver`,
`SourceArtworkResolver` y `SourceAttributionLookup` enrutan por `identity.source`;
un proveedor nuevo entra por `app/*_wiring`. Lo que faltaría es **de producto**
(D6): cursor por fuente, fallos parciales en la página y política de mezcla; y el
aislamiento por fuente dentro de `SourceSongLookup` (hoy solo en los casos de uso
de Favoritos/Playlists, no en el contrato). No se implementó.

---

## 7. Favorites / Playlists Audit

| Tema | Evidencia | Resultado |
|---|---|---|
| Esquema | `taki_database.dart` v3: `PRIMARY KEY (source, external_id)` en favoritos; `playlist_songs` con `id` propio y sin `UNIQUE` (duplicados permitidos); `CHECK` de no vacío | NO ISSUE |
| Migración | v1/v2 → v3 con copia verificada y transacción | NO ISSUE (tests en `taki_database_test`) |
| Orden y duplicados | posiciones contiguas; `GetPlaylistSongs` conserva orden y duplicados | NO ISSUE (tests 3.4) |
| Reencuentro/relink | solo identidades **locales** `missing`; nunca para `failed` ni remotas | NO ISSUE (mutation 3.4) |
| Canción no resuelta | se oculta, **no se borra** | NO ISSUE |
| Fuente caída | solo se ocultan sus identidades; si fallan todas, error de página | **KNOWN DEBT**: el fallo parcial es **silencioso** (la UI no distingue «oculta por fallo» de «no existe») |
| Permiso local | ya no bloquea remotas; con solo locales se pide permiso; con mixtas y sin permiso las locales quedan ocultas **sin aviso** | **KNOWN DEBT** |
| Playlists mixtas | portada: local con prioridad + remota por `SongLookup` en una sola consulta por cambio del conjunto | NO ISSUE |
| Colisión de fuentes | `local:42 ≠ jamendo:42 ≠ jamendo:0042` en SQLite (texto) | NO ISSUE (tests) |
| Riesgo de pérdida de datos | no hay `DELETE` fuera de acciones explícitas del usuario (quitar/eliminar playlist/favorito); la copia de respaldo sirve solo al reencuentro local | NO ISSUE |
| Latencia | los providers esperan el escaneo local (instantáneo sin permiso) antes de resolver | **KNOWN DEBT (LOW)** |
| Backup | el manifest no fija `android:allowBackup`: el valor por defecto (`true`) respalda `taki.db` (favoritos/playlists) | **NO VERIFICADO / informativo** |

---

## 8. Android / MediaSession Audit

### 8.1 Configuración (código)

- `AndroidManifest.xml` (main): `INTERNET`, `READ_MEDIA_AUDIO`, `READ_EXTERNAL_STORAGE`
  (`maxSdkVersion=32`), `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`,
  `WAKE_LOCK`, `POST_NOTIFICATIONS`; servicio `AudioService`
  (`foregroundServiceType=mediaPlayback`) y `MediaButtonReceiver`;
  `<queries>` http/https (prescindible: ver 3.7A, no se usa `canLaunchUrl`).
- Sin `usesCleartextTraffic` ni `networkSecurityConfig`: con `targetSdk` 36 el
  tráfico `http://` queda bloqueado para ExoPlayer y `HttpClient` de Java; la API de
  Jamendo usa `Uri.https` y las carátulas/enlaces se validan `http(s)` (el audio
  remoto no se valida: §4).
- `MainActivity extends AudioServiceActivity` y registra `MediaStoreChannel` una vez
  (el engine sobrevive a la Activity). El canal usa un pool de 3 hilos y devuelve en
  el hilo principal; `querySongs` carga **toda** la biblioteca en una llamada.
- `build.gradle.kts`: `applicationId = com.limbermendoza.taki`, `release` **firmado
  con la clave de debug** (`signingConfigs.getByName("debug")`); sin reglas
  ProGuard/R8 propias; `versionName`/`versionCode` de Flutter (`1.0.0+1`); queda un
  comentario `TODO` obsoleto sobre el applicationId.

### 8.2 Qué está verificado y dónde

| Nivel | Qué |
|---|---|
| **VERIFICADO EN CÓDIGO** | todo lo anterior; handler/adaptador/MediaItem/artUri; wiring en `main.dart` |
| **VERIFICADO EN TEST** | controles de MediaSession y estado (`taki_audio_handler_test`), skip y errores del adaptador (`just_audio_player_adapter_test`, falso de just_audio), `ArtworkFileCache`, aviso de errores (widget), carreras A→B (handler) |
| **VERIFICADO EN ANDROID** | solo lo que el propietario dio por validado en dispositivo **hasta la 3.2E** (búsqueda en Jamendo desde 2 caracteres, reproducción, carátula remota en filas de Search, MiniPlayer, paginación) y las mediciones de carátulas locales de la 1.8K. **Ninguna fase posterior** |
| **NO VERIFICADO** | notificación y lockscreen (local y remota), auriculares, `POST_NOTIFICATIONS` en Android 13+, `FOREGROUND_SERVICE_MEDIA_PLAYBACK` (Android 14+), apertura de enlaces externos, aviso de errores en pantalla, muerte del proceso y reinicio, comportamiento sin red, build `release` |

**Smoke test acumulado 3.2F → 3.7B: BLOCKED — no Android device/emulator available.**

---

## 9. Security / Privacy Audit

| Elemento | Evidencia | Resultado |
|---|---|---|
| `client_id` en repo | no hay `.env`/keystore versionados; `android/local.properties` no está en el índice; el id solo llega por `--dart-define` | NO ISSUE |
| `client_id` en binario | `String.fromEnvironment` queda **embebido** en el APK (extraíble) | **KNOWN DEBT / inherente** a un cliente sin backend; Jamendo lo trata como identificador de app |
| `client_id` en logs/errores | **0** `print`/`debugPrint`/`log`; las excepciones de Jamendo no incluyen URI ni causa (`jamendo_exception`, `http_jamendo_api`), y el parser sustituye el id por `***` en mensajes de la API; tests de seguridad dedicados (`jamendo_security_test`) | NO ISSUE |
| `client_id` en URL | viaja en la query (`Uri.https(host, …)`); el transporte (`IoArtworkHttpClient` = `HttpClient` de `dart:io`) **sigue redirecciones** | **POTENTIAL (LOW)**: ante una redirección a otro host la query iría con ella; no observado |
| Transporte compartido | `HttpJamendoApi` usa el cliente «de carátulas»: 10 s, 4 MB (API) / 5 MB (carátulas) | NO ISSUE (nombre histórico, documentado) |
| URLs de audio | solo en memoria (`JamendoAudioCache`); nunca SQLite | NO ISSUE |
| URLs de carátula | en `Song.artwork` (memoria); en disco solo como **nombre hasheado** y bytes | NO ISSUE |
| URLs de atribución | en memoria; **no** se persisten | NO ISSUE |
| SQLite | solo `source`, `external_id`, título/artista/álbum/duración y `path` local | NO ISSUE |
| Enlaces externos | solo `http(s)` con host y sin espacios (`openableUrl*`); nunca interno; fallo ⇒ `false` | NO ISSUE (la ruta real de `url_launcher` no se prueba: depende de plataforma) |
| Validación del audio remoto | ver §4 (`RemoteUriResource`) | **POTENTIAL (LOW)** |
| Telemetría / llamadas inesperadas | ninguna dependencia de analítica; llamadas solo a `api.jamendo.com`, a las URLs de carátula/audio que devuelve y a lo que abre el usuario; **`audio_service` incluye `flutter_cache_manager`** como transitiva (no usada por Taki) | NO ISSUE |
| Licencias | las pistas CC-NC prohíben uso comercial (`PHASE_3_1B`); la atribución se muestra en Reproduciendo (no en listas) | **IMPORTANT** si la app se distribuye con fines comerciales |
| Cuota de Jamendo | Free: 10 req/s, 500 000/mes (3.1A); **cuota efectiva y caducidad del audio sin determinar** (3.1B) | **KNOWN DEBT** |

---

## 10. Dependency Audit

| Paquete | `lib/` | `test/` | Estado |
|---|---|---|---|
| `flutter_riverpod` | 32 imports | 29 | usada |
| `go_router` | 1 (`router.dart`) | 1 | usada |
| `equatable` | 9 | 1 | usada (también en `core/domain`, único paquete permitido) |
| `just_audio` | 2 | 2 | usada |
| `audio_service` | 2 (+ `MainActivity.kt`) | 1 | usada |
| `audio_session` | 1 (`player_bootstrap`) | 0 | usada |
| `permission_handler` | 2 | 0 | usada |
| `device_info_plus` | 1 (`permission_handler_media_permission`) | 0 | usada (elige el permiso según SDK) |
| `sqflite` | 4 | 0 | usada |
| `path_provider` | 1 (`artwork_file_cache`) | 0 | usada |
| `url_launcher` | 1 (`external_link_providers`) | 0 | usada (añadida en 3.2F; sin más usos) |
| `flutter_localizations` | 1 (`app.dart`) | 0 | usada |
| `cupertino_icons` | **0** | 0 | **no utilizada** (resto de la plantilla; sin `CupertinoIcons`) |
| `mocktail`, `sqflite_common_ffi`, `flutter_test`, `flutter_lints` | — | sí | dev |
| Fuentes Sora y DM Sans | assets OFL declarados | — | usadas |
| Transitivas notables | `flutter_cache_manager`, `url_launcher_*`, `rxdart`, `sqflite_*` | — | transitivas |

`flutter pub add` reportó **31 paquetes con versiones más nuevas incompatibles con
las restricciones**: no se evaluó; es deuda de mantenimiento, no de esta fase. No
hay dependencias potencialmente obsoletas demostradas.

---

## 11. Dead Code / Duplication

| Hallazgo | Evidencia | Clase |
|---|---|---|
| `artworkResolverProvider`, `buildArtworkResolver`, `SourceArtworkResolver`, `LocalArtworkResolver`, `SongArtworkResolver`, puerto `ArtworkResolver` | cableados en `main.dart`/`jamendo_wiring.dart`; **ningún `ref.watch/read`** en `lib/`; la UI usa `song.artwork` | **UNUSED/DEAD** funcional (con tests); punto previsto para un resolvedor por fuente |
| `audioHandlerProvider` | solo definición + override en `main.dart`; sin lectores (el handler vive por `AudioService`) | **UNUSED** |
| `openableUrlFromText` | solo tests (12 usos) y su propia definición | **TEST-ONLY** |
| `ProviderPlaybackResource`, `RemoteUriResource.expiresAt` | sin productores; el adaptador sí los maneja | **KNOWN DEBT** (previstos) |
| `cupertino_icons` | declarada y sin uso | UNUSED dependencia |
| `.gitkeep` | 15; incluidos `features/search/**` que ya tienen código y `settings`/`core/error` vacíos | residuo |
| Helper de test `localRef` | `artwork_reference_ext.dart:18`, sin uso | residuo menor |
| `AppColors` | **0** referencias en `lib/`; solo menciones históricas en docs | NO ISSUE |
| Widgets antiguos (`ArtworkImage`, `AlbumArtworkImage`) | eliminados (commits previos); sin referencias | NO ISSUE |
| Duplicación de artwork | tres cachés con roles distintos (§5); ningún segundo cliente HTTP | NO ISSUE |
| Duplicación Jamendo | `JamendoSongLookup`/`JamendoAttributionLookup` comparten la forma (filtrar fuente → `tracksByIds` → mapear) | NO ISSUE (clases pequeñas, contratos distintos) |
| Textos de UI duplicados en español | repartidos entre `SearchTexts`, literales en páginas de playlists/favoritos y `PlaybackErrorTexts` | **KNOWN DEBT** (sin infraestructura de localización; solo español) |

---

## 12. Testing Audit

**1614 tests** + 1 saltado (`jamendo_credentials_test.dart:73`: requiere
`JAMENDO_CLIENT_ID` en tiempo de compilación). Sin `integration_test/` ni tests
instrumentados Android.

| Área | Archivos de test | Valoración |
|---|---|---|
| Arquitectura | 1 (13 reglas) | **A** bien cubierto |
| `core/domain` | 13 | **A** |
| `core/database` | 1 (≈600 líneas) | **A** (migraciones con `sqflite_common_ffi`) |
| `core/widgets` | 12 | **A** |
| `core/artwork` | 3 | **A** |
| `jamendo` | 10 | **A** (parser, API con falso, seguridad, atribución) |
| `search` | 5 | **A** (generación, paginación, dedupe, textos) |
| `player` | 12 | **A** (adaptador con falso de just_audio, handler, listeners, atribución) |
| `library`/`playlists` | 12 / 8 | **A** |
| `app` | 7 | **A/B** (router, wiring, errores) |
| Carreras A→B | handler, atribución, búsqueda, `ArtworkFileCache` | **A** |
| Mutation testing | manual, con registro en cada `PHASE_3_*` (0 survivors reales al cierre) | **A** (no automatizado ni reproducible por CI) |
| Notificación/lockscreen/auriculares/foreground/proceso muerto | solo vía falsos | **C requiere Android** |
| `UrlLauncherLinkOpener` real, `launchUrl` | sin test (colgaba bajo `testWidgets`) | **C requiere Android** |
| Descarga real de carátulas/atribución | falsos | **C requiere Android/red** |
| Rendimiento (listas grandes, `querySongs`) | sin pruebas | **B insuficiente** |
| Release/R8 | ninguna | **C / B** |

No se agregaron tests en esta fase.

---

## 13. Documentation Audit (solo reporte; no se corrigió nada)

| Documento | Afirmación obsoleta o falsa hoy | Evidencia |
|---|---|---|
| `README.md` | «Reproductor de música **local**… funciona **100 % en el dispositivo**: sin backend…» | Taki consulta Jamendo si hay `JAMENDO_CLIENT_ID`; `INTERNET` en el manifest |
| `README.md` | Funcionalidades y stack no mencionan Búsqueda, Jamendo, atribución, enlaces ni `url_launcher`; lista de features «library, player, playlists, settings» | falta `search` y `jamendo` |
| `README.md` | «6 excepciones documentadas» | el test enumera **7** |
| `README.md` | Sin instrucciones de `--dart-define=JAMENDO_CLIENT_ID=…` | `jamendo_credentials.dart` |
| `README.md` | «Las canciones… reencuentran aunque cambie su id» | cierto solo para locales |
| `docs/ARCHITECTURE.md` | «reproductor de música **local**… sin telemetría» (líneas 3-5) | idem |
| `docs/ARCHITECTURE.md` | `search/`: «Esqueleto vacío: solo carpetas con `.gitkeep`, sin código ni ruta» (línea 57) y «`features/search` son carpetas vacías» (línea ~497) | `search` tiene dominio, infra, presentación, ruta y tests |
| `docs/ARCHITECTURE.md` | «Pestañas: Biblioteca, Playlists, Favoritos y Ajustes» | hay «Buscar» condicional (`hasSearch`) |
| `docs/ARCHITECTURE.md` | tabla `Song`: «id, `albumId`, ruta, `contentUri`, fecha y carpeta» | esos campos son de `LocalSong` desde la 2.9 |
| `docs/ARCHITECTURE.md` | «Solo hay carátulas locales» (línea ~217) y flujo de carátula «local» | hay `RemoteArtworkReference`, `ArtworkCache` remota y `ArtworkFileCache` remota |
| `docs/ARCHITECTURE.md` | «Estas excepciones deberán reevaluarse cuando Taki incorpore el catálogo online» | el catálogo ya existe |
| `docs/ARCHITECTURE.md` | no describe `core/catalog`, `core/lookup`, `core/links`, `jamendo`, atribución | ausentes |
| Comentarios de código | `playback_resource.dart:50-51` «Hoy no hay ninguna fuente que la produzca» (Jamendo la produce); `artwork_reference.dart:13-14` «hoy ninguna fuente produce una `RemoteArtworkReference` y no hay cargador de red»; `remote_artwork_loader.dart:7` «hoy **no hay ningún adaptador**» (existe `HttpRemoteArtworkLoader`); `artwork_providers.dart` «Hoy solo la local… Aún no lo consume la UI» | comentarios previos a la 3.1/3.2 |
| `docs/PHASE_3_3_*` | los `REAL_LEAK 1/2/3` figuran abiertos | resueltos en 3.4, 3.6 y 3.7B (el documento es un registro histórico y no lo indica) |
| `docs/DESIGN_SYSTEM.md` | menciones a `AppColors` | marcadas como históricas («eliminado en 1.9B»): **NO ISSUE** |
| `docs/PHASE_3_2D_*` | §1 «estado actual» describe pre-3.2E | el §0 aclara el estado; coherente |
| Promesas no validadas | afirmaciones de notificación/lockscreen/artwork remoto en 3.7B | documentadas con «Android: BLOCKED» (correcto) |

Estado del árbol: **201 entradas en `git status`** (78 modificados + 123 sin
seguimiento); el último commit (`a6f4cd6 refactor: remove legacy widgets`) es de la
fase 1.9. Todo el trabajo 2.x–3.7B, incluidos los documentos citados, **no está
versionado**.

---

## 14. Performance Audit (estático; sin benchmarks)

| Área | Hallazgo | Nivel |
|---|---|---|
| Encolar remotas en frío | N consultas Jamendo en paralelo (una por canción) con `Future.wait` | **MEDIUM** |
| Búsquedas vacías | hasta 4 peticiones por búsqueda sin resultados (`emptyRetries`) | **MEDIUM** |
| `querySongs` | carga toda la biblioteca y filtra en Dart; sin paginación | LOW–MEDIUM (bibliotecas grandes; sin medir) |
| Favoritos/Playlists | una consulta en lote por fuente; esperan el escaneo local | LOW |
| Portadas de playlist | una consulta en lote por cambio de conjunto; imágenes por `ArtworkCache` | LOW |
| Descargas repetidas de carátula | UI y notificación bajan la misma URL por separado una vez | LOW |
| `ArtworkFileCache` | crecimiento sin tope | LOW ahora / MEDIUM a largo plazo |
| Paginación de Search | `loadMore` por scroll con generación; `SliverPrototypeExtentList` | LOW |
| Decodificación | `ResizeImage` limita el tamaño; el plugin decodifica el archivo completo (sin `artDownscale`) | LOW |
| Presión de memoria | `ArtworkCache` 200 imágenes sin tope de bytes; `JamendoAudioCache` 500 URLs | LOW |
| Concurrencia | pool de 3 hilos en el canal nativo; dedupe en vuelo en cachés | LOW |

---

## 15. Release Blockers

| Nivel | Item | Evidencia | Impacto |
|---|---|---|---|
| **BLOCKER** | Release firmada con clave de debug | `android/app/build.gradle.kts:36-37` | no publicable |
| **BLOCKER** | Validación Android acumulada (3.2F → 3.7B) sin hacer | **BLOCKED** (sin dispositivo) | notificación, lockscreen, enlaces, errores, carátula remota sin demostrar |
| **BLOCKER** | Build `release` (R8/shrink con audio_service, just_audio, sqflite, canal propio) nunca ejecutada en estas fases | no hay evidencia; sin reglas propias | riesgo de crash solo en release (**UNKNOWN**) |
| **BLOCKER (proceso)** | 2.x–3.7B sin commit | `git status` (201); último commit `a6f4cd6` | una release debe salir de un commit/tag |
| **IMPORTANT** | `README`/`ARCHITECTURE` describen una app local que ya no es | §13 | información falsa para colaboradores |
| **IMPORTANT** | Licencias NC de Jamendo y atribución solo en Reproduciendo | 3.1B, 3.2F | uso comercial prohibido; revisar antes de distribuir |
| **IMPORTANT** | Cuota y caducidad del audio de Jamendo sin medir | 3.1B | fallos en producción con colas largas |
| **IMPORTANT** | Permiso/notificaciones en Android 13/14 sin probar | manifest + `PermissionHandler…` | primer arranque |
| KNOWN DEBT | Fallo parcial silencioso, locales ocultas sin aviso | §7 | UX |
| KNOWN DEBT | `ArtworkFileCache` sin limpieza; resolución masiva; reintentos vacíos | §14 | rendimiento |
| KNOWN DEBT | Pantalla de Ajustes provisional; `cupertino_icons` sin uso | README | cosmético |
| FUTURE FEATURE | Segundo proveedor/D6, modo offline, localización | — | no mezclar con hardening |

Cobertura de las dimensiones pedidas: *INTERNET* presente en main/debug/profile
(**no** hace falta nada más); *attribution* implementada (Reproduciendo);
*persistencia* sin pérdidas demostradas; *crash paths* de playback/artwork
degradan a `null`/aviso; *offline local* sin dependencia de red (la red solo la usan
Search/Jamendo/carátulas remotas); *privacy* sin telemetría.

---

## 16. Android Validation Matrix

Leyenda: **VERIFIED** = se vio funcionar en Android (según lo registrado/dado por el
propietario); **PARTIAL** = código y tests (o validado antes de un cambio posterior)
pero no confirmado hoy en Android; **BLOCKED** = requiere dispositivo que no existe
ahora; **UNKNOWN** = sin evidencia en ningún nivel.

| Área | Código | Tests | Android | Estado |
|---|---|---|---|---|
| Reproducción local | sí | sí | usada en fases previas, sin registro de smoke test | PARTIAL |
| Reproducción Jamendo | sí | sí | validada por el propietario en 3.2E | VERIFIED (hasta 3.2E; no repetida después) |
| Búsqueda | sí | sí | validada en 3.2E | VERIFIED (hasta 3.2E) |
| Favoritos (local) | sí | sí | sin registro | PARTIAL |
| Favoritos remotos / sin permiso | sí (3.4) | sí | no | BLOCKED |
| Playlists (local) | sí | sí | sin registro | PARTIAL |
| Playlist mixta | sí (3.4/3.6) | sí | no | BLOCKED |
| Notificación | sí | falsos | no | BLOCKED |
| Lockscreen | sí | falsos | no | BLOCKED |
| Auriculares / botones | sí (handler) | sí | no | BLOCKED |
| Cola | sí | sí | sin registro | PARTIAL |
| Shuffle / repeat | sí | sí | sin registro | PARTIAL |
| Carátula remota en UI | sí | sí | validada en filas de Search (3.2E); playlists/Now Playing no | PARTIAL |
| Carátula remota en notificación/lockscreen (3.7B) | sí | sí | no | BLOCKED |
| Carátula remota ya en caché (sin red) | sí | sí | no | BLOCKED |
| Carrera A→B (carátula) | sí | sí (handler/archivo) | no | BLOCKED |
| Aviso de error de reproducción | sí (3.5) | sí | no | BLOCKED |
| Enlaces externos (atribución) | sí | parcial (política) | no | BLOCKED |
| Denegación de permiso de música | sí | sí | no | BLOCKED |
| Reinicio de la app / muerte del proceso | sí | falsos | no | BLOCKED |
| Build `release` | firma debug | — | no | UNKNOWN |

---

## 17. Technical Debt (demostrable)

| # | Item | Evidencia | Recomendación (futura, no implementada) |
|---|---|---|---|
| T1 | `README`/`ARCHITECTURE` obsoletos | §13 | fase de documentación |
| T2 | `ArtworkFileCache` sin límite/limpieza | `artwork_file_cache.dart` | política simple (tope o antigüedad) |
| T3 | Fallo parcial silencioso en Favoritos/Playlists | `findAllIsolatingSources` + páginas | comunicar el fallo parcial |
| T4 | Resolución masiva de URLs al encolar | `_toSources` | resolver perezosamente / medir |
| T5 | Reintentos de respuesta vacía de Jamendo | `HttpJamendoApi.emptyRetries` | revisar con medición real |
| T6 | `addToQueue`/`playNext` fuera de la serialización | `just_audio_player_adapter.dart:232,244` | comprobar dentro de `_serialized` |
| T7 | `RemoteUriResource`/campo `audio` sin validar esquema | `playback_resource.dart`, parser | validar `http(s)` |
| T8 | Código sin consumidor (`ArtworkResolver*`, `audioHandlerProvider`, `openableUrlFromText`) | §11 | decidir uso o retirada |
| T9 | `cupertino_icons`, `.gitkeep`, `localRef` | §10/§11 | limpieza menor |
| T10 | Comentarios «hoy no hay…» obsoletos | §13 | actualizar |
| T11 | `<queries>` http/https del manifest | 3.7A | quitar si el enlace abre sin ella |
| T12 | Textos sin infraestructura de localización | §11 | solo si se añade otro idioma |
| T13 | Aislamiento por fuente solo en casos de uso, no en `SourceSongLookup` | 3.4 | cuando llegue el 2.º proveedor |
| T14 | 31 paquetes con versiones nuevas incompatibles | `pub add` | mantenimiento |

---

## 18. Future Features (no mezclar con hardening)

- D6: segundo proveedor, selector de fuente/fan-out, mezcla y ranking.
- Modo offline / descarga de pistas remotas.
- Atribución en listas/detalle de canción, y pantalla de detalle.
- Acciones de cola específicas de Search («reproducir resultados»).
- Localización a otros idiomas; Ajustes reales.
- Precarga de carátulas, telemetría o cuentas (no existen hoy; no se proponen).

---

## 19. Recommended Next Phase

1. **Antes de continuar:** (a) versionar el trabajo acumulado (commit/tag por el
   propietario); (b) conseguir un dispositivo o emulador Android.
2. **Validaciones necesarias:** el **smoke test acumulado** de §16 (notificación y
   lockscreen con una pista de Jamendo y con una local, cambio A→B rápido, sin red,
   enlaces de atribución, aviso de error con una pista rota, denegar el permiso de
   música, matar el proceso y reabrir) y una **build `release`** probada.
3. **Siguiente fase técnica concreta:** **PHASE 3.9 — Android validation & release
   readiness**: ejecutar el smoke test, generar y probar la build release
   (R8/ProGuard), definir la firma de release y registrar los resultados. Si el
   smoke test descubre fallos, se corrigen en fases de alcance mínimo separadas.
4. **Después, por separado:** actualización de `README`/`ARCHITECTURE` (T1/T10) y,
   si se prioriza, el hardening menor T2–T7.
5. **No hay una siguiente fase de producto clara** hasta que exista validación en
   dispositivo; las funciones de §18 son decisiones de producto, no continuación
   técnica obligatoria.

---

## 20. Validation Results

Ejecutado en esta fase (sin cambios de código):

| Comprobación | Resultado |
|---|---|
| `flutter analyze` | **No issues found** |
| `flutter test` | **1614 pasan, 1 saltado** (el que exige `JAMENDO_CLIENT_ID`) |
| `flutter test test/architecture/dependency_rules_test.dart` | **13/13** |
| `flutter build apk --debug` | **OK** (`app-debug.apk`) |
| `flutter devices` | sin Android (solo Windows, Chrome y Edge) |
| Mutation testing | **no ejecutado** (no se modificó producción) |
| Smoke test Android | **BLOCKED — no Android device/emulator available** |
