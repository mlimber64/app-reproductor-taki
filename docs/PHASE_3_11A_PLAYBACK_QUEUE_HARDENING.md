# Fase 3.11A — Endurecimiento de cola y resolución remota

## 1. Objetivo

Comprobar en el código **actual** dos puntos de la auditoría 3.8 y corregir solo los
que existan: (1) `addToQueue`/`playNext` comprobaban el estado de la cola fuera de la
serialización del adaptador; (2) con la caché fría, la misma identidad remota podía
resolverse varias veces a la vez. Sin cambios de UX, Jamendo (reintentos/parser),
artwork, atribución, SQLite, `MusicIdentity`, `Song`/`LocalSong`, `PlaybackResource`
ni dependencias.

## 2. Código auditado

`JustAudioPlayerAdapter` (cola, `_serialized`, `_toSources`, `setQueue`, `addToQueue`,
`playNext`, `removeFromQueue`, `moveInQueue`, `clearUpcoming`, `setShuffle`),
`PlaybackResolver`, `SourcePlaybackResolver`, `LocalPlaybackResolver`,
`JamendoPlaybackResolver`, `CachingJamendoApi`, `JamendoAudioCache`, casos de uso
`PlaySongs/AddToQueue/PlayNext` y los tests existentes del adaptador.

## 3. Conclusiones de la auditoría (A/B/C/D)

| Punto | Conclusión | Evidencia |
|---|---|---|
| `addToQueue`/`playNext` comprueban la cola **antes** de `_serialized` | **A. Confirmado** | Tests de carrera escritos primero fallaban: dos `addToQueue` sobre cola vacía dejaban `['Y']` (se perdía `X`); `setQueue` lento + `addToQueue` dejaba `['X']` en vez de `['A','B','X']`; `setQueue` lento + `playNext` dejaba `['Y']` |
| Resolución lenta dentro de operaciones de cola | **C. Ya resuelto** | `_toSources` se espera **dentro** de `_serialized`: una operación lenta retiene a las siguientes (tests de `clearUpcoming`/`removeFromQueue` tras `addToQueue`/`playNext` lentos ya pasaban) |
| `clearUpcoming` + `addToQueue`, fallos de una operación | **C. Ya resuelto** | pasaban sin cambios |
| Misma `MusicIdentity` resuelta dos veces a la vez | **A. Confirmado** | Dos `resolve` concurrentes hacían `[['123'], ['123']]` consultas a Jamendo |
| Resolución de **toda** la cola al encolar (`Future.wait`) | **B. Parcialmente mitigado** | Sigue resolviendo todas, pero ahora una consulta por **identidad** (duplicados compartidos) y las canciones en caché no consultan; **no se cambió la estrategia** |
| URL expirada / TTL | **D. Sin cambio** | El TTL de 10 min no se tocó; una URL ya fijada en una `AudioSource` sigue sin renovarse (deuda anotada) |

## 4. Cambios (producción: sí, 2 archivos)

1. `lib/features/player/infrastructure/just_audio_player_adapter.dart`
   - `setQueue` ahora es `_serialized(() => _replaceQueue(...))`; `_replaceQueue` es el
     cuerpo anterior sin serializar propia (solo se llama dentro de `_serialized`).
   - `addToQueue`: la comprobación «cola vacía» pasa **dentro** de la operación
     serializada y usa `_replaceQueue`.
   - `playNext`: la comprobación «cola vacía o sin posición» pasa **dentro** de la
     operación serializada.
   - El resto no cambia (orden, `currentIndex`, shuffle, repeat, eventos).
2. `lib/features/jamendo/domain/services/jamendo_playback_resolver.dart`
   - **Single-flight por `MusicIdentity`**: `Map<MusicIdentity, Future<PlaybackResource>>`
     de peticiones en vuelo; llamadas posteriores reutilizan el mismo `Future`; la
     entrada se retira siempre al terminar (éxito o fallo), así un fallo no se
     recuerda. La caché y su TTL no cambian; sigue siendo solo de memoria (sin URLs en
     disco ni en SQLite).

## 5. Estrategia de serialización

Una única cadena `_pending` (`_serialized`) ordena **todas** las operaciones que
cambian la cola, y las decisiones que dependen del estado (cola vacía, posición
actual) se toman **cuando la operación se ejecuta**, no cuando se pide. No hay un
lock nuevo ni se serializaron más métodos: `play`, `pause`, `seek`, `skip*` siguen
sin serializar (no cambian la cola).

## 6. Estrategia de resolución remota

`Song → SourcePlaybackResolver → JamendoPlaybackResolver → RemoteUriResource`.
Orden por llamada: **1)** acierto de caché (`JamendoAudioCache`, TTL 10 min, 500) →
sin red; **2)** resolución en vuelo de esa identidad → se comparte; **3)** consulta
`tracksByIds([id])` y, si trae audio, a la caché. Dos canciones idénticas, aunque
sean instancias distintas de `Song`, comparten la consulta porque la clave es la
identidad. Identidades distintas (`jamendo:123` / `jamendo:124`, `0123` / `123`) y
fuentes distintas (`local:123`) no comparten nada.

