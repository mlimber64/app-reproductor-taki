# Fase 3.3 — Auditoría del ciclo de vida de una `Song` remota

Fase **solo de auditoría y documentación**: no se modificó producción, tests,
dependencias, esquema ni contratos. Todo lo propuesto queda como trabajo futuro.

Método: lectura de los flujos A–J de extremo a extremo y búsqueda en `lib/` de
`LocalSong`, `as/is LocalSong`, `localPathOf`, `contentUri`, `albumId`, `.path`,
`.folder`, `MediaStore`, `.id`, `externalId`, `int.parse/tryParse`,
`LocalArtworkReference`, `SongMatcher` y `MediaItem`. Clasificación:
`SAFE_LOCAL_SPECIFIC`, `SAFE_UNIVERSAL`, `POTENTIAL_LEAK`, `REAL_LEAK`,
`UNUSED/DEAD`.

## 1. Resumen ejecutivo

- **El núcleo es universal.** Ningún código universal (`Song`, `MusicIdentity`,
  puertos, cola, reproductor, Reproduciendo, MiniPlayer, Cola, Search, acciones,
  atribución, persistencia) lee `id`, `albumId`, `path`, `contentUri` o `folder`.
  Esos datos solo se tocan tras `is LocalSong` o en código de la fuente local.
  No hay ningún `as LocalSong`, ninguna conversión `MusicIdentity → int` ni
  parseo numérico de `externalId` fuera de la migración v2→v3 (SQL, congelada).
- **Reproducción, identidad, persistencia y artwork en pantalla: correctos** para
  `jamendo:<id>`.
- **Hay 3 `REAL_LEAK`** (todos de superficie, ninguno corrompe datos ni rompe la
  reproducción): (1) Favoritos y detalle de playlist se bloquean tras el permiso
  de música local aunque la canción sea remota; (2) las portadas de playlist
  (lista y selector) ignoran las canciones remotas; (3) la notificación /
  pantalla de bloqueo no tiene carátula remota (limitación conocida y diferida).
- **5 `POTENTIAL_LEAK`** documentados (§6).

**Resultado: READY FOR IMPLEMENTATION** (existen `REAL_LEAK`).

## 2. Ciclo de vida real

```
Jamendo API ─▶ parser (decodifica HTML) ─▶ JamendoTrack ─▶ songFromJamendoTrack
   ─▶ Song(musicIdentity=jamendo:<id>, artwork=RemoteArtworkReference)      [sin subclase]
        │
        ├─ Search ─▶ CatalogResultItem ─▶ SearchPage ── tap ─▶ PlaySongs ─▶ AudioPlayerPort.setQueue
        │                                   └── ⋯ ─▶ showSongActions ─┬─ toggleFavorite ─▶ SQLite(source, external_id)
        │                                                              ├─ addSongsToPlaylist ─▶ SQLite(source, external_id)
        │                                                              ├─ playNext / addToQueue ─▶ AudioPlayerPort
        │
        ├─ Favoritos / Playlist: SQLite ─▶ MusicIdentity ─▶ SongLookup(SourceSongLookup→JamendoSongLookup) ─▶ Song ─▶ UI ─▶ PlaySongs
        │
        └─ Reproducción: Song ─▶ JustAudioPlayerAdapter._toSource ─▶ SourcePlaybackResolver(source)
                 ─▶ JamendoPlaybackResolver ─▶ RemoteUriResource ─▶ AudioSource.uri(tag: Song)
                 ─▶ currentSong ─▶ TakiAudioHandler._toMediaItem (id = source/externalId codificados)
                 ─▶ MediaSession / notificación / lockscreen   (sin artUri remoto, §9)
        UI: Reproduciendo / MiniPlayer / Cola ─▶ song.artwork ─▶ AlbumArtworkBuilder.reference
              ─▶ ArtworkCache ─▶ HttpRemoteArtworkLoader ─▶ TakiArtwork
        Atribución: MusicIdentity ─▶ attributionProvider ─▶ AttributionLookup ─▶ ProviderAttribution?
```

## 3. Tabla por capa

