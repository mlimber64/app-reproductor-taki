# Fase 2.3 — Recurso de reproducción

Fase 2.2 respondió «¿qué canción es?» (`MusicIdentity`). Esta fase responde «¿cómo puede reproducirse?» (`PlaybackResource`), sin cambiar el comportamiento de la app. Sin commit ni push.

## 1. Executive Summary

- Nuevo modelo de dominio **sellado de cuatro casos**: `LocalUriResource`, `RemoteUriResource`, `ProviderPlaybackResource`, `UnavailableResource`. No es «una URL».
- Nuevo puerto `PlaybackResolver` (`core/domain/ports`): `Future<PlaybackResource> resolve(Song song)`. Contrato con errores explícitos (`IdentityNotFound`, `PlaybackResolutionError`) sin filtrar HTTP/SDK/MediaStore.
- Única implementación: `LocalPlaybackResolver` (`core/domain/services`), Dart puro: lee la `contentUri` que la canción ya trae; no duplica datos ni hace E/S.
- `JustAudioPlayerAdapter` **deja de decidir qué es una canción**: pide el recurso al resolvedor (por defecto, el local) y solo lo convierte a `AudioSource`. Recursos que aún no sabe reproducir (motor propio, no disponible) o fallos de resolución producen una entrada **no reproducible** que conserva la cola y sigue el camino de errores ya existente.
- No cambiado: `Song`, `MusicIdentity`, `MediaItem.id`, `audio_service`, cola, SQLite, artwork, UI, manifiesto, dependencias.
- Validaciones: **795 tests** (759 + 36), `flutter analyze` limpio, arquitectura 6/6, build debug correcto.

**PHASE 2.3 READY FOR PERSISTENCE**

## 2. Auditoría del Player actual

Flujo (sin cambios de arquitectura):

```text
UI → PlaySongs / AddToQueue / PlayNext (player/domain/usecases)
   → AudioPlayerPort (player/domain/ports)  — trabaja con List<Song>
   → JustAudioPlayerAdapter (player/infrastructure)  — única implementación
   → just_audio (ExoPlayer)       y       TakiAudioHandler → audio_service
```

| Pregunta | Respuesta |
|---|---|
| ¿Dónde se convierte `Song` en `AudioSource`? | Solo en `JustAudioPlayerAdapter` (antes `_toSource`: `AudioSource.uri(Uri.parse(song.contentUri), tag: song)`), usado en `setQueue`, `addToQueue` y `playNext` |
| ¿Dónde se genera `MediaItem`? | `TakiAudioHandler._toMediaItem` (`id: song.contentUri`) |
| ¿Dónde se conserva `contentUri`? | En `Song` (la crea `MediaStoreSongRepository`); lo leen el adaptador de just_audio y `TakiAudioHandler`; ningún otro sitio de `lib/` |
| Contratos existentes | `AudioPlayerPort` (dominio del player), `PlaybackState`, `PlaybackError`; casos de uso del player |
| Pertenece al dominio | `AudioPlayerPort`, `PlaybackState`, `Song`, y ahora `PlaybackResource`/`PlaybackResolver` |
| Pertenece al adapter de just_audio | `AudioSource`, `ConcatenatingAudioSource`/operaciones incrementales, `ShuffleOrder`, traducción de índices, manejo de errores de carga |

## 3. Auditoría de `JustAudioPlayerAdapter`

- La cola son `Song`s (`_sources`, `_queue`), no `AudioSource` ni URL: el recurso no se guarda en la cola salvo dentro de la fuente de just_audio (con `tag: song`).
- Todas las operaciones que crean fuentes ya eran asíncronas y van serializadas por `_serialized`, así que resolver de forma asíncrona no cambia el orden ni la concurrencia.
- Los errores de carga llegan por `errorStream` → `PlaybackError` y salto a la siguiente (máx. 10 seguidos); las tests existentes cubren ese camino.

## 4. Auditoría de `MediaItem`

