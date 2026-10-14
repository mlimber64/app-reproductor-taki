# Fase 2.0 — Arquitectura del catálogo musical

**Estado:** diseño conceptual. Esta fase **no cambia código, dependencias, base de datos ni UI**. Todo lo que aquí se llama «propuesto» es una hipótesis de trabajo para fases posteriores, no algo implementado. Los nombres de tipos o puertos nuevos son **provisionales**: sirven para razonar, no para fijar la API.

Las afirmaciones sobre el código actual se verificaron leyendo los archivos citados. Las que dependen de librerías o proveedores (por ejemplo, el comportamiento de `just_audio` con URLs remotas) se marcan como **no verificadas en esta fase**.

---

## 1. Executive Summary

1. Hoy Taki es local de extremo a extremo: `MediaStoreSongRepository` es el **único** sitio que crea `Song`, y `Song.id` es el `_ID` de MediaStore (un `int`). Ese `int` es la identidad de la canción en favoritos, playlists, cola, UI y matching.
2. El reproductor está **menos acoplado de lo que parece**: el único punto donde se toca el recurso reproducible es `JustAudioPlayerAdapter._toSource` (`AudioSource.uri(Uri.parse(song.contentUri), tag: song)`), más `MediaItem.id` en `TakiAudioHandler`. Aceptar un recurso remoto es, conceptualmente, cambiar ese punto.
3. El mayor riesgo arquitectónico no es el reproductor, sino la **identidad**: un `int` de MediaStore no sirve para `proveedor + id externo` (cadena), y está grabado como clave en SQLite (`favorites.song_id INTEGER PRIMARY KEY`, `playlist_songs.song_id INTEGER`).
4. El segundo es el **artwork**: todo el flujo se indexa por `albumId` entero de MediaStore (`ArtworkRepository`, `ArtworkCache`, `AlbumArtworkBuilder`, `ArtworkFileCache`). `TakiArtwork`, en cambio, ya es agnóstico del origen (recibe un `ImageProvider?`).
5. Dirección recomendada (sección 18-19): **identidad compuesta `(fuente, id externo)` como concepto del dominio; `Song` como identidad + metadata; el recurso reproducible se obtiene por un puerto resolvedor; las fuentes son adapters; un futuro `features/catalog` descubre y busca pero no reproduce ni persiste; la composición la hace `app/`**, igual que hoy con `ShowSongActions`.
6. Nada de esto exige tocar el código ahora. La fase deja identificadas las decisiones que encarecerían una migración si se aplazan (sobre todo la clave de SQLite) y las que deben esperar a la investigación de proveedores (Fase 2.1).

**Conclusión:** PHASE 2.0 READY FOR PROVIDER RESEARCH (ver §23).

---

## 2. Estado arquitectónico actual

```text
MediaStore (Kotlin, canal taki/media_store)
   ↓ MediaStoreSongRepository (features/library/infrastructure)   ← único creador de Song
   ↓ SongRepository (puerto, features/library/domain/ports)
   ↓ GetSongs + SongFilter (library/domain) → SongsNotifier (library/presentation)
   ↓ List<Song> (LibraryLoaded)
       ├─→ Library / Favorites / Playlists (resuelven referencias guardadas contra esta lista)
       └─→ PlaySongs → AudioPlayerPort (player/domain) → JustAudioPlayerAdapter → just_audio
                                                       └→ TakiAudioHandler → audio_service (notificación)
```

- Patrón real de Taki: hexagonal **por feature** (`domain`, `infrastructure`, `presentation`), más `core/domain` (Dart puro: `Song`, `SongReference`, `SongMatcher`, puerto `ArtworkRepository`) y `app/` (composición). `main.dart` es la raíz de composición y crea los adapters.
- Dependencias: `app → features → core`. Entre features solo hay **6 excepciones** documentadas (todas hacia `presentation/providers` de otra feature), comprobadas por `test/architecture/dependency_rules_test.dart`.
- Persistencia: SQLite (`taki.db`, versión 2): `favorites`, `playlists`, `playlist_songs`. La cola de reproducción **no se persiste**.
- Permisos: `READ_MEDIA_AUDIO`/`READ_EXTERNAL_STORAGE`, servicio en primer plano y notificaciones. `INTERNET` **no** está declarado en el manifiesto principal (solo en debug/profile). No hay ninguna dependencia ni código de red en `lib/` ni en Kotlin.
- `SongRepository` ya anticipa otra fuente en su documentación («Hoy: MediaStore de Android. Mañana: Navidrome, etc.»): la intención de fuentes intercambiables existe, pero solo a nivel de lista de canciones locales, no de identidad ni de reproducción.

---

## 3. Auditoría de Song

`core/domain/entities/song.dart`, `Equatable`, 10 campos:

| Campo | Tipo | Naturaleza |
|---|---|---|
| `id` | `int` | **Local**: `_ID` de MediaStore. Es la identidad usada en todo Taki |
| `title`, `artist?`, `album?`, `durationMs` | texto / `int` | Metadata: aplica a cualquier fuente |
| `albumId` | `int?` | **Local**: `ALBUM_ID` de MediaStore; clave de todo el flujo de artwork |
| `path` | `String` | **Local**: ruta de archivo «solo informativa»; también es criterio de matching y respaldo persistido |
| `contentUri` | `String` | **Local en origen, genérico en uso**: es lo que recibe el reproductor (`Uri.parse`) |
| `dateAdded` | `DateTime?` | **Local**: fecha de MediaStore |
| `folder` | `String` | **Local**: lo usa `SongFilter` (política de biblioteca) |

Respuestas a las preguntas de la fase:

1. **Dónde se crea:** solo en `MediaStoreSongRepository._toSong` (`lib/`). En `test/` hay 4 construcciones, todas en helpers o pruebas de `Song`/`SongFilter` (`library_fakes.dart`, `widget_test_utils.dart`, `song_test.dart`, `song_filter_test.dart`). Cambiar la forma de `Song` tiene un coste de tests bajo.
2. **Quién lo persiste:** nadie persiste `Song` como tal. Favoritos y playlists persisten una **referencia de respaldo** (`song_id` + título, artista, álbum, duración, ruta) mediante `FavoriteEntry` y `PlaylistEntry`.
3. **Quién lo identifica:** `Song.id` (`int`). Lo usan `favorites_usecases`, `playlist_usecases`, `SongMatcher`, los repositorios SQLite, `isFavoriteProvider` (`Provider.family<bool, int>`), `Set<int>` de favoritos y varias páginas (`library_page`, `favorites_page`, `queue_page`, `now_playing_page`, `playlist_detail_page`, `song_actions_sheet`).
4. **Quién lo reproduce:** `AudioPlayerPort` (recibe `List<Song>`), implementado por `JustAudioPlayerAdapter`.
5. **Dependencias de rutas/URIs locales:** `contentUri` (2 consumidores: adaptador de audio y `TakiAudioHandler`), `path` (matching, filtro, respaldo en SQLite), `folder` (filtro), `albumId` (12 archivos).
6. **Supuestos de MediaStore:** id entero, `albumId` entero, la ruta como criterio de reencuentro, la carpeta como criterio de filtrado, `<unknown>` como valor nulo (limpiado en el adapter), permiso de audio como condición de la biblioteca.
7. **Qué funcionaría con una canción remota tal cual:** la cola y el estado (`PlaybackState`, `List<Song>`), los casos de uso del reproductor, `TakiSongTile`, `TakiMiniPlayer`, el menú de acciones; y, en principio, un `contentUri` `http(s)` en `AudioSource.uri` (**no verificado en esta fase**; `just_audio` admite URIs de red según su API documentada).
8. **Qué NO debería tocarse todavía:** la forma de `Song` y `SongReference`, el esquema SQLite, `AudioPlayerPort`, `ArtworkRepository`/`ArtworkCache` y la UI (alcance de la fase, y faltan datos de proveedores para decidir el detalle).

---

## 4. Auditoría de SongReference

`core/domain/entities/song_reference.dart` es una interfaz con `songId (int)`, `title?`, `artist?`, `durationMs?`, `path?`. La implementan `FavoriteEntry` (favoritos) y `PlaylistEntry` (playlists).

- **Propósito real:** «reencontrar» una canción local cuyo `_ID` cambió (reescaneo, reinstalación). Por eso guarda una copia de metadata.
- **Suficiencia para remoto:** no basta. Falta la **fuente** y el identificador es un `int`. Los campos `title/artist/durationMs` sirven como respaldo también para remoto; `path` es local por definición.
- Hoy mezcla dos cosas: la **identidad** guardada (`songId`) y el **respaldo** para re-matching. Con fuentes remotas conviene separarlas conceptualmente: una identidad estable (exacta) y un respaldo (heurístico, solo para fuentes cuyos ids no son estables).

## 5. Auditoría de SongMatcher

`core/domain/services/song_matcher.dart`: construye índices sobre la **biblioteca local** y resuelve una referencia por id → ruta → (título + artista) con duración ±1 s.

- Es una **política de la fuente local**, no una regla universal: existe porque los ids de MediaStore no son estables.
- Con una fuente remota cuyo id externo es estable, el matching es una **igualdad exacta** `(fuente, id externo)`; aplicar id/ruta/título+artista sería innecesario y, peor, podría fusionar por error canciones distintas con el mismo título.
- Lo usan `GetFavoriteSongs` y `GetPlaylistSongs`, que además «reparan» la referencia (`relink`) al reencontrarla con otro id. Ese mecanismo es válido solo para la fuente local.
- Conclusión: debe seguir siendo la estrategia **de la fuente local**. Conceptualmente cada fuente aporta su propio modo de reencontrar una referencia; el dominio no debe asumir uno único.

---

## 6. Flujo actual de reproducción