| Flujo | Capa | Estado | Notas |
|---|---|---|---|
| A Search | `CatalogSearch`→`Song`→`SearchPage` | SAFE_UNIVERSAL | Usa `song.musicIdentity`, `song.artwork`; deduplica por `MusicIdentity` |
| B Acciones | `showSongActions` | SAFE_UNIVERSAL | Favorito/playlist guardan `source+external_id`, `path = localPathOf(song)` = `null` para remotas; cola recibe la `Song` |
| C Favoritos | SQLite→lookup→UI→play | SAFE_UNIVERSAL en datos; **REAL_LEAK 1**, POTENTIAL 1 en la UI/providers | |
| D Playlists | ídem | SAFE_UNIVERSAL en datos; **REAL_LEAK 1 y 2**, POTENTIAL 1 | |
| E Cola | `JustAudioPlayerAdapter` | SAFE_UNIVERSAL | `List<Song>`; `tag: song`; `ValueKey` de la Cola por identidad + n.º de repetición |
| F Player | resolver → recurso → fuente | SAFE_UNIVERSAL | Ver §5 |
| G Reproduciendo | artwork, metadata, atribución, controles | SAFE_UNIVERSAL | Sin acceso a datos locales |
| H MiniPlayer | título/artista/artwork | SAFE_UNIVERSAL | `AlbumArtworkBuilder.reference(song.artwork)` |
| I Artwork | `ArtworkReference`→caché→loader→`TakiArtwork` | SAFE_UNIVERSAL | Sin `albumId` fuera de lo local (§10) |
| J MediaSession | `MediaItem` | SAFE_UNIVERSAL en metadata; **REAL_LEAK 3** en carátula | §9 |

## 4. Hallazgos SAFE_LOCAL_SPECIFIC (correctamente acotados)

- `LocalSong` (`id`, `albumId`, `path`, `contentUri`, `folder`) y `localPathOf`.
- `LocalPlaybackResolver`: comprueba `identity.source == local` y `song is! LocalSong`
  → `UnavailableResource`; es el único lugar que lee `contentUri`.
- `LocalArtworkResolver`: `song is! LocalSong → Unavailable`; único que lee `albumId`.
- `SongMatcher`, `LocalSongLookup`, `SongFilter`, `GetSongs`, `MediaStoreSongRepository`,
  `MediaStoreArtworkRepository`: solo `LocalSong`/MediaStore. `GetFavoriteSongs` y
  `GetPlaylistSongs` aplican el matcher **solo** si `identity.source == local` y el
  lookup dijo `missing` (nunca a remotas).
- `LocalArtworkReference(albumId)` en `ArtworkCache._fetch` (rama local) y
  `ArtworkFileCache.artUriFor` (solo `LocalArtworkReference`).
- `local_music_identity.dart`: conversión `int → "id"` (sentido único, no se parsea).
- Migración `taki_database.dart` v2→v3 (`song_id INTEGER` solo en el esquema v2
  congelado; copia con `CAST` a texto como fuente `'local'`).

## 5. Hallazgos SAFE_UNIVERSAL

- **Identidad.** `MusicIdentity` es `(source, externalId)` opaca, igualdad carácter
  a carácter, sin parseo. `local:42 ≠ jamendo:42` y `jamendo:42 ≠ jamendo:0042`.
  Ningún punto posterior lo rompe: SQLite usa `PRIMARY KEY(source, external_id)`
  (texto), el id del `MediaItem` codifica ambas partes con `Uri.encodeComponent`,
  la atribución/lookup/dedupe/`ValueKey`/`Set`/`Map` usan la identidad completa.
  Los tests cubren `'0042'` (parser, mapper, wiring, seguridad).
- **Reproducción.** `Song → SourcePlaybackResolver(source) → PlaybackResource`;
  `JustAudioPlayerAdapter._toSource` hace el único `switch` sobre el recurso:
  `LocalUriResource` y `RemoteUriResource` → `AudioSource.uri`;
  `ProviderPlaybackResource` y `UnavailableResource` → fuente no reproducible
  (`taki-unplayable`), y un `PlaybackResolutionException` se convierte en
  `UnavailableResource`. Ninguna capa posterior (handler, Reproduciendo, MiniPlayer,
  Cola) necesita el proveedor.
- **Artwork en UI.** Todas las pantallas usan `AlbumArtworkBuilder.reference(song.artwork)`;
  la clave de la caché es `(reference, size)` por valor; una remota ausente o fallida
  no se memoiza como ausencia.
- **Persistencia.** Favoritos y playlists: `source` + `external_id` `TEXT`, con
  `CHECK` de no vacío; las columnas `title/artist/album/duration_ms/path` son
  respaldo (`path` solo para locales). No hay `int songId`, ni `song.id` como
  PK/FK, ni conversión de identidad a entero (las PK/FK enteras son `playlists.id`
  y `playlist_songs.id`, ajenas a la canción).

## 6. POTENTIAL_LEAK