- `MediaItem.id = song.contentUri`. Lo usa `TakiAudioHandler` solo para comparar (`mediaItem.value?.id == item.id`) al adjuntar la carátula; nada lo convierte de vuelta en identidad.
- **Decisión: no se cambia.** Cambiarlo ahora sería una migración sin beneficio (nada depende de que sea una identidad musical) y los tests existentes lo fijan (`item.id == song.contentUri`).
- **Aplazado:** cuando `contentUri` deje de ser un campo de `Song` (o exista una fuente remota), `MediaItem.id` deberá salir de un identificador estable por entrada de cola; la candidata natural es la identidad serializada. Hay que cuidar que dos entradas de la misma canción compartan `id` (ya ocurre hoy).

## 5. Auditoría de Queue

- `PlaybackState.queue` es `List<Song>`; la cola de just_audio guarda el mismo `Song` como `tag`.
- No se duplican recursos: el `AudioSource` es derivado y se descarta con la cola.
- **No se cambió el comportamiento de la cola.** La resolución es **anticipada** (al encolar). La resolución perezosa, necesaria para URL que caducan, queda para una fase posterior (§21).

## 6. Problema actual

El adaptador de just_audio era el sitio que decidía qué representa una canción para reproducirla (`contentUri` ⇒ URI). Con fuentes remotas o con motor propio eso no vale: un recurso puede ser una URL de red que caduca, necesitar un SDK, o no existir. Faltaba un contrato en el dominio que lo describa sin atarlo a just_audio.

## 7. Decisiones de `PlaybackResource`

- **Ubicación:** `lib/core/domain/entities/playback_resource.dart` (Dart puro; sin Flutter, just_audio, audio_service, Riverpod, MediaStore, HTTP ni SDK).
- **Jerarquía sellada** (el `switch` es exhaustivo; añadir un caso obliga a revisar a los consumidores):
  - `LocalUriResource(uri)`: URI del propio dispositivo.
  - `RemoteUriResource(uri, {expiresAt})`: URI de red abrible por un reproductor de URI; `expiresAt` opcional (`null` = la fuente no informa, no «no caduca»).
  - `ProviderPlaybackResource(engine, {reference})`: lo reproduce un motor propio de la fuente; `engine` es una **etiqueta opaca** y `reference` un dato opaco opcional. Información mínima; sin SDK ni nombres de proveedores.
  - `UnavailableResource({reason})`: la canción existe pero no hay recurso reproducible.
- Las URI son `String` opacas (no `Uri`): el adaptador las interpreta.
- **HLS/DASH: sin tipo propio.** Si hay una URI que el reproductor puede abrir, es un `RemoteUriResource` y el formato lo decide el adaptador (just_audio/ExoPlayer); un tipo aparte sería una abstracción sin consumidor. (La compatibilidad real de just_audio con HLS/DASH no se verificó en esta fase.)
- Invariantes: `uri`/`engine` no vacíos ni en blanco (`ArgumentError`); sin normalización; igualdad por valor.
- No contiene `AudioSource`, `MediaItem`, `AudioPlayer`, artwork ni metadata.

## 8. Alternativas consideradas

| | A. Jerarquía sellada | B. Un tipo con discriminador interno | C. El resolvedor devuelve directamente algo reproducible |
|---|---|---|---|
| Ventajas | Exhaustividad comprobada por el compilador; cada caso con sus campos; fácil de probar | Una sola clase | El adaptador recibe «lo que reproduce» sin intermedios |
| Desventajas | Más tipos | Campos opcionales (`uri`, `engine`…) con combinaciones inválidas representables; `switch` sobre un enum sin garantía de campos | El dominio tendría que producir objetos de la tecnología (p. ej. `AudioSource`): viola «dominio sin just_audio» |
| Impacto en dominio | Cuatro tipos pequeños | Uno, con invariantes cruzadas | Dependencia del reproductor |
| Impacto en just_audio | Un `switch` exhaustivo en el adaptador | `if`/`switch` manual | Ninguno (pero acoplado) |
| Futuro con SDK | `ProviderPlaybackResource` ya prepara la frontera | Otro campo opcional más | Habría que duplicar por motor |
| Complejidad | Media-baja | Baja al principio, alta al crecer | Baja al principio, alta al acoplar |
| Testabilidad | Alta (igualdad, invariantes y `switch`) | Media | Baja (depende de la librería) |