1. UI (p. ej. `library_page`) → `playSongsProvider` → `PlaySongs(songs, index)` → `AudioPlayerPort.setQueue(List<Song>)`.
2. `JustAudioPlayerAdapter`: `_toSource(song) = AudioSource.uri(Uri.parse(song.contentUri), tag: song)`; usa `setAudioSources`, `addAudioSources`, `insertAudioSources`, `moveAudioSource`, `removeAudioSourceRange` para editar la cola; `ShuffleOrder` propio (`queue_shuffle_order.dart`).
3. Errores: si una canción falla, el adaptador emite `PlaybackError` y salta a la siguiente (con un máximo de saltos consecutivos); `_consecutiveErrors` se reinicia al llegar a `ready`.
4. `TakiAudioHandler` (audio_service): publica `playbackState` y `MediaItem`; `MediaItem.id = song.contentUri`; la carátula llega después con `ArtworkFileCache.artUriFor(song)`.
5. **Acoplamiento local del reproductor:** únicamente `_toSource` y `MediaItem.id`. No hay `FileAudioSource`, ni rutas de archivo, ni `ContentResolver` en Dart. `PlaybackState`, `AudioPlayerPort` y los casos de uso operan con `Song`, sin saber de MediaStore.
6. **Lo que el modelo actual no cubre para remoto** (conceptual): recursos que caducan o requieren cabeceras/credenciales, resolución asíncrona antes de reproducir, errores de red distintos a «archivo borrado», estado de buffering prolongado, y reproducción sin conexión.

## 7. Flujo actual de artwork

`ArtworkRepository (porta, int albumId) → ArtworkCache (bytes, LRU, clave (albumId, px)) → AlbumArtworkBuilder → ResizeImage(MemoryImage) → TakiArtwork`. `ArtworkFileCache` (player, 512 px, archivo) atiende la notificación y la pantalla de bloqueo y llama directamente al repositorio.

- `TakiArtwork` recibe un `ImageProvider?` y no sabe de dónde viene (punto fuerte para remoto).
- Todo lo anterior a `TakiArtwork` está indexado por `albumId` entero de MediaStore; `MediaStoreArtworkRepository` lee miniaturas por un canal nativo; `SongsNotifier.rescan` vacía `ArtworkCache`.

## 8. Dependencias actuales de MediaStore

| Dependencia | Dónde | Naturaleza |
|---|---|---|
| Canal nativo `taki/media_store` (Kotlin) | `media_store_channel.dart`, `MediaStoreChannel.kt` | Adapter; correcto que sea local |
| `MediaStoreSongRepository`, `MediaStoreArtworkRepository` | `features/library/infrastructure` | Adapters; correctos |
| `Song.id`, `albumId`, `path`, `contentUri`, `folder`, `dateAdded` | `core/domain/entities/song.dart` | **Datos locales dentro de una entidad compartida** |
| `SongMatcher` (paso por ruta) | `core/domain/services` | Política local en `core` |
| `SongFilter` (carpeta, duración mínima, ruta) | `library/domain/services` | Política de biblioteca local; su sitio (library) es correcto |
| Respaldo `path` y `song_id INTEGER` | SQLite (favorites, playlist_songs) | **Identidad local grabada en persistencia** |
| `ArtworkRepository(int albumId)` | `core/domain/ports` | Puerto con clave local |
| `ArtworkFileCache(albumId)` | `player/infrastructure` | Clave local |
| Permisos de audio | `MediaPermissionPort`, `SongsNotifier` | Propios de la fuente local |

---

## 9. Problemas arquitectónicos para música remota

| # | Problema | Gravedad para remoto | Dónde |
|---|---|---|---|
| P1 | Identidad = `int` de MediaStore; un id externo es cadena y depende del proveedor | **Alta** (afecta a persistencia) | `Song.id`, `SongReference.songId`, favoritos, playlists, `isFavoriteProvider`, `Set<int>` |
| P2 | `Song` mezcla metadata con datos locales (`path`, `folder`, `albumId`, `dateAdded`, `contentUri`) | Media | `song.dart` |
| P3 | SQLite clave primaria `song_id INTEGER` en `favorites` y columna `INTEGER NOT NULL` en `playlist_songs` | **Alta** (migración costosa si se aplaza) | `taki_database.dart` |
| P4 | Resolución de referencias guardadas solo contra `List<Song>` de la biblioteca local; lo ausente se oculta | Alta | `GetFavoriteSongs`, `GetPlaylistSongs`, `SongMatcher` |
| P5 | Reproductor asume que el recurso es un URI estático conocido al encolar | Media | `_toSource` |
| P6 | Artwork indexado por `albumId` entero | Media | `ArtworkRepository`, `ArtworkCache`, `AlbumArtworkBuilder`, `ArtworkFileCache` |
| P7 | Portadas de playlist se derivan de ids de canción → `libraryAlbumIdsProvider` (mapa de la biblioteca local) | Media | `playlists_providers.dart`, `Playlist.coverSongIds` (`List<int>`) |
| P8 | Un único estado «no disponible» (ausente de la biblioteca) | Baja-media | `PlaylistItem`, `TakiSongTile.available` |
| P9 | Privacidad y permisos: el README declara «sin backend, sin cuentas… sin telemetría»; `INTERNET` no está en el manifiesto principal | Decisión de producto | README, `AndroidManifest.xml` |

Lo que **no** es un problema: `PlaybackState`, `AudioPlayerPort` y los casos de uso del reproductor (operan con `Song`); `TakiArtwork` (agnóstico); los componentes `Taki*`; `SongRepository` como contrato de fuente local.

