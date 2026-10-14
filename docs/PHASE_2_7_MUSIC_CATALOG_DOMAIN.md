# Fase 2.7 — Music Catalog Domain / Remote-ready Song model

> Fase **de arquitectura**: no se modificó código. Toda afirmación sobre usos
> sale de búsquedas en `lib/` y `test/` hechas en esta fase (referencias
> `archivo:línea` donde importa). Resultado: **READY FOR IMPLEMENTATION** de la
> estrategia incremental del §17; la siguiente fase solo ejecuta el paso 1.

## 1. Estado actual de Song

`lib/core/domain/entities/song.dart`: `Equatable`, 10 campos, **todos
obligatorios** salvo `folder`. `musicIdentity` es un getter **derivado** de `id`
(`localMusicIdentity(id)`): hoy una `Song` *no puede* tener una identidad que no
sea local. Origen único: `MediaStoreSongRepository._toSong`
(`media_store_song_repository.dart:29`).

Evidencia de que el modelo ya no encaja con otras fuentes: el helper de tests
`ForeignSong` (`test/helpers/foreign_song.dart`) tiene que **rellenar con basura**
`id: 0`, `path: ''`, `contentUri: ''`, `albumId: null`, `dateAdded: null` y
sobrescribir `musicIdentity` para representar una canción no local.

## 2. Auditoría campo por campo

Leyenda: ✔ lo usa / ✘ no. «Lectores» = código real de `lib/` que lo lee.

| Campo | Universal | Local | Playback | Artwork | Persistencia | Legacy | Lectores reales |
|---|---|---|---|---|---|---|---|
| `title` | ✔ | | | | respaldo | | UI (tile, mini, now playing, queue), `MediaItem`, `SongMatcher`, respaldo SQLite |
| `artist?` | ✔ | | | | respaldo | | UI, `MediaItem`, `SongMatcher`, respaldo |
| `album?` | ✔ | | | | | | tile (`taki_song_tile.dart:88`), `MediaItem` |
| `durationMs` / `duration` | ✔ | | | | respaldo | | UI, `MediaItem`, `SongMatcher` (±1 s), queue total, adapter |
| `musicIdentity` (derivado) | ✔ | hoy derivado de `id` | | | **clave** | | favoritos, playlists, `SongMatcher`, resolvers, UI (corazón) |
| `id` | ✘ | ✔ | | | ✘ (ya no) | **✔** | "¿es la que suena?" en 4 pantallas (`library_page.dart:156`, `favorites_page.dart:137`, `playlist_detail_page.dart:332`, `queue_page.dart:44`), `get_songs.dart:21` (desempate), y como entrada de `localMusicIdentity` |
| `albumId?` | ✘ | ✔ (MediaStore) | | ✔ | ✘ | | 10 llamadas de UI al builder, `LocalArtworkResolver`, `ArtworkFileCache`, `playlists_providers.dart:48` |
| `path` | ✘ | ✔ | | | respaldo (SQLite) | | `SongMatcher` (por ruta), `SongFilter` (carpeta), respaldo de favoritos/playlists |
| `contentUri` | ✘ | ✔ | ✔ | | ✘ | | **Solo** `LocalPlaybackResolver` (`:25`) y `MediaItem.id` (`taki_audio_handler.dart:141`) |
| `folder` | ✘ | ✔ | | | ✘ | | **Solo** `SongFilter` (`song_filter.dart:32`) |
| `dateAdded?` | ✘ | ✔ | | | ✘ | **✔ muerto** | Nadie lo lee: solo se escribe en el repositorio y se compara en `props` |

Clasificación demostrada: **5 universales** (título, artista, álbum, duración,
identidad) y **6 locales** (`id`, `albumId`, `path`, `contentUri`, `folder`,
`dateAdded`). `path` es local aunque se persista: es un respaldo opcional
(`PlaylistEntry.path`, `FavoriteEntry.path` ya son `String?`).

## 3. Auditoría de consumidores

`Song` aparece 91 veces en 38 archivos de `lib/` y 253 en 31 de `test/`;
`SongReference` solo en 4 archivos (matcher + 2 entradas persistidas + su
definición). Qué necesita cada uno **de verdad**:

| Consumidor | Qué lee | Necesita realmente |
|---|---|---|
| Library / Favorites / Playlists (páginas) | título, artista, álbum, duración; `albumId` (artwork); `id` (resaltar la actual) | metadata + `ArtworkReference` + `MusicIdentity` |
| Queue, MiniPlayer, Now Playing | metadata; `albumId`; `id` (clave de lista); `musicIdentity` (corazón) | metadata + `ArtworkReference` + `MusicIdentity` |
| `TakiSongTile`, `TakiMiniPlayer`, `song_actions` | solo metadata | metadata |
| Player (`JustAudioPlayerAdapter`) | `Song` completo se pasa a `PlaybackResolver`; `tag: song`; `duration` | `Song` → `PlaybackResource` (2.3 ya lo separa) |
| MediaSession (`TakiAudioHandler`) | metadata + `contentUri` (como `MediaItem.id`) + `albumId` (vía `ArtworkFileCache`) | metadata + id opaco + `ArtworkReference` |
| Artwork (`LocalArtworkResolver`, `ArtworkFileCache`) | `albumId` | datos **locales** (correcto: son resolvers locales) |
| Persistencia (repos SQLite, use cases) | `musicIdentity` + respaldo (`title`, `artist`, `durationMs`, `path`) | `MusicIdentity` + metadata |
| `SongMatcher`, `SongFilter`, `get_songs` | `path`, `folder`, `id`, metadata | datos locales (política de la **biblioteca local**) |
| Tests | `buildSong` (helper) y `Song(...)` directo | ver §17 |

Conclusiones:
- **Nadie necesita el `Song` completo salvo código de la fuente local.** La UI y
  el player necesitan *metadata + identidad + artwork*.
- Los lectores de campos locales son **resolvers/ políticas locales** (correcto)
  **más 3 fugas**: la UI lee `albumId` directamente, la UI compara por `id`, y
  `MediaItem.id` es el `contentUri`.
- `SongReference` ya está bien separada (identidad + respaldo); no cambia.

## 4. Dependencias de MediaStore

Fuera de `MediaStoreSongRepository` y `MediaStoreArtworkRepository`, el dominio
conserva dependencias *conceptuales* de MediaStore en: `Song.id`/`albumId`/
`contentUri`/`folder` (campos), `SongMatcher` (ruta, política «local»),
`SongFilter` (carpetas), y la UI (`albumId`, `id`). No hay imports de MediaStore
en el dominio (la prueba de arquitectura lo garantiza).

## 5. Alternativas arquitectónicas

| | A. `Song` universal, campos locales opcionales | B. `MusicTrack` + `LocalSong` (rename) | C. Piezas sueltas, sin agregado | **D. `Song` base universal + `LocalSong extends Song`** |
|---|---|---|---|---|
| Idea | `id`, `albumId`, `path`, `contentUri`… pasan a `?` | Nuevo agregado universal; `Song` pasa a `LocalSong` | `MusicMetadata` + `MusicIdentity` + `PlaybackResource` + `ArtworkReference` por separado | La clase `Song` **conserva el nombre** y queda solo con lo universal; lo local baja a una subclase |
| Ventajas | Cambio mínimo de firma | Nombres exactos | Máxima separación teórica | Mismo nombre para UI/player/queue; lo local queda confinado y tipado |
| Desventajas | Cada resolver y cada lector hace `!`/null-check; sigue siendo «un modelo de MediaStore con huecos»; `id` obligatorio int obliga a inventar valores (como `ForeignSong`) | Renombrar `Song` en 38 archivos de `lib/` y 31 de `test/` sin que cambie ningún comportamiento | La UI/cola/player siguen necesitando *un* objeto con metadata + identidad: reaparece el agregado, sin nombre ni tipo | Hace falta una (pequeña) migración de las 3 fugas y del tipado de lo local |
| Arquitectura | Ensucia el dominio | Limpia | Dispersa | Limpia |
| Player | Sin cambio, pero `Song` con campos vacíos | Cambia el tipo de la cola | Cola con estructuras paralelas | Sin cambio (la cola sigue siendo `List<Song>`) |
| SQLite | Ninguno | Ninguno | Ninguno | Ninguno |
| Artwork | `albumId?` sigue «colándose» | Igual que D | Igual que D | Resolver local lee `LocalSong`; remoto lee identidad / referencia |
| UI | Sin cambio | Rename masivo | Rewrite | Solo las 3 fugas |
| Migración | Pequeña pero **deja la deuda** | Grande | Muy grande | Incremental y reversible por pasos |
| Acoplamiento | Alto (todo conoce lo local) | Bajo | Bajo | Bajo: solo resolvers/políticas locales conocen `LocalSong` |

## 6. Alternativa elegida: D

**`Song` queda como el track universal** y `LocalSong extends Song` lleva lo
específico de MediaStore. Un proveedor remoto **no necesita su propia clase**
(`RemoteSong`/`SpotifySong`… quedan descartadas): devuelve `Song` base, con su
`MusicIdentity` explícita, y sus datos propios los resuelve cada resolver a
partir de la identidad.