**Elegida: A.** Razones basadas en el código de Taki: el dominio ya es Dart puro y probado con tests de invariantes (`MusicIdentity`); el adaptador ya convierte `Song` → `AudioSource` en un único punto donde un `switch` exhaustivo es natural; la investigación de proveedores (2.1/2.1B) mostró justamente cuatro naturalezas distintas (URI local, URL de red —a veces firmada y temporal—, motor del proveedor, no disponible).

## 9. Decisión sobre `PlaybackResolver`

- **Puerto** en `lib/core/domain/ports/playback_resolver.dart` (junto a `ArtworkRepository`): lo consume el player y lo implementan las fuentes.
- **Entrada: `Song`** (no solo `MusicIdentity`), para que la resolución local no duplique datos: `Song.contentUri` ya la entregó la fuente. Las decisiones deben basarse en `song.musicIdentity`; solo la fuente local lee además sus datos locales.
  - Alternativas para la entrada: **B. `MusicIdentity`** obligaría a un índice o repositorio local (la `contentUri` la construye el código nativo según el volumen y no puede reconstruirse en Dart) y a estado nuevo; **C. repositorio local** añade una segunda fuente de datos; **A. `Song`** reutiliza lo que ya hay. Se elige A.
  - Consecuencia: una futura cola persistida (solo identidades) deberá cargar primero la `Song` desde su fuente y luego resolver; el puerto no lo impide.
- **Contrato:** devuelve un `PlaybackResource` (nunca `null`); `UnavailableResource` si existe pero no hay recurso; lanza `IdentityNotFound` si la identidad no es suya y `PlaybackResolutionError` si la resolución falla. No reproduce, descarga ni obtiene artwork.

## 10. Local playback

`LocalPlaybackResolver` (const, Dart puro, sin E/S):
- Identidad de otra fuente → `IdentityNotFound`.
- `contentUri` vacía o en blanco → `UnavailableResource` (existe, sin recurso).
- Si no → `LocalUriResource(contentUri)`.

Sigue **sin conocer MediaStore** (solo lee una cadena que ya entregó). Es el comportamiento exacto de antes para canciones con URI.

## 11. Remote URL playback

Solo **modelado y probado con un resolvedor de prueba**; ninguna fuente real lo produce. El adaptador lo convierte igual que una URI local (`AudioSource.uri`). No se implementó HTTP, red ni caducidad operativa: `expiresAt` es informativo y nadie lo evalúa todavía. Permisos (`INTERNET`) y manifiesto **sin cambios**.

## 12. Provider engine boundary

`ProviderPlaybackResource(engine, reference?)` fija la **frontera**: el dominio puede decir «esto lo reproduce el motor X con este dato opaco». **No hay motor implementado.** El adaptador de just_audio no sabe manejarlo: lo trata como no reproducible (entrada conservada + error en su turno). Cuando exista un motor, el punto de integración es un segundo adaptador del puerto de reproducción (o un enrutador por `engine`), no `Song` ni `MusicIdentity`. Información mínima que se asume necesaria: `engine` opaco y `reference` opaco opcional; cualquier dato más específico lo aportará el adaptador del motor.

## 13. Unavailable resource

Existe en el modelo porque `null` no permite distinguir «no resuelto todavía», «no disponible», «error» y «no existe». Semántica:

| Situación | Representación |
|---|---|
| La canción existe pero no hay recurso reproducible | `UnavailableResource` (resultado definitivo) |
| El resolvedor no conoce la identidad | `IdentityNotFound` |
| La resolución falló (posible fallo transitorio) | `PlaybackResolutionError` (reintentable) |
| Aún no se ha resuelto | Sin resultado (la llamada no ha terminado) |

Un error transitorio **no** se convierte en `UnavailableResource`.

## 14. Error model