---

## 10. Conceptos de dominio propuestos

Análisis de si cada concepto hace falta (sin crear tipos todavía):

| Concepto | Hoy | ¿Hace falta distinguirlo? |
|---|---|---|
| **Canción (metadata)** | `Song` | Sí: es lo que muestra la UI (título, artista, álbum, duración) |
| **Identidad estable** | `Song.id` (int) | **Sí, y es el cambio más importante**: debe ser independiente de URL y de MediaStore |
| **Fuente** | implícita («MediaStore») | Sí: sin ella no se puede identificar ni resolver. Conjunto abierto (local, remoto, futuras), no un enum cerrado |
| **Referencia de canción** | `SongReference` | Sí, pero redefinida: identidad (exacta) + respaldo opcional (heurístico) |
| **Recurso reproducible** | `contentUri` dentro de `Song` | Sí: algo que se **resuelve** desde la identidad en el momento de reproducir (puede ser asíncrono, caducar, necesitar cabeceras) |
| **Artwork** | `albumId` + `ArtworkRepository` | Sí: referencia de artwork distinta de la identidad de la canción |
| **Metadata** | campos de `Song` | No como clase aparte; es parte de `Song` |

- `LOCAL` / `REMOTE` / `FUTURE`: **no** deben ser un enum que el dominio enumere (cada fuente nueva obligaría a tocarlo). La fuente es una **etiqueta opaca** (identificador de fuente) cuyo significado lo dan los adapters registrados. «Local» es una fuente más.
- Un proveedor remoto concreto nunca debe aparecer en el dominio (ni su nombre, ni sus DTOs, ni su URL base).

## 11. Identidad de canciones

Requisitos: soportar `MediaStore ID` (local, **no estable**) y `proveedor + id externo` (remoto, **normalmente estable**), sin que la identidad dependa de una URL.

Alternativas:

| | A. Mantener `int id` y añadir columna de fuente | B. Clave de texto única `fuente:idExterno` | C. Valor compuesto `(fuente, idExterno: String)` |
|---|---|---|---|
| Ventajas | Cambio mínimo | Una sola columna/clave; igualdad y `Set` triviales | Claridad de tipos; igualdad estructural; índices por fuente |
| Desventajas | **Falla**: los ids externos son cadenas (p. ej. no caben en `int`) | Hay que construir/parsear; fácil filtrar mal; mezcla dos conceptos en una cadena | Dos campos por todo el código y dos columnas |
| Impacto actual | Bajo | Medio | Medio |
| Impacto futuro | Alto (rehacer) | Bajo-medio | Bajo |
| Hexagonal | Fuga de identidad local | Correcto | Correcto |
| Riesgo de migración | Alto | Medio | Medio (una migración bien planificada) |

**Recomendación:** C como **concepto del dominio** (valor con igualdad estructural, sin URL). La representación persistida (dos columnas o una cadena compuesta) es un detalle de la fase de persistencia y puede elegirse entonces sin cambiar el concepto.

Consecuencias por ámbito:

- **Igualdad:** por valor `(fuente, idExterno)`. Hoy `Song` es `Equatable` por todos sus campos; con identidad explícita conviene que la comparación «es la misma canción» use la identidad, no todos los campos (p. ej. metadata actualizada).
- **Favoritos:** `Set<int>` / `Provider.family<bool, int>` pasan a depender de la identidad (conceptual).
- **Playlists:** `songId` de `PlaylistEntry` pasa a ser referencia `(fuente, idExterno)`; se mantiene el `id` de la entrada (la misma canción puede repetirse).
- **Cola:** ya opera con objetos `Song`; solo cambia cómo se compara «la actual».
- **Deduplicación:** el mismo tema local y remoto son identidades **distintas**. Fusionarlos (p. ej. por título + artista + duración) es una política de producto **aplazada**; no debe ocurrir implícitamente.
- **Matching:** por fuente (local: id → ruta → título+artista+duración; remoto: igualdad exacta).
- **Persistencia futura:** ver §16.

---

## 12. Local vs Remote

Evitar un «God Model» del tipo `Song { mediaStoreId, spotifyId, youtubeId, apiUrl, … }`: el dominio no enumera fuentes. Responsabilidades:

| Pieza | Responsabilidad | Dónde (hipótesis) |
|---|---|---|
| Identidad, metadata, referencia | Qué es una canción | `core/domain` |
| Contrato «dame el recurso reproducible de esta canción» | Puerto resolvedor (por fuente) | `core/domain/ports` |
| Fuente local | MediaStore: listar, resolver recurso (`content://`), artwork local, política de reencuentro | `features/library/infrastructure` (ya existe en parte) |
| Fuente remota | Cliente, DTOs, mapeo a dominio, resolución de recurso, artwork remoto | adapter de proveedor, dentro del módulo de catálogo (§17) |
| Orquestación (qué fuente usar para qué identidad) | Registro de fuentes | `app/` (composición) |

Regla: **el dominio depende de contratos; las fuentes dependen del dominio**, nunca al revés.

## 13. Modelo de fuente / recurso reproducible

Pregunta: ¿`Song` debe contener la URL?