```
Song                         (universal)
 ├ musicIdentity   (campo, ya no derivado)
 ├ title, artist?, album?, durationMs
 └ artwork         (ArtworkReference, ver §13)
LocalSong extends Song       (fuente local)
   id, albumId?, path, contentUri, folder, dateAdded?
   musicIdentity = localMusicIdentity(id)
```

## 7. Razones (basadas en el código)

1. **Quienes leen campos locales ya son locales** (§3): 3 resolvers/políticas
   locales y `MediaStoreSongRepository`. Moverlos a `LocalSong` es un cambio de
   tipo, no de lógica.
2. **A deja la deuda que `ForeignSong` ya expone** (valores falsos para campos
   obligatorios); D la elimina.
3. **B cuesta 69 archivos de renombre sin aportar capacidad** que D no tenga: el
   nombre `Song` no es el problema, lo son sus campos.
4. **C ya existe en lo que importa** (identidad, `PlaybackResource`,
   `ArtworkReference`, `SongReference`), pero la UI/cola/player necesitan un
   agregado de *metadata + identidad*: es `Song` sin lo local.
5. Persistencia y player **no cambian**: ya trabajan con identidad y con
   `PlaybackResolver(Song)`.

## 8. Futuro de `Song.id`

Opción elegida: **(B) pasa a ser propiedad de `LocalSong`** y, con el tiempo, (C)
se puede eliminar (su valor ya vive en `musicIdentity.externalId`).
- Persistencia: **ya no depende de él** (2.4); no debe volver a hacerlo.
- Pasos: (1) la UI deja de comparar por `id` y compara `musicIdentity`
  (4 sitios); (2) `get_songs` desempata por `musicIdentity.externalId`/ una clave
  local; (3) al separar `LocalSong`, `id` queda solo ahí; (4) opcional: derivarlo
  de `externalId` y borrarlo. No hay migración de datos.

## 9. Futuro de `albumId`

Vive **solo en `LocalSong`** (y en `LocalArtworkReference`). Es un dato de
MediaStore; `albumId != MusicIdentity.externalId` (el externalId es el `_ID` de
la **canción**; el `albumId` es de otro objeto y varias canciones lo comparten)
y `albumId != MusicIdentity`. Nunca se promociona a identidad. La UI deja de
leerlo (§13).

## 10. Futuro de `contentUri`

Pertenece a **`LocalSong`** como *dato de entrada* de la fuente local.
`PlaybackResource` (2.3) es la *salida* derivada (`LocalUriResource(contentUri)`):
no es duplicación, es la separación «qué sabe la fuente» / «cómo se reproduce».
No se mueve a `PlaybackResource` porque este se resuelve bajo demanda y no se
guarda en la canción. Su única fuga es `MediaItem.id = song.contentUri`
(`taki_audio_handler.dart:141`): debe ser un id opaco derivado de la identidad.

## 11. Relación con MusicIdentity

`MusicIdentity` sigue siendo la identidad universal y **no cambia**. Lo que
cambia es que en `Song` pasa de *derivada de `id`* a **campo explícito** (en
`LocalSong` se sigue derivando). Nada de `albumId`, `id` ni URLs entra en ella.

## 12. Relación con PlaybackResource

Sin cambios. `PlaybackResolver.resolve(Song)` se mantiene: el local hace
`song is LocalSong` (equivale a `source == 'local'`, que ya comprueba); uno
remoto decide con `song.musicIdentity`. El recurso se sigue pidiendo bajo
demanda (las URL caducan), nunca se guarda en `Song`.

## 13. Relación con ArtworkReference (consecuencia de 2.6)

Hoy `ArtworkResolver.resolve(Song)` es asíncrono y, para lo local, trivial. Para
un catálogo remoto es **probable que sobre**: las respuestas de listados suelen
traer ya la URL de la portada junto con la metadata, y una llamada asíncrona por
tile para obtener un dato que el listado ya tenía sería innecesaria.

**Decisión propuesta** (no implementada): `Song` expone
`ArtworkReference get artwork` — síncrona, producida por la fuente
(`LocalSong` = `localArtworkReference(albumId)`; un proveedor = la URL de su
listado, o `Unavailable`). La UI pasa `song.artwork` a
`AlbumArtworkBuilder.reference` (el widget ya existe) y deja de leer `albumId`.
`ArtworkResolver`/`SourceArtworkResolver` (2.6) quedan para fuentes que necesiten
una consulta posterior; **si ninguna la necesita, se eliminarán** (decisión a
tomar con el primer proveedor real; por eso no se toca 2.6 aquí).
`ArtworkFileCache` (notificación) pasa a recibir la referencia, sigue siendo solo
local.