| # | Dónde | Supuesto | Efecto en una remota | Sev. |
|---|---|---|---|---|
| P1 | `favoriteSongsProvider` (`favorites_providers.dart:49`), `playlistItemsProvider` (`playlists_providers.dart:38`), `LocalSongLookup`/`buildSongLookup` | Para resolver favoritos/playlists se **espera** `songsProvider.future` (escaneo local), y un fallo de lectura local lanza `SongLookupFailure` que tumba **todo** el lote (R-FAV-1) | Un error del escaneo de MediaStore (o su lentitud) deja sin favoritos/playlist también a las canciones remotas | Media-baja |
| P2 | `AudioPlayerPort.errors` / `PlaybackError` | Nadie consume el stream (solo puerto + adaptador) | Una remota que no se resuelve o abre (sin red, sin audio) se **salta en silencio**; tras 10 seguidas pausa sin explicación. Para locales era raro; para remotas es esperable | Media |
| P3 | `JustAudioPlayerAdapter` (`resolver ?? const LocalPlaybackResolver()`) | Por defecto asume solo local | Producción inyecta `SourcePlaybackResolver` (`main.dart`); un arranque sin ese argumento no reproduciría remotas (lanza `IdentityNotFound` → no reproducible) | Baja |
| P4 | `setQueue`/`addToQueue`/`playNext` (`_toSources`) | Resuelve **todas** las canciones a la vez | Con la caché de URL fría, N consultas a Jamendo en paralelo; la URL queda fijada al encolar (puede caducar en canciones muy posteriores) | Baja (ya anotado en D7) |
| P5 | `JamendoSongLookup`/`JamendoPlaybackResolver` | Comparan `track.id` con el `externalId` guardado por igualdad exacta | Un id guardado no canónico (que la API devuelva en otra forma) da `SongLookupFailure` en lugar de `missing` y falla el lote; los ids guardados vienen de la propia API, así que hoy no ocurre | Baja |

## 7. REAL_LEAK

### REAL_LEAK 1 — Favoritos y detalle de playlist exigen el permiso de música local

- **Archivos / símbolos:** `lib/features/library/presentation/pages/favorites_page.dart`
  (`FavoritesPage.build`, líneas 38-50) y
  `lib/features/playlists/presentation/pages/playlist_detail_page.dart`
  (cuerpo, líneas 198-211).
- **Asunción local:** si `songsProvider` es `LibraryNeedsPermission`, se muestra
  «Taki necesita acceso a tu música… se muestran a partir de las canciones de tu
  teléfono» y **no** se llega a resolver nada.
- **Efecto en una remota:** un usuario que deniega el permiso de música (o no
  quiere dar acceso) y usa solo Jamendo **no puede ver ni reproducir** sus
  favoritos ni sus playlists remotas. Las canciones remotas no necesitan ese
  permiso.
- **Severidad:** Media (bloqueo funcional en un caso real; sin pérdida de datos).
- **Propuesta:** no bloquear por permiso: resolver siempre con el `SongLookup`
  (el `LocalSongLookup` ya devuelve vacío si no hay permiso) y mostrar el aviso de
  permiso solo si hay entradas locales ocultas por ello; cambiar el texto.

### REAL_LEAK 2 — Portadas de playlist ignoran las canciones remotas

- **Archivos / símbolos:** `lib/features/playlists/presentation/providers/playlists_providers.dart`
  (`libraryArtworkProvider`, líneas 47-52), usado en `playlists_page.dart:163-166`
  y `add_to_playlist_sheet.dart:122`.
- **Asunción local:** el mapa `identidad → ArtworkReference` se construye **solo**
  con `LibraryLoaded.songs` (canciones locales); `Playlist.coverIdentities` se
  traduce con `libraryArtwork[identity]`.
- **Efecto en una remota:** una playlist cuyas primeras 4 entradas son remotas
  muestra el mosaico sin carátulas (`null`/placeholder) en la lista y en el
  selector «Añadir a una playlist», aunque el detalle (que usa `song.artwork`)
  sí las muestra. Con una playlist mixta, solo salen las locales.
- **Severidad:** Baja-media (cosmético, inconsistente entre pantallas).
- **Propuesta:** que la portada salga de las canciones resueltas (o de un mapa que
  incluya la carátula de las remotas ya vistas), no solo de la biblioteca local;
  p. ej. resolver `coverIdentities` con el `SongLookup` o cachear
  `identity → artwork` al añadir/resolver.

### REAL_LEAK 3 — Sin carátula remota en notificación / pantalla de bloqueo

- **Archivos / símbolos:** `lib/features/player/infrastructure/artwork_file_cache.dart`
  (`artUriFor`: `if (artwork is! LocalArtworkReference) return null`) y
  `taki_audio_handler.dart` (`_publishMediaItem`).
- **Asunción local:** la `artUri` de `MediaItem` exige un archivo local generado
  desde MediaStore por `albumId`.
- **Efecto en una remota:** notificación, pantalla de bloqueo y controles de
  auriculares/Bluetooth muestran título/artista/duración, pero **sin carátula**.
  No bloquea la reproducción. Está documentado en el código como «fase posterior».