| | A. `Song` contiene todo lo reproducible | B. `Song` = identidad + metadata; otra abstracción = recurso | C. `SongReference` + puerto que resuelve después | D. Híbrido B+C |
|---|---|---|---|---|
| Descripción | Añadir campos de recurso (URL, cabeceras, caducidad) a `Song` | `Song` sin recurso; un tipo aparte representa el recurso | Solo se guarda/pasa la referencia; se resuelve siempre bajo demanda | `Song` (identidad+metadata) se usa en UI/cola; el recurso lo obtiene un **resolvedor** a partir de la identidad cuando hace falta reproducir |
| Ventajas | Sin cambios de flujo | Separa identidad de recurso | Mínima persistencia; recursos siempre frescos | Combina: UI sigue con `Song`; persistencia con referencia; recurso fresco |
| Desventajas | `Song` se vuelve un modelo de todo (God Model); URLs que caducan dentro de una entidad «de identidad» | Hay que decidir quién y cuándo produce el recurso | La UI no puede pintar sin resolver metadata; obliga a cachear metadata aparte | Dos conceptos más (identidad de fuente y resolvedor); más piezas |
| Impacto actual | Nulo hoy | Medio | Alto | Medio, **localizado en `_toSource`** |
| Futuro | Frágil (caducidad, credenciales) | Bueno | Bueno | Bueno |
| Hexagonal | Mezcla | Correcto | Correcto | Correcto |
| Riesgo de migración | Bajo ahora, alto después | Medio | Alto | Medio |

Evidencia del código que inclina la decisión:
- El único consumo del recurso está aislado en `_toSource` y `MediaItem.id` → introducir un resolvedor es un cambio **local y reversible**.
- `Song.contentUri` ya se comporta como «recurso»; `path` está declarado como «solo informativa» en la propia entidad: hay una intención previa de separar metadata y recurso.
- La cola contiene `Song` (con `tag: song`), y la UI usa `Song` en todas partes: sacar la metadata de `Song` obligaría a cambiar mucho más código que aislar el recurso.

**Recomendación:** D (B + C): `Song` conserva identidad + metadata y deja de ser la casa del recurso; el recurso lo produce un puerto resolvedor por fuente. Los campos puramente locales (`path`, `folder`, `dateAdded`, y en su momento `albumId`/`contentUri`) son candidatos a salir de la entidad compartida, **de forma gradual y sin romper** (primero aditivo, después retirada; ver §22).

Preguntas abiertas de este modelo (se aplazan a 2.1, dependen de proveedores): resolución **anticipada** (al encolar) o **perezosa** (al reproducir); caducidad y renovación; cabeceras o credenciales por recurso; si `just_audio` necesita una fuente personalizada para recursos que requieran cabeceras dinámicas (no verificado).

---

## 14. Frontera Library / Catalog / Player / Playlists

Hoy: `library` (fuente local + favoritos), `player`, `playlists`, `settings`. Las dependencias entre features son 6 excepciones hacia `presentation/providers`.

**`features/catalog` (futuro) — tiene sentido**, con esta responsabilidad:

| Hace | No hace |
|---|---|
| Descubrir, buscar, categorías (más adelante) | Reproducir audio |
| Metadata y artwork remotos; identificadores remotos | Gestionar MediaStore ni permisos locales |
| Exponer resultados como objetos del dominio (`Song`/identidad) | Controlar `just_audio` ni la cola |
| Su propio puerto de repositorio de catálogo y adapters de proveedor | Guardar favoritos ni playlists |

Dependencias deseadas y prohibidas:

| Dependencia | Decisión |
|---|---|
| `catalog → core` | Permitida |
| `catalog → player` | **Evitar** (no hace falta): la acción «reproducir» se inyecta por callback desde `app/` |
| `catalog → playlists` / `favorites` | **Evitar**: «añadir a playlist» y «favorito» también llegan como acciones compuestas en `app/` |
| `library → catalog` | **Evitar**: la biblioteca local no debe conocer el catálogo |
| `player → catalog` | **Evitar**: el reproductor recibe `Song` y un resolvedor por puerto en `core` |
| `playlists/favorites → catalog` | **Evitar**: dependen de identidades y de un resolvedor en `core`, no de una feature |

Mecanismo: Taki ya tiene el patrón exacto. `ShowSongActions` es un `typedef` en `core/widgets/song_actions.dart` que **implementa `app/`** (`song_actions_sheet.dart`) y se pasa a las páginas por el router. Un catálogo recibiría del mismo modo `onPlay`, `onAddToQueue`, `onAddToPlaylist`, `onToggleFavorite`. Así no se añade ninguna excepción nueva al test de arquitectura.

Piezas compartidas que sí deben vivir en `core` (no en una feature) porque las usan varias: identidad/referencia de canción, el resolvedor de recurso reproducible y, cuando llegue, el puerto de artwork generalizado.

Nota sobre `library`: además de la fuente local, hoy aloja los **favoritos** (`FavoritesRepository`). Los favoritos de canciones remotas obligarían a decidir si «favoritos» sigue siendo parte de `library` o pasa a un módulo propio; queda aplazado (§20).

---

## 15. Evolución de Artwork