## 7. Cache semántica

| Evento | Comportamiento |
|---|---|
| cache hit | `RemoteUriResource` sin tocar el proveedor |
| in-flight hit | reutiliza la resolución pendiente (sin consulta nueva) |
| cache miss | una consulta al proveedor |
| fallo | llega a todos los que esperaban; la entrada en vuelo se libera; **no** se cachea |
| pista que la API ya no devuelve | `IdentityNotFound` (entrada liberada) |
| sin audio | `UnavailableResource` compartido; no se cachea |
| TTL vencido | nueva resolución |

Sin logging nuevo y sin URLs en logs.

## 8. Antes / después

| Área | Antes | Después | Evidencia |
|---|---|---|---|
| Dos `addToQueue` sobre cola vacía | Cola `[Y]` (se pierde `X`) | `[X, Y]` | `queue_concurrency_test` |
| Dos `playNext` / `addToQueue`+`playNext` sobre cola vacía | `[Y]` | `[X, Y]` | idem |
| `setQueue` lento + `addToQueue` | `[X]` | `[A, B, X]` | idem |
| `setQueue` lento + `playNext` | `[Y]` | `[A, Y, B]` | idem |
| `addToQueue` lento + `setQueue` | (ya correcto) | gana `setQueue` (posterior) | idem |
| `clearUpcoming`/`removeFromQueue` tras operación lenta | ya correcto | sin cambios | idem |
| Misma identidad concurrente | 2 consultas | **1** | `jamendo_playback_single_flight_test` |
| Misma canción repetida en una cola fría | N consultas | **1** (la cola conserva las N entradas) | idem (integración con el adaptador) |
| Identidades distintas | N consultas | N consultas (sin cambios) | idem |
| Fallo de resolución | — | libera la entrada y permite reintentar | idem |
| Estrategia `setQueue` (resolver toda la cola) | `Future.wait` | `Future.wait` (sin cambios) | adapter tests existentes |

## 9. Tests

- `test/features/player/infrastructure/queue_concurrency_test.dart` (**16 tests**):
  cola vacía con dos operaciones a la vez, `setQueue` pendiente + otra operación,
  `clearUpcoming`/`removeFromQueue` con resolución lenta, una operación lenta no deja
  pasar a las siguientes, un fallo no bloquea y compatibilidad (cola vacía, lista
  vacía, secuencias esperadas, la actual es la primera).
- `test/features/jamendo/jamendo_playback_single_flight_test.dart` (**19 tests**): misma
  identidad concurrente (2 y 5), caché tras completarse, acierto de caché, TTL,
  fallo compartido y liberación, reintento, fallo sin caché, `IdentityNotFound`, sin
  audio, identidades/fuentes/ceros distintos, la clave es la identidad, e integración
  con el adaptador.
- Los tests existentes (adaptador, resolver, handler) siguen sin cambios y pasan.

## 10. Mutation testing (manual, 12 mutantes)

- **Killed: 10** (9 a la primera + `startIndex` de `playNext` tras añadir un test):
  `addToQueue` sin rama de cola vacía, `startIndex` de `addToQueue` y de `playNext`,
  `setQueue` sin serializar, rama inalcanzable, resolver sin compartir, sin liberar la
  entrada, sin caché de lectura, sin caché de escritura y aceptando otras fuentes.
- **Survived reales: 0.** Un superviviente real inicial (`playNext` con `startIndex` 1)
  se mató añadiendo la aserción de la canción actual.
- **Survived esperados: 2** en `playNext`: quitar solo el chequeo de «cola vacía»
  (equivalente: con la cola vacía no hay posición actual) y quitar solo el de
  «sin posición» (requiere un estado «hay fuentes pero `currentIndex` es nulo» que el
  falso del reproductor no produce; es una defensa preexistente).
- **Compile-invalid: 0.**

## 11. Riesgos restantes

- **TECHNICAL DEBT — OUT OF SCOPE:** `setQueue`/`addToQueue`/`playNext` siguen
  resolviendo **toda** la cola (una consulta por identidad fría); las URLs de audio
  se fijan al encolar y pueden caducar en colas largas (TTL 10 min no cambiado).
- `_toSource` solo captura `PlaybackResolutionException`; otra excepción del
  resolver rechazaría el `Future.wait` y haría fallar la operación (preexistente).
- `removeFromQueue(index)` sigue interpretando el índice sobre la cola **cuando se
  ejecuta** (en orden), no cuando el usuario lo pidió.
- Un fallo aislado e irreproducible de un test en la primera corrida completa (`+1648
  -1`, no capturado); cuatro corridas completas posteriores pasaron.
- Sin validación Android nueva (no se hizo smoke): el cambio no altera el orden ni los
  eventos observables en el flujo normal.

## 12. Validación

`flutter analyze`: sin issues. `flutter test`: **1649 pasan, 1 saltado** (antes 1614;
+35 tests nuevos). Arquitectura: 13/13. `flutter build apk --debug`: OK. Sin
dependencias nuevas, sin cambios en Android ni en SQLite, sin secretos, sin commits ni
push. Producción modificada: **sí** (2 archivos).
