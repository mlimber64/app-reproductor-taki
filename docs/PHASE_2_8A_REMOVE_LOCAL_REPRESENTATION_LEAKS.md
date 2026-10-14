# Fase 2.8A — Remove Local Representation Leaks

Paso 1 de la estrategia de la Fase 2.7. No se creó `LocalSong`, no se movió ni
eliminó `Song.id`/`albumId`/`contentUri`, no se creó `Song.artwork` y no se
tocó SQLite, `PlaybackResource`, `ArtworkReference`/`Resolver`/`Cache`, el
`Player` ni el `AndroidManifest`.

## 1. Auditoría

Clasificación de cada uso (A = legítimo local, B = fuga, C = se queda por
compatibilidad hasta 2.8B):

| Uso | Clase | Acción |
|---|---|---|
| `taki_audio_handler.dart:141` `MediaItem.id = song.contentUri` | **B** | Corregido |
| `library_page` / `favorites_page` / `playlist_detail_page`: `song.id != currentSongId` | **B** | Corregido (identidad) |
| `queue_page.dart:44` clave de fila `(song.id, n)` | **B** | Corregido (identidad) |
| `get_songs.dart:21` desempate `a.id.compareTo(b.id)` | **A** | Se queda: orden determinista de la **biblioteca local** |
| `LocalPlaybackResolver` lee `contentUri` | **A** | Se queda: es la capa que lo necesita |
| `LocalArtworkResolver`, `ArtworkFileCache` leen `albumId` | **A** | Se quedan (fuente local) |
| `MediaStoreSongRepository` construye `Song(id…)` | **A** | Se queda |
| `SongMatcher` (`path`), `SongFilter` (`folder`/`path`) | **A** | Se quedan (política local) |
| 10 llamadas de UI `AlbumArtworkBuilder(albumId: song.albumId)` | **C** | Ver §3 |
| `playlists_providers.dart:48` `libraryAlbumIdsProvider` | **C** | Ver §3 |

Diferencias respecto a 2.7: ninguna en el inventario. La 2.7 hablaba de «13
fugas»: 4 de `id` y 1 de `contentUri` (B, corregidas aquí) y 11 de `albumId`
(10 de UI + el provider), que resultan ser **C**, no corregibles en esta fase.

## 2. Fugas eliminadas

- **«La que suena» se decide por `musicIdentity`**, no por `Song.id`
  (Library, Favoritos, Detalle de playlist). Localmente `id` ↔ identidad es 1:1,
  así que no cambia el comportamiento; con otra fuente, `id` no distinguiría
  nada (el helper `ForeignSong` tiene `id: 0`).
  `select((song) => song.valueOrNull?.musicIdentity)` no añade reconstrucciones:
  `MusicIdentity` tiene igualdad por valor.
- **Claves de fila de la cola**: `(musicIdentity, nº de aparición)`; mismas
  garantías con canciones repetidas.
- **`MediaItem.id`**: ver §3 del cambio.

## 3. Cambio de MediaItem.id

Antes: `song.contentUri` (el **recurso reproducible**, dependiente del volumen y
vacío en canciones no locales). Ahora `TakiAudioHandler.mediaIdFor(identity)`:

```
<source codificado>/<externalId codificado>      p. ej. local/42, otra/a%2Fb
```

- Identifica **la canción**; la URI sigue resolviéndose con `PlaybackResolver`
  (`PlaybackResource` no cambia).
- Cada parte va con `Uri.encodeComponent`, así `/` no puede aparecer dentro de
  una parte y `("a/b","c")` ≠ `("a","b/c")`; mayúsculas y espacios se
  conservan (igual que `MusicIdentity`).
- Es un id opaco para audio_service, **no** un formato de serialización ni se
  persiste ni se analiza. No introduce dependencias.
- La comparación existente de la carátula tardía
  (`mediaItem.value?.id == item.id`) pasa a comparar identidades de canción:
  mismo comportamiento (misma canción ↔ mismo id), y ahora también correcto
  cuando `contentUri` cambia o está vacío.
- Como antes con `contentUri`, la misma canción dos veces seguidas en la cola
  tiene el mismo id.

## 4. Impacto en artwork

Ninguno en `ArtworkResolver`/`Cache`/`Reference`. `ArtworkFileCache` sigue
recibiendo la `Song` y leyendo `albumId` (A). El adjunto de carátula a la
notificación está cubierto por tests (se adjunta a la canción actual; una
carátula tardía de la anterior se descarta).

## 5. Impacto en queue / Now Playing / playlists

- **Queue**: solo la clave de fila (§2). Reordenar, quitar y deshacer no
  cambian.
- **Now Playing**: sin cambios de código. No usaba `id` ni `contentUri`
  (solo `musicIdentity` para el corazón y `albumId` para la portada → C).
- **Playlists**: el detalle resalta por identidad. La persistencia ya era por
  `(source, external_id)`; no se tocó.

## 6. Fugas legítimas restantes

`get_songs` (desempate por `id`), `LocalPlaybackResolver` (`contentUri`),
`LocalArtworkResolver`/`ArtworkFileCache` (`albumId`), `MediaStoreSongRepository`,
`SongMatcher`, `SongFilter`.

## 7. Qué queda para 2.8B

Los 11 usos de `albumId` en UI/providers (C). No hay hoy una API que los
encapsule sin leer `albumId` en la UI: `AlbumArtworkBuilder.reference` necesita
una `ArtworkReference`, y obtenerla desde una `Song` en la UI
(`localArtworkReference(song.albumId)`) seguiría leyendo `albumId`; el
`ArtworkResolver` es asíncrono (inadecuado para pintar una fila). La API es
`Song.artwork` (síncrona), que es justo el alcance de 2.8B. Mover estos usos
ahora habría creado esa API a medias o una fuga nueva.

## 8. Riesgos

- `mediaIdFor` cambia el id publicado a audio_service: cualquier consumidor
  externo que dependiera de que fuese una URI (no hay ninguno en el repo)
  dejaría de funcionar. Se ejecuta en Android con el mismo canal; no se pudo
  validar manualmente en dispositivo en esta sesión.
- La clave del `ValueKey` de la cola pasa a contener un `MusicIdentity`
  (hash por valor, algo más caro que un `int`); el cálculo es una vez por cola
  (`_keysFor` memoiza).
- Mientras `Song.musicIdentity` se derive de `id`, las comparaciones por
  identidad y por `id` son equivalentes localmente: los tests nuevos usan
  `ForeignSong` (mismo `id`, identidades distintas) para distinguirlas.