Estado: `ArtworkRepository.getAlbumArtwork(int albumId, {size})` devuelve bytes; `ArtworkCache` los guarda por `(albumId, px)`; `AlbumArtworkBuilder(albumId)` produce el `ImageProvider`; `TakiArtwork` dibuja.

Alternativas para artwork remoto (sin implementar nada):

| | A. Generalizar la clave del puerto a una referencia de artwork `(fuente, id)` | B. Puerto/flujo paralelo para remoto | C. Mantener el puerto local; el artwork remoto llega como `ImageProvider` ya construido por el catálogo |
|---|---|---|---|
| Ventajas | Un solo flujo y una sola caché | No toca lo local | Cambio mínimo; `TakiArtwork` ya lo admite |
| Desventajas | Cambia `ArtworkRepository`, `ArtworkCache`, `AlbumArtworkBuilder`, `ArtworkFileCache` y sus tests | Duplica resolución y cachés (riesgo de volver a tener resolvers paralelos, lo que la Fase 1.8 eliminó) | Pierde `ResizeImage` acotado y la caché de bytes unificada; `ArtworkFileCache` seguiría sin cubrir remoto |
| Impacto | Alto | Medio | Bajo |
| Hexagonal | Correcto | Correcto pero redundante | Mezcla presentación con origen |
| Riesgo | Medio (tocar artwork recién consolidado) | Medio-alto (deuda) | Bajo a corto, alto a largo |

**Dirección recomendada (provisional):** A a medio plazo, cuando se conozca qué entrega un proveedor (URL, bytes, varios tamaños); mientras tanto C es un atajo aceptable para una primera integración, marcado como deuda. `ArtworkFileCache` (lockscreen) necesita tratamiento propio: la notificación admite URIs remotas, pero si se exige archivo local o política offline es una decisión de 2.1/2.x. **No se modifica nada en `ArtworkRepository` ni `ArtworkCache` en esta fase.**

Hallazgo relacionado: `Playlist.coverSongIds` y `libraryAlbumIdsProvider` asumen que cada canción se resuelve a un `albumId` por la biblioteca local; una playlist con canciones remotas no tendría portada con este mecanismo (P7).

---

## 16. Persistencia futura

Esquema actual (v2, onUpgrade aditivo «nunca tocan lo existente»):

- `favorites(song_id INTEGER PRIMARY KEY, added_at, title, artist, album, duration_ms, path)`
- `playlists(id, name, created_at, updated_at)`
- `playlist_songs(id, playlist_id FK CASCADE, position, song_id INTEGER NOT NULL, title, artist, album, duration_ms, path)`

Qué pasa con una playlist mixta (local + remota) y con favoritos:

| Aspecto | Situación actual | Con fuentes remotas |
|---|---|---|
| Identidad en favoritos | PK `song_id` entero: **imposible** guardar un id externo de texto ni distinguir fuente | Requiere una clave `(fuente, id externo)`; cambiar la PK de SQLite exige **reconstruir la tabla** (crear, copiar, renombrar) |
| Identidad en playlists | Columna entera; las entradas ya tienen `id` propio | Añadir columnas es aditivo; migrar filas existentes a fuente `local` y `idExterno = song_id` |
| Duplicados | La misma canción puede repetirse (entradas con `id`) | Igual; la clave de favoritos deja de ser solo `song_id` |
| Eliminación | Borrar playlist (CASCADE) o entrada | Sin cambios |
| Reorden | `position` contigua, `move`, `reinsertEntry` | Sin cambios (independiente de la fuente) |
| Reencuentro | `SongMatcher` contra la biblioteca local; ausentes se ocultan sin borrar | Cada fuente reencuentra a su manera; remoto = igualdad exacta; ausentes remotos: «no disponible/sin conexión» |
| Respaldo (`title/artist/…/path`) | Para re-matching local | `path` sin sentido en remoto (nulo); el resto sirve para mostrar sin conexión |
| Resumen de playlist | `songCount`, `totalDurationMs`, `coverSongIds` (enteros) | `coverSongIds` debe poder referir identidades de cualquier fuente |

**Decisiones que encarecerían la migración si se aplazan sin atención:**
1. Añadir más código que dependa de `int songId` (nuevos providers, nuevas tablas, nuevas pantallas) — cada uso nuevo aumenta el coste del cambio de identidad.
2. Añadir una tercera tabla con `song_id INTEGER` (p. ej. historial, cola persistida, «recientes») antes de fijar la identidad compuesta.
3. Persistir URLs de recurso: nunca; se guarda identidad + respaldo, no el recurso (caduca, puede ser credencial).

Migración hipotética (no ejecutada): v3 aditiva (`source`, `external_id` en `playlist_songs`; tabla nueva para favoritos con PK compuesta y copia de la antigua con `source='local'`), conservando la columna antigua hasta confirmar. Detalles de esquema → fase de persistencia.

---

## 17. Arquitectura Hexagonal propuesta

Adaptada al patrón real de Taki (la infraestructura vive **por feature**, no en una carpeta global). La hipótesis del enunciado (`infrastructure/provider_x` global) se ajusta así:

