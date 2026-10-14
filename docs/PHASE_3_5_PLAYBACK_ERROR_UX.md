# Fase 3.5 — Feedback de errores de reproducción

Da un consumidor real a `PlaybackError`/`AudioPlayerPort.errors`, que se producía
sin que nadie lo leyera. Solo UX: no se tocó Song, `MusicIdentity`, resolvers,
Queue, SQLite, atribución, artwork, Jamendo, MediaSession, ni la lógica de salto
del adaptador.

## 1. Flujo anterior (auditado antes de modificar)

```
Song ─▶ SourcePlaybackResolver ─▶ PlaybackResource ─▶ AudioSource.uri(tag: song)
   (resolución fallida / UnavailableResource / ProviderPlaybackResource
    ─▶ fuente 'taki-unplayable')
 ─▶ just_audio carga ─▶ PlayerException ─▶ JustAudioPlayerAdapter._onError
      ├─ emite PlaybackError(song, index, message)  ← nadie lo consumía
      └─ si hay siguiente y < 10 fallos seguidos: salta; si no, pausa
```

Las tres vías de fallo (A: resolución antes de reproducir; B: el motor al abrir o
leer; C: el que provoca el salto) llegan por el mismo punto
(`PlayerException → _onError`) y producen **un** `PlaybackError` por intento. Otros
errores internos del adaptador no se emiten por `errors`.

## 2. Problema

Una remota que no se resuelve o no se abre (sin red, sin audio) se saltaba **en
silencio**, y tras 10 fallos seguidos el reproductor pausaba sin explicación
(POTENTIAL_LEAK P2 de la auditoría 3.3).

## 3. Solución

- `PlaybackErrorListener` (`features/player/presentation/widgets`), colocado en el
  `builder` de `MaterialApp.router` (`app/app.dart`): cubre las pestañas y las
  pantallas completas (Reproduciendo, Cola). Se suscribe **directamente** al stream
  `errors` (no a un provider, que descartaría dos eventos iguales seguidos).
- Función pura `playbackErrorMessage(error, willSkip:)` + `PlaybackErrorTexts`.
- Dominio y `core` sin UI; el evento ya lo exponía el puerto, la presentación lo
  consume. Sin dependencias ni excepciones de arquitectura nuevas.

## 4. Cuándo aparece el mensaje

| Situación | UI |
|---|---|
| Error con canción o posición y **hay siguiente** (según `state.hasNext`) | «No se pudo reproducir. Pasando a la siguiente.» |
| Error con canción o posición y **no hay siguiente** | «No se pudo reproducir esta canción» (una sola vez) |
| Error sin canción **ni** posición (interno, no ligado a un intento visible) | nada |

Sin stack traces, URLs, HTTP, nombres de excepciones ni de proveedor (el texto del
`PlaybackError.message` nunca se muestra; un test lo fija).
Límite conocido: tras 10 fallos seguidos el adaptador pausa en vez de saltar, y el
aviso sigue diciendo «Pasando a la siguiente» en ese último caso (el evento no
trae ese dato; no se cambió el adaptador).

## 5. Queue

El listener no llama a ningún caso de uso: ni `setQueue`, ni saltos, ni limpiar. El
salto (o la pausa) sigue siendo exactamente el del adaptador. Con duplicados en la
cola, cada intento fallido es un evento (dos avisos si falla dos veces) y la cola
no se deduplica.

## 6. Favoritos / Playlists

No se tocan: el aviso no escribe en SQLite, no relinka, no marca `missing` ni
cambia `MusicIdentity`. La canción sigue en favoritos y playlists.

## 7. Eventos múltiples

Cada aviso **reemplaza** al anterior (`hideCurrentSnackBar` + `showSnackBar`):
una cascada no forma cola y queda el más reciente. Un evento = un SnackBar. No hay
reintento automático.

## 8. Tests

- `test/features/player/presentation/playback_error_listener_test.dart` (13):
  mensajes (con/sin siguiente, interno sin contexto, sin detalles técnicos), un
  evento = un SnackBar, cascada, mismo evento repetido avisa de nuevo, favoritos,
  playlists, identidad y cola con duplicados intactos, `player.calls` sin cambios,
  reproducir otra canción tras el fallo, cancelación al salir.
- `test/app/playback_error_app_test.dart` (2): cableado en `TakiApp`, sobre las
  pestañas y sobre Reproduciendo (que no se cierra).
- El salto existente sigue cubierto por `just_audio_player_adapter_test.dart`
  (emite el error y salta; tras 10 fallos pausa), sin cambios.

## 9. Mutation testing (12 mutantes)

- **Killed: 9** (filtro interno `&&→||` y ausente, mensajes invertidos,
  `hasNext` fijo true/false, sin `hideCurrentSnackBar`, dedupe de eventos iguales,
  texto técnico, listener sin cablear en `TakiApp`).
- **Survived reales: 0.**
- **Survived esperados: 2**: quitar solo el guard `mounted` o solo el `cancel()`
  (defensas redundantes entre sí; quitar **ambas** sí falla el test de salida).
- **Compile-invalid: 1** (quitar el null check del mensaje); no cuenta como killed.

## 10. Android

Pendiente: no hay dispositivo/emulador; no se hizo smoke test. En particular falta
comprobar en real el aspecto del SnackBar sobre el MiniPlayer/barra inferior y un
fallo real de red con una pista de Jamendo.
