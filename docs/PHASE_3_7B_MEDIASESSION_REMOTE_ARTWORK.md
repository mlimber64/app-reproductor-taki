# Fase 3.7B — Carátula remota en notificación y pantalla de bloqueo

Implementa lo que dejó decidido `PHASE_3_7A_MEDIASESSION_REMOTE_ARTWORK_AUDIT.md`
(cierra el `REAL_LEAK 3` de la 3.3). Alcance estricto: solo la rama remota de
`ArtworkFileCache` y su cableado. No se tocó `TakiAudioHandler`, `Song`,
`ArtworkReference`, `ArtworkCache`, `RemoteArtworkLoader`/`HttpRemoteArtworkLoader`,
`ArtworkHttpClient`, `JustAudioPlayerAdapter`, Jamendo, UI, manifest ni `pubspec`.

## 1. Problema

`ArtworkFileCache.artUriFor` devolvía `null` para cualquier referencia que no fuera
`LocalArtworkReference`; el handler publicaba el `MediaItem` sin `artUri` y la
notificación/lockscreen de una canción remota salían sin carátula.

## 2. Solución

`ArtworkFileCache` acepta un `RemoteArtworkLoader?` opcional y despacha por
`song.artwork`:

| Referencia | Resultado |
|---|---|
| `LocalArtworkReference` | **rama anterior, sin cambios** (`album_<id>_<size>.jpg`, repositorio local) |
| `RemoteArtworkReference` + loader | archivo `remote_<fnv1a64(url)>.img` → `file://` |
| `RemoteArtworkReference` sin loader | `null` (compatibilidad) |
| `UnavailableArtworkReference` | `null` |

Los bytes remotos salen **solo** de `RemoteArtworkLoader.load` (el que ya valida
esquema/host, 10 s, 5 MB y firma de imagen); no hay HTTP, `url_launcher` ni
`flutter_cache_manager` nuevos.

## 3. Flujo

```
Song.artwork = RemoteArtworkReference(url)
 → TakiAudioHandler._publishMediaItem: publica el MediaItem (metadata) SIN artUri
 → ArtworkFileCache.artUriFor(song)
      · ¿existe <cache>/artwork/remote_<fnv64>.img?  sí → file.uri
      · no → RemoteArtworkLoader.load(ref, size) → bytes
             → temporal en el mismo directorio → flush → rename al final → file.uri
 → handler: si el MediaItem actual sigue con el mismo id → copyWith(artUri: file://…)
 → audio_service (archivo → artCacheFile) → MediaSession → notificación / lockscreen
```

## 4. Clave de archivo: FNV-1a 64

`remote_<16 hex>.img` sobre el UTF-8 de la URL **completa** (no `String.hashCode`,
no `externalId` ni `MusicIdentity`). Misma URL → mismo nombre (también entre
reinicios e instancias); otra query (`width=600`) → otro archivo. `.img` porque los
bytes pueden ser JPEG/PNG/GIF/WebP. Vectores de prueba conocidos (`""`, `a`,
`foobar`), UTF-8 (`é`) y relleno con ceros a la izquierda. El hex sin signo se
obtiene vía `BigInt` (`int.toUnsigned(64)` no cambia el signo en la VM).

## 5. Escritura atómica

Temporal `<final>.<n>_<µs>.tmp` en el mismo directorio → `writeAsBytes(flush)` →
`rename` al nombre final. Si falla: se borra el temporal, se devuelve `null` y no se
propaga ni se memoiza. Un archivo final nunca se ve a medias.

## 6. Deduplicación en vuelo

`Map<String, Future<Uri?>>` por URL: una segunda petición mientras la primera
descarga reutiliza el mismo `Future`; la entrada se elimina al terminar (también si
falla). Es solo de peticiones en vuelo; la caché es el archivo.

## 7. Fallbacks