```text
core/domain                        (Dart puro; sin HTTP/JSON/SDK/MediaStore/just_audio)
  entities/   Song (identidad + metadata) ; identidad de canción (concepto)
  ports/      ArtworkRepository (existente) ; resolvedor de recurso reproducible (nuevo, conceptual)
  services/   (la política de reencuentro pertenece a cada fuente)

features/library                   fuente LOCAL
  domain/     SongRepository, SongFilter, favoritos            (existente)
  infrastructure/  MediaStoreSongRepository, adapter de recurso local, artwork local

features/catalog   (futuro)        fuente(s) REMOTA(S)
  domain/     puerto de repositorio de catálogo (búsqueda, detalle, metadata)
  infrastructure/<proveedor>/   cliente, DTOs, mapper a dominio, resolvedor de recurso, artwork
  presentation/  páginas y providers propios (descubrir, buscar)

features/player                    reproduce; recibe Song + resolvedor por puerto (core)
features/playlists                 guarda referencias (identidad), no recursos
app/                               compone: registra fuentes, conecta acciones (onPlay, onAddToPlaylist…)
```

Reglas (se mantienen las del test de arquitectura actual):
- El dominio no conoce HTTP, Dio, REST/GraphQL, JSON, APIs concretas, MediaStore, `just_audio` ni SDKs.
- Las fuentes remotas solo aparecen en `features/catalog/infrastructure/<proveedor>` y se inyectan desde `main.dart`/`app/`.
- `catalog` depende de `core`; no importa `player`, `playlists` ni `library`.
- Los DTOs de proveedor **no** cruzan la frontera: el mapper entrega objetos del dominio.
- Una nueva feature requeriría ajustar `dependency_rules_test.dart` solo si introdujera importaciones entre features; con el mecanismo de callbacks de `app/` no hace falta ninguna excepción.

---

## 18. Alternativas consideradas

Resumen de las decisiones grandes (detalle en §11, §13, §14, §15):

| Decisión | Opciones | Elegida |
|---|---|---|
| Identidad de canción | A `int`+fuente · B cadena `fuente:id` · C valor compuesto | **C** (concepto); representación persistida aplazada |
| Modelo de recurso | A `Song` todo-en-uno · B identidad/recurso · C solo referencia · D B+C | **D** |
| Dónde viven las fuentes | Fuentes dentro de `library` · módulo `catalog` separado · fuentes en `core` | **Fuente local en `library`; fuentes remotas en un `catalog` futuro** (la opción «dentro de library» acoplaría la biblioteca local a proveedores y crearía `library → catalog`) |
| Coordinación entre features | Importes entre features · eventos/bus · callbacks compuestos en `app/` | **Callbacks en `app/`** (patrón ya existente y sin excepciones nuevas) |
| Artwork remoto | A clave generalizada · B flujo paralelo · C `ImageProvider` ya armado | **A** a medio plazo; **C** como atajo temporal, marcado como deuda |
| Matching | Único y global · por fuente | **Por fuente** |

## 19. Decisiones tomadas

1. La identidad de una canción es un concepto **independiente de la URL y de MediaStore**, compuesto por fuente e identificador externo.
2. «Fuente» es una etiqueta opaca y abierta; el dominio no enumera proveedores. «Local» es una fuente más.
3. `Song` representa identidad + metadata; el recurso reproducible se resuelve por un **puerto** (resolvedor) y no pertenece a la entidad.
4. La política de reencuentro de referencias (`SongMatcher` actual) pertenece a la fuente local; las remotas usan igualdad exacta.
5. Un futuro `features/catalog` existirá como módulo **separado** de `library`, con dependencias solo hacia `core`; la composición con reproducción, playlists y favoritos la hace `app/` mediante callbacks.
6. No se añade ninguna dependencia de red ni código de proveedor hasta que termine la investigación (Fase 2.1).
7. No se modifica nada del código existente en esta fase.

## 20. Decisiones deliberadamente aplazadas

| Tema | Por qué se aplaza | Fase |
|---|---|---|
| Elección de proveedor(es) | Requiere investigación de APIs, licencias y derechos de reproducción | 2.1 |
| REST vs GraphQL; `http` vs `dio` | Dependen del proveedor | 2.1 / posterior |
| Autenticación / OAuth, tokens y almacenamiento seguro | Dependen del proveedor y de políticas de privacidad | 2.1 |
| Protocolo y calidad de streaming, CDN, backend propio | Dependen del proveedor | 2.1 |
| Resolución anticipada vs perezosa del recurso; caducidad/renovación; cabeceras dinámicas en `just_audio` | Dependen del proveedor; parte no verificada | 2.1 → 2.3 |
| Representación persistida de la identidad (dos columnas vs cadena) y plan exacto de migración de SQLite | Detalle de persistencia | 2.4 |
| Política de deduplicación entre local y remoto | Decisión de producto | posterior |
| Dónde viven los favoritos (¿siguen en `library`?) | Depende del alcance final | posterior |
| Offline / descargas / caché de audio | Producto y licencias | posterior |
| Artwork remoto: forma final y `ArtworkFileCache` | Depende de lo que entregue el proveedor | 2.5 |
| Cambios de README y de permisos (`INTERNET`, política de privacidad) | Decisión de producto | cuando se añada la primera fuente real |
| UI del catálogo y navegación | Fuera de alcance | posterior |