`PlaybackResolutionException` (sellada, `core/domain/entities/playback_resolution_exception.dart`):
- `IdentityNotFound(identity)`.
- `PlaybackResolutionError(message, {cause})`: `cause` es opaca y solo para depuración.
- Mapa conceptual de los demás casos pedidos: **PlaybackUnavailable** = `UnavailableResource` (no es excepción); **ProviderUnavailable** y **NetworkError futuro** serán nuevos subtipos de `PlaybackResolutionException` **cuando exista una fuente que los produzca**; no se crearon. Regla: quien resuelve traduce su error (HTTP, SDK, MediaStore) a estos tipos; ningún error de tecnología llega al dominio.

## 15. JustAudio adapter

`JustAudioPlayerAdapter({player, resolver})`; `resolver` por defecto `const LocalPlaybackResolver()` (las pruebas y `initPlayer` no cambian).

| Recurso | Conversión |
|---|---|
| `LocalUriResource`, `RemoteUriResource` | `AudioSource.uri(Uri.parse(uri), tag: song)` |
| `ProviderPlaybackResource`, `UnavailableResource` | `AudioSource.uri(Uri(scheme: 'taki-unplayable'), tag: song)` |
| Excepción `PlaybackResolutionException` al resolver | Igual que `UnavailableResource` |

- La entrada no reproducible **se conserva** (`state.queue` y las fuentes siguen alineadas) y al llegar su turno falla al cargar: se emite `PlaybackError` y se salta, como una canción rota de siempre (las pruebas lo verifican).
- Las excepciones que no son `PlaybackResolutionException` (errores de programación del resolvedor) **no se capturan**: se propagan.
- Límite conocido: como la resolución es anticipada, un fallo **transitorio** de resolución deja esa entrada no reproducible hasta que se vuelva a encolar; la resolución perezosa con reintento queda para después.

## 16. AudioService impact

Ninguno. `TakiAudioHandler`, `MediaItem.id` (= `contentUri`), la notificación, la pantalla de bloqueo y los controles de auriculares no se tocaron; siguen recibiendo `Song` del puerto. Los tests existentes del handler (incluido `item.id == song.contentUri`) siguen pasando.

## 17. SQLite impact

Ninguno. No se modificó el esquema, las migraciones, `song_id` ni la versión, y **no se persiste ninguna URL ni recurso**: el recurso se resuelve bajo demanda, nunca se guarda. La persistencia de `MusicIdentity` es la Fase 2.4.

## 18. Artwork separation

El recurso de reproducción es independiente del artwork: `PlaybackResource` no lleva portada y no se tocó `ArtworkRepository`, `ArtworkCache`, `AlbumArtworkBuilder`, `TakiArtwork` ni `ArtworkFileCache`. El artwork remoto sigue siendo la Fase 2.5.

## 19. Tests

36 tests nuevos, todos verdes:

- `test/core/domain/entities/playback_resource_test.dart` (18): los cuatro casos (valores, igualdad, `hashCode`, invariantes de URI/motor/referencia vacíos), que casos distintos nunca son iguales, `switch` exhaustivo y las excepciones (`IdentityNotFound`, `PlaybackResolutionError`).
- `test/core/domain/services/local_playback_resolver_test.dart` (7): identidad local → `LocalUriResource`, identidad ajena → `IdentityNotFound` (sin leer sus datos), URI vacía o en blanco → `UnavailableResource`, y que no produce recursos remotos/de motor.
- `test/features/player/infrastructure/just_audio_player_adapter_test.dart`, grupo `PlaybackResolver` (11): comportamiento por defecto idéntico al anterior; Local/Remote → `AudioSource.uri` con la canción como `tag`; la URI sale del resolvedor y no de `contentUri`; cada canción se resuelve una vez; no disponible y motor propio → entrada conservada y no reproducible, con el camino de errores de siempre; fallos de resolución no rompen la cola; mezcla en `addToQueue`/`playNext`.
- **Mutaciones comprobadas:** ignorar el resolvedor, no capturar los errores de resolución y tratar `Unavailable` como reproducible hicieron fallar tests; el archivo se restauró.
- Los 759 tests previos (incluidos los 26 previos del adaptador y los del handler) pasan sin cambios.

## 20. Changes