## 14. Impacto en Player

Ninguno obligatorio ni en esta fase. Qué necesita realmente: `Song` (metadata +
identidad) para la cola y la notificación, y `PlaybackResource` bajo demanda —
que ya obtiene. **No** conviene pasar a «`MusicIdentity` + `PlaybackResource`»:
la UI de cola/Now Playing necesita metadata. Cambio menor pendiente:
`MediaItem.id` ← id opaco por identidad (hoy `contentUri`, que además se repite
si una canción está dos veces en la cola, igual que sucedería con la identidad).

## 15. Impacto en SQLite / persistencia

Ninguno. Favoritos y playlists guardan `source + external_id` + respaldo
opcional (`title`, `artist`, `duration`, `path`); eso soporta pistas remotas tal
cual. **No debe volver a depender de `Song.id`.** Lo que sí faltará en el
dominio (no en SQLite): hoy los favoritos/playlists se resuelven contra la
biblioteca **local** (`songsProvider` → `SongMatcher`,
`favorites_providers.dart:44`), así que una entrada remota quedaría «ausente».
Hará falta un puerto de búsqueda *identidad → `Song`* por fuente (p. ej.
`SongLookup`), con el `SongMatcher` como política exclusivamente local.

## 16. Impacto en UI

Dependencia de que `Song` sea local, medida:
- **Metadata + identidad (sin cambio):** `TakiSongTile`, `TakiMiniPlayer`,
  `song_actions`, corazones — la gran mayoría.
- **Fugas a corregir (13 sitios):** `albumId` en 10 llamadas al builder +
  `playlists_providers.dart:48`; comparación por `id` en 4 pantallas.
- **Local legítimo:** `SongFilter`/`folder` (filtro de carpetas de la biblioteca)
  y `get_songs`.
No hace falta migración masiva.

## 17. Estrategia incremental

Cada paso es un cambio **sin cambio de comportamiento**, con tests verdes, y
no toca SQLite, `PlaybackResource` ni `ArtworkReference`:

1. **Quitar fugas de la UI:** comparar `musicIdentity` (no `id`) para «la que
   suena»; `MediaItem.id` desde la identidad. *(la siguiente fase)*
2. **`Song.artwork`** (síncrono, derivado de `albumId` hoy) y la UI usa
   `AlbumArtworkBuilder.reference(song.artwork)`; `ArtworkFileCache` recibe la
   referencia.
3. **Separar `LocalSong`:** `Song` base con `musicIdentity` explícito;
   `LocalSong extends Song` con los campos locales; el repositorio MediaStore,
   `LocalPlaybackResolver`, `LocalArtworkResolver`, `SongMatcher`, `SongFilter` y
   `get_songs` pasan a tipar `LocalSong`. `buildSong` en tests construye
   `LocalSong`; `ForeignSong` desaparece (usa `Song` base).
4. **Eliminar `dateAdded`** (nadie lo lee) o documentar su uso futuro.
5. **`SongLookup`** (puerto identidad → `Song`) para resolver entradas guardadas
   de fuentes no locales; `SongMatcher` queda como política local.
6. (Con el primer proveedor) decidir si `ArtworkResolver` se elimina (§13) y
   registrar el resolver de reproducción del proveedor.

## 18. Qué debe hacer la siguiente fase

Ejecutar el **paso 1** (y, si cabe, el 2): corregir las fugas de la UI y de
`MediaItem.id`, con tests de que resaltar «la que suena» y las notificaciones se
comportan igual. Es pequeño, reversible y es precondición de todo lo demás.

## 19. Qué NO debe hacerse todavía

`RemoteSong`/`ProviderSong`/`SpotifySong…`, proveedores, catálogo o búsqueda
remota, HTTP musical, claves o autenticación, migrar SQLite, cambiar el Player,
`PlaybackResource` o `ArtworkReference`, renombrar `Song`, eliminar `Song.id` o
`albumId` antes de separar `LocalSong`, y borrar `ArtworkResolver` antes de
tener un proveedor que confirme que no hace falta.

## Riesgos de la decisión

- `LocalSong extends Song` usa herencia: debe mantenerse `Equatable` correcto
  (`props` incluyen los campos locales) para no romper `==` en tests y listas.
- `song is LocalSong` en los resolvers locales es una comprobación de tipo; se
  mantiene la de `identity.source` como contrato principal y el tipo como ayuda.
- Si un proveedor necesitara metadata propia en la cola (p. ej. un id de
  streaming distinto del externalId), habría que reconsiderar una extensión por
  composición; hoy no hay evidencia de esa necesidad.