| Caso | Resultado |
|---|---|
| Loader exitoso | `file://` |
| Loader devuelve `null` o bytes vacíos | `null`, sin archivo |
| Loader lanza | `null`; la siguiente llamada reintenta |
| Escritura/rename falla | `null`, sin temporales |
| Archivo borrado | se vuelve a descargar |
| `Unavailable` / sin loader | `null` |

Ningún fallo afecta a reproducción, cola, cambio de canción ni a la metadata (que
se publica antes). Sin SnackBar ni `PlaybackError`.

## 8. Cableado

`initPlayer(…, remoteArtworkLoader)` → `ArtworkFileCache(artwork, remoteArtworkLoader:)`.
En `main.dart` se crea **una** `HttpRemoteArtworkLoader(http)` y se comparte con
`initPlayer` y con el override de `remoteArtworkLoaderProvider`. Sin Jamendo en
`player`.

## 9. Archivos modificados

`lib/features/player/infrastructure/artwork_file_cache.dart`,
`lib/features/player/infrastructure/player_bootstrap.dart`, `lib/main.dart`;
tests: `artwork_file_cache_test.dart`, `taki_audio_handler_test.dart`.

## 10. Tests (+24 en el conjunto)

- `artwork_file_cache_test.dart` (27, 20 nuevos): carga exitosa (archivo, `file://`,
  bytes, sin tocar el repositorio local), reutilización sin loader, URLs distintas,
  clave = URL (no identidad), concurrencia (una carga; URLs distintas no se
  fusionan), fallo y reintento (también en vuelo), `null`/vacío, `Unavailable`, sin
  loader, archivo borrado, nombre estable entre instancias, vectores FNV, atomicidad
  (sondeo del archivo final durante una escritura de 24 MB: nunca parcial), sin
  temporales, fallo de escritura (nombre ocupado por un directorio) y rama local
  intacta con loader presente.
- `taki_audio_handler_test.dart` (+4): una remota recibe el `artUri` `file://` que
  resuelve la caché, la metadata se publica antes de esperar la carátula, `null` no
  rompe el `MediaItem`, y A→B: la carátula tardía de A nunca se publica sobre B.
- Los tests locales existentes siguen igual (el de «remota sin archivo» ahora es «sin
  loader»).

## 11. Mutation testing (19 mutantes)

**Killed 19, survived reales 0, survived esperados 0, compile-invalid 0** (rama
remota ignorada, sin dedupe, entrada en vuelo no retirada, sin reutilizar archivo,
bytes vacíos aceptados, escritura directa, sin `rename`, sin limpiar temporal, error
de escritura no propagado, fallo remoto propagado, `size` distinto, cuatro mutantes
de FNV, UTF-8↔code units, sin `padLeft`, con signo, extensión, `Unavailable`
consulta). Una primera corrida marcó todo «compile-invalid» por un error del propio
script (ruta de tests mal pasada; la línea base ya fallaba) y se repitió bien. El
test de atomicidad se ejecutó 3 veces sin variación.

## 12. Arquitectura

`ArtworkFileCache` (`features/player/infrastructure`) usa el puerto
`RemoteArtworkLoader` de `core/domain`; `player` no importa Jamendo ni
`core/artwork`; sin nuevas excepciones en `dependency_rules_test`.

## 13. Riesgos / deuda

- Sin limpieza de archivos (igual que los locales): crece con el uso de Search; el
  cache dir lo purga Android.
- Un temporal huérfano solo queda si el proceso muere a mitad de escritura.
- Si la descarga falla no hay reintento en esa canción hasta que cambie de nuevo.
- El lockscreen con carátula depende también de la versión de Android/OEM.
- Colisión FNV-64: teórica (se serviría otra carátula).

## 14. Validación

`flutter analyze`: sin issues. `flutter test`: 1614 pasan (antes 1590), 1 saltado.
Arquitectura: 13/13. `flutter build apk --debug`: OK.

**Android smoke test: BLOCKED — no Android device/emulator available.** Pendientes
en dispositivo: carátula local sigue en notificación; pista de Jamendo con carátula
en notificación y lockscreen; carrera A→B; reutilización sin red de una carátula ya
guardada.