## 21. Riesgos

| Riesgo | Efecto | Mitigación |
|---|---|---|
| Seguir añadiendo código con `int songId` | Migración de identidad más cara | Fijar el concepto de identidad (2.2) antes de crear más tablas/providers basados en `int` |
| Migración SQLite de favoritos (PK) | Pérdida de datos si falla | Migración aditiva y por copia, con pruebas sobre bases v2 reales (hay infraestructura de tests con `sqflite_common_ffi`) |
| Recursos caducados / cabeceras | Fallo de reproducción | Resolvedor asíncrono y reintento; decisión en 2.1 |
| Fallo de red tratado como «archivo borrado» | Saltos erróneos en la cola | Distinguir tipos de error (hoy `PlaybackError` no los distingue) |
| Licencias/ToS del proveedor | Inviabilidad de reproducir/almacenar | Investigación previa (2.1) antes de construir nada |
| Resolvers paralelos de artwork | Reaparece la duplicación eliminada en la Fase 1.8 | Evolución por el puerto único (opción A) |
| `Song` convertido en God Model | Mantenimiento | Regla de §12: el dominio no enumera fuentes |
| Cambio de promesa de privacidad («sin backend… sin telemetría») | Expectativas del usuario | Decisión explícita de producto y actualización del README |
| Dos métodos de reencuentro mezclados | Fusiones erróneas | Matching por fuente |
| Precisiones sobre `just_audio` con URLs no verificadas | Plan de reproducción inválido | Verificar en 2.1/2.3 con pruebas de concepto |

## 22. Plan de fases posteriores

Propuesta, sujeta a los resultados de 2.1:

| Fase | Contenido | Toca código |
|---|---|---|
| **2.1 — Investigación de proveedores/APIs y licencias** | Qué fuentes son viables (derechos de reproducción, límites, autenticación, artwork, streaming, offline); ninguna decisión de implementación | No |
| **2.2 — Identidad de canción en el dominio** | Introducir el concepto de identidad de forma **aditiva** (p. ej., una identidad derivable de `Song`), sin romper API ni persistencia; tests | Sí (`core/domain`) |
| **2.3 — Resolvedor de recurso reproducible** | Puerto en `core`, resolvedor local (equivalente a hoy), `_toSource` y `MediaItem.id` por el puerto; sin red | Sí (`player`, `core`) |
| **2.4 — Persistencia de identidad** | Migración v3 de favoritos y playlists (fuente + id externo), retrocompatible | Sí (SQLite) |
| **2.5 — Artwork generalizado** | Referencia de artwork y evolución del puerto/caché | Sí (`core/artwork`) |
| **2.6 — Esqueleto de `features/catalog`** | Puerto de catálogo, adapter falso para tests, sin proveedor real, sin UI | Sí |
| **2.7+ — Primer proveedor** | Solo tras 2.1 y con las fases anteriores estables | Sí |

Orden sugerido: 2.2 → 2.3 → 2.4 son independientes de qué proveedor se elija y reducen el riesgo de P1/P3/P5.

## 23. Criterios de aceptación de Phase 2.0

| Criterio | Estado |
|---|---|
| La arquitectura local actual está comprendida | Cumplido: `Song`, `SongReference`, `SongMatcher`, repositorios, persistencia, reproductor, artwork y dependencias de MediaStore auditados (§2-§9) |
| Responsabilidades de Library, Catalog, Player y Playlists delimitadas | Cumplido (§14, §17) |
| La identidad de una canción está resuelta conceptualmente | Cumplido (§11): valor compuesto `(fuente, id externo)`; representación persistida aplazada con motivo |
| Estrategia para recursos locales/remotos | Cumplido (§13): identidad+metadata en `Song`, recurso por puerto resolvedor |
| La arquitectura es independiente de proveedores | Cumplido: sin nombres de proveedor en ninguna decisión (§12, §17, §19) |
| No hay decisiones críticas sin identificar | Cumplido: los riesgos de identidad/SQLite/artwork/recurso están identificados (§9, §16, §21) |
| Decisiones aplazadas documentadas | Cumplido (§20) |
| Sin cambios de código, dependencias, SQLite, UI ni reproductor | Verificado (ver validación) |

### Validación de la fase

- Sin cambios de código: el único archivo nuevo de esta fase es este documento.
- Búsqueda de referencias online: `pubspec.yaml` sin `http`, `dio`, GraphQL, OAuth, Firebase ni similares; `lib/` y el código Kotlin sin `HttpClient`, `okhttp`, `package:http`, ni URLs `http(s)://`. `INTERNET` solo aparece en los manifiestos de debug/profile.
- `pubspec.yaml`, `pubspec.lock` y `android/` sin modificaciones. Aunque no era obligatorio, se ejecutaron `flutter test` (**729 pasan**) y `flutter analyze` (sin problemas) como comprobación; no se hizo build por no haber cambios ejecutables. Sin commit ni push.

**PHASE 2.0 READY FOR PROVIDER RESEARCH**