- **Severidad:** Baja-media (limitación de producto conocida; no es un fallo).
- **Propuesta:** extender `ArtworkFileCache` para escribir los bytes de una
  `RemoteArtworkReference` (vía `ArtworkCache`/`RemoteArtworkLoader`, nombre de
  archivo por hash de la URL) y publicar `artUri`; mantener «sin carátula antes
  que sin notificación» ante fallos.

## 8. Dead / unused relevante

- `artworkResolverProvider` y `buildArtworkResolver` (`SourceArtworkResolver`,
  `SongArtworkResolver`): cableados en `main.dart`, **sin ningún consumidor**
  (la UI usa `song.artwork` directamente). Inofensivo; es el punto previsto para un
  resolvedor por fuente.
- `AudioPlayerPort.errors`/`PlaybackError`: producido, **no consumido** (ver P2).
- `JustAudioPlayerAdapter` default `LocalPlaybackResolver` (ver P3): rama sin uso en
  producción.

## 9. MediaSession / lockscreen

- **`MediaItem`:** `id = Uri.encodeComponent(source)/Uri.encodeComponent(externalId)`
  (opaco, único por identidad, sin MediaStore ni `contentUri`), `title`, `artist`,
  `album`, `duration` (`null` si `durationMs <= 0`). Una remota llega a
  `MediaItem`, notificación, lockscreen y controles de auriculares **sin depender**
  de `contentUri`, ID de MediaStore, `albumId` ni rutas. El audio lo resuelve el
  `PlaybackResolver` (la URI no va en el `MediaItem`).
- **Controles de sistema:** `skipToQueueItem(index)`, play/pause/siguiente/anterior
  van por índices del `AudioPlayerPort`; independientes de la fuente.
- **Limitaciones:** (a) sin `artUri` remoto (REAL_LEAK 3); (b) metadata remota
  completa pero estática (sin actualización tras reconectar); (c) al abrir una
  notificación no hay navegación específica de fuente (no aplica).
- **No validado en dispositivo** (no hay Android conectado): solo lectura del código.

## 10. Artwork remoto

`Song.artwork` (`RemoteArtworkReference`) → `AlbumArtworkBuilder.reference` →
`ArtworkCache._fetch` (rama remota → `RemoteArtworkLoader`, `HttpRemoteArtworkLoader`
cableado en `main.dart`) → `TakiArtwork`. **No necesita `albumId`.** Caminos
secundarios con `albumId`: solo `MediaStoreArtworkRepository`, la rama local de
`ArtworkCache` y `ArtworkFileCache` (locales). Salvedades: REAL_LEAK 2 (mosaicos) y
3 (lockscreen). Sin `remoteArtworkLoaderProvider` la remota se trata como ausente
(el default es `null`; `main.dart` lo sobrescribe).

## 11. Persistencia

`favorites(source, external_id, added_at, …)` con `PRIMARY KEY (source, external_id)`;
`playlist_songs(id, playlist_id, position, source, external_id, …)`. La identidad
persistida es `source + external_id` (texto, sin normalizar). No queda `int songId`
ni `song.id` usado como PK/FK universal; no hay conversión de `MusicIdentity` a
entero. Los respaldos (`title/artist/album/duration_ms`) no se muestran para
remotas (se muestra la `Song` resuelta); `path` es `null` para ellas.
Una remota que el proveedor deja de conocer queda **oculta** (no se borra).

## 12. Riesgos futuros

- Segunda fuente (D6): P1 y R-FAV-1 (un fallo de fuente tumba el lote) se agravan.
- Sin modo offline: sin red, favoritos/playlist remotos desaparecen de la vista
  (se ocultan, no se pierden) y la reproducción falla en silencio (P2).
- URLs de audio de Jamendo en memoria con TTL; caducidad en colas largas (P4).
- Etiquetas de fuente (`'local'`, `'jamendo'`) congeladas en datos persistidos:
  cambiarlas exigiría migración.
- Tests: aunque la lógica universal está cubierta con identidades remotas, no hay
  una prueba de integración que combine permiso denegado + favoritos remotos.

## 13. Recomendación de la siguiente fase

Fase de implementación «Remote lifecycle hardening», en este orden:

1. **REAL_LEAK 1 + P1:** desacoplar Favoritos/detalle de playlist del permiso y del
   escaneo local; aislar fallos por fuente (lotes parciales).
2. **P2:** consumir `PlaybackError` (aviso discreto en Reproduciendo/MiniPlayer; sin
   textos de proveedor).
3. **REAL_LEAK 2:** portadas de playlist con carátula remota.
4. **REAL_LEAK 3:** carátula remota en notificación/lockscreen.
5. P3/P4/P5 como endurecimientos menores; revisar con la segunda fuente.

Cada paso con tests y mutation testing sobre lo modificado. Pendiente transversal:
smoke test en Android (sigue sin dispositivo).