| Archivo | Cambio |
|---|---|
| `lib/core/domain/entities/playback_resource.dart` | **Nuevo** |
| `lib/core/domain/entities/playback_resolution_exception.dart` | **Nuevo** |
| `lib/core/domain/ports/playback_resolver.dart` | **Nuevo** |
| `lib/core/domain/services/local_playback_resolver.dart` | **Nuevo** |
| `lib/features/player/infrastructure/just_audio_player_adapter.dart` | Inyecta `PlaybackResolver` y convierte el recurso; `_toSource` pasa a async |
| Tests | 2 archivos nuevos + grupo nuevo en el test del adaptador |

Sin cambios en `Song`, `MusicIdentity`, `TakiAudioHandler`, `player_bootstrap`, SQLite, artwork, UI, manifiesto ni `pubspec.*`.

Comprobaciones: los archivos nuevos de dominio solo importan archivos de `core/domain`; sin referencias a Flutter, just_audio, audio_service, Riverpod, sqflite, HTTP ni proveedores en `lib/core/domain`; sin imports nuevos entre features (la importación `player` → `library` de `now_playing_page.dart` es una de las 6 excepciones documentadas); sin dependencias nuevas.

## 21. Deferred work

- **Resolución perezosa y con reintento** (URL que caducan, fallos transitorios).
- **Motor de reproducción de proveedor**: adaptador/enrutador por `engine`.
- **Enrutador de resolvedores por fuente** (`source`) cuando haya más de uno.
- **`MediaItem.id`** estable por entrada de cola y no basado en `contentUri`.
- **Tipos de error de red/proveedor** (nuevos subtipos de `PlaybackResolutionException`).
- **`PlaybackError`** que distinga fallo de red de archivo roto.
- **Sacar `contentUri`/`path`/`folder` de `Song`** cuando la persistencia migre.
- **Persistencia de `MusicIdentity`** (2.4) y **artwork generalizado** (2.5).
- Verificar el soporte real de just_audio para URL http(s) con cabeceras y HLS/DASH (no verificado aquí).

## 22. Criteria for Phase 2.4

1. `MusicIdentity` y `PlaybackResource` estables y probados (cumplido).
2. La persistencia guarda **identidad y respaldo de metadata, nunca recursos ni URL**.
3. Decidir la representación de `source` + `externalId` en SQLite (dos columnas o una cadena compuesta) y el plan de migración aditiva (`favorites` requiere reconstrucción por su clave primaria; `playlist_songs` admite columnas nuevas).
4. Migrar a identidades `Set<int>`/`family<bool,int>` de favoritos, `Playlist.coverSongIds` y `libraryAlbumIdsProvider`.
5. Conservar `Song.id` como id local/clave de compatibilidad hasta completar la migración.
6. Mantener 6/6 en arquitectura y `core/domain` sin dependencias de tecnología.

## Validaciones

- `flutter test`: **795 pasan**. `flutter analyze`: sin problemas. `test/architecture`: **6/6**. `flutter build apk --debug`: correcto.
- **Limitación de la validación:** el build y los tests no ejercitan la reproducción real en un dispositivo; el comportamiento de background, pantalla de bloqueo y auriculares se conserva por no haber tocado `TakiAudioHandler` ni `MediaItem`, y por las pruebas del adaptador y del handler, no por una prueba manual.

### Git status

- **Propios de 2.3:** `M lib/features/player/infrastructure/just_audio_player_adapter.dart`, `M test/features/player/infrastructure/just_audio_player_adapter_test.dart`, `?? lib/core/domain/entities/playback_resource.dart`, `?? lib/core/domain/entities/playback_resolution_exception.dart`, `?? lib/core/domain/ports/playback_resolver.dart`, `?? lib/core/domain/services/local_playback_resolver.dart`, dos tests nuevos en `test/core/domain/` y `docs/PHASE_2_3_PLAYBACK_RESOURCE.md`.
- **De la Fase 2.2:** `song.dart`, `song_reference.dart`, `music_identity.dart`, `local_music_identity.dart` y sus tests.
- **Acumulados de las fases 1.8–1.9:** UI, tema, artwork, tests asociados e informes `PHASE_1_8*`/`PHASE_1_9*`; más los informes `PHASE_2_0`, `PHASE_2_1`, `PHASE_2_1B`.
- Sin commit ni push.
