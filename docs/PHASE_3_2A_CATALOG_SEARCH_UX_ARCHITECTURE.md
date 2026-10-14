# Fase 3.2A — Arquitectura UX de la búsqueda de catálogo

Estado: **diseño**. Esta fase no cambia código de producción ni tests. Todo lo
que aquí aparece como «propuesta» se implementa en 3.2B–3.2E.

Base auditada (código real, no supuestos):

- `core/domain/ports/catalog_search.dart`, `entities/catalog_search.dart`
- `core/domain/entities/{song, music_identity, artwork_reference,
  playback_resource, playback_resolution_exception, provider_attribution,
  song_lookup_result, song_lookup_failure}.dart`
- `core/domain/services/{source_playback_resolver, source_song_lookup}.dart`
- `features/jamendo/**` (`JamendoCatalogSearch`, `JamendoPlaybackResolver`,
  `CachingJamendoApi`, `HttpJamendoApi`, `jamendo_song_mapper`)
- `app/{router, jamendo_wiring, song_lookup_wiring}.dart`
- `core/widgets/*` (Design System Taki), `docs/DESIGN_SYSTEM.md` §8, §14–§16
- `features/library/**`, `features/player/**` (puntos de integración)

---

## 0. Auditoría (resumen)

| Área | Hallazgo | Consecuencia para la búsqueda |
|---|---|---|
| Navegación | `StatefulShellRoute.indexedStack` con 4 destinos: Biblioteca, Playlists, Favoritos, Ajustes. Pantallas completas (`/now-playing`, `/queue`) fuera del shell. MiniPlayer + `NavigationBar` forman un único bloque inferior. DS §16: «máximo 5 destinos; si llega Buscar, la decisión es de producto». | Hay hueco para exactamente un destino más; es decisión de producto (D1). |
| Biblioteca | `LibraryPage` = «Tu música» (solo local, MediaStore). **No tiene búsqueda en la UI** (el único `TextField` de `lib/` es el diálogo de nombre de playlist). | Mezclar catálogo remoto dentro de «Tu música» rompería su significado. |
| Favoritos / Playlists | Ya operan sobre `Song` + `MusicIdentity` y se resuelven con `SongLookup` (cualquier fuente). `showSongActions(context, ref, Song)` es genérico. | Una `Song` remota ya encaja sin cambios. |
| Ajustes | `PlaceholderPage`. | No es un lugar para búsqueda. |
| MiniPlayer / Now Playing | Consumen `currentSongProvider`/`playbackStateProvider`; muestran `Song` + `AlbumArtworkBuilder.reference`. | Una `Song` remota ya se muestra. |
| Design System | `TakiSongTile`, `TakiArtwork`, `TakiEmptyState` (`noResults` ya documentado para «Sin resultados de búsqueda (futuro)»), `TakiErrorState`, `TakiButton`, `TakiIconButton`, SnackBar, tokens `TakiColors/Typography/Spacing/Radius`. El DS reserva `radiusFull` para el «futuro campo de búsqueda». | Casi todo existe. Faltan **campo de búsqueda** y **estado de carga de lista** (ver §13). |
| Contrato `CatalogSearch` | Un puerto de **una sola fuente**: `search(CatalogSearchQuery) → CatalogSearchPage(songs, hasMore)`; error `CatalogSearchFailure(message, source, cause)`. | No hay forma de enumerar ni elegir fuentes, ni de saber su etiqueta. |
| Cableado | `JamendoServices.search` existe, pero **no hay ningún provider de Riverpod ni registro de `CatalogSearch`** (a diferencia de lookup/playback/artwork, que tienen router por `source`). `jamendoServicesProvider` es `null` sin `JAMENDO_CLIENT_ID`. | Falta la pieza «registro de catálogos» (§7). Sin credencial no hay ninguna fuente. |
| Atribución | `ProviderAttribution` se construye en `JamendoTrack.attribution`, pero `songFromJamendoTrack` y `JamendoCatalogSearch` **la descartan**: `CatalogSearchPage` solo lleva `Song`. | **Incompatibilidad demostrable** con el requisito «Search Result → Song + provider metadata» (§9). |
| Reproducción | `PlaySongs(songs, index)` → `JustAudioPlayerAdapter` resuelve el recurso por canción (`SourcePlaybackResolver`). Un fallo de resolución (`IdentityNotFound`, `PlaybackResolutionError`, `UnavailableResource`) **se convierte en una fuente no reproducible** → `PlaybackError` y salto a la siguiente. | Presentation no ve el motivo; solo `PlaybackError(song)`. No se toca el Player. |
| Intermitencia Jamendo | `HttpJamendoApi` reintenta respuestas vacías (`emptyRetries = 3`, `retryDelay = 300 ms`). | La UI no reintenta (§5, §11). |
| Arquitectura | `dependency_rules_test`: features no dependen de otras salvo excepciones listadas; `core/domain` Dart puro; `features/search/` es un esqueleto con `.gitkeep`. | La feature `search` consume solo `core`; si reproduce, necesita añadir su excepción al test (como `library_page → player_providers`). |

---

## 1. UX goal

Que el usuario encuentre una canción **de cualquier fuente de catálogo
registrada** escribiendo una consulta, la reproduzca de inmediato y pueda
guardarla (favorito / playlist / cola) con los mismos gestos que ya conoce en
Biblioteca.

Principios:

1. **Provider-neutral.** Ninguna clase de `presentation` ni de `search/` nombra
   «Jamendo». Trabajan con `Song`, `MusicIdentity` y abstracciones de catálogo.
2. **Un solo `TakiSongTile`.** Un resultado es una `Song`; se dibuja como
   cualquier otra fila.
3. **Estados que no se confunden**: vacío ≠ fallo ≠ no disponible ≠ no
   soportado (§11).
4. **Nada persiste solo.** Buscar no escribe en SQLite ni en disco (§10).
5. **Sin lógica de red en la UI**: ni reintentos automáticos, ni HTTP, ni
   conocimiento de URLs temporales.

Fuera de alcance de toda la serie 3.2 (hasta decisión explícita): selector
visual de proveedor, descargas/offline, resultados parciales multi-fuente,
filtros avanzados (artista/etiqueta) en la UI.

---

## 2. Entry point

### Opciones evaluadas

| Opción | Pros | Contras |
|---|---|---|
| **A. Nuevo destino «Buscar» (5.º)** | Descubrible; coincide con la previsión del DS (§16); cada rama conserva su estado (indexedStack); no altera «Tu música». | Usa el último hueco de navegación; el DS exige decisión de producto. |
| B. Dentro de Biblioteca (barra de búsqueda arriba) | Cero navegación nueva. | Biblioteca es «Tu música»: mezcla local y catálogo; obliga a UI de segmentos local/online; mezcla semántica (`LibraryLoaded` vs resultados). |
| C. Icono de lupa en AppBar de Biblioteca → ruta apilada | No consume pestaña. | Poco descubrible; la búsqueda es una función principal del catálogo; sin estado persistente entre visitas; solo accesible desde una pestaña. |
| D. Dentro de Ajustes / Playlists | — | Semánticamente incorrecto. |

### Recomendación

**Opción A: un 5.º destino «Buscar»** (icono `search_rounded`, según DS
§ iconografía), **mostrado solo si hay al menos una fuente de catálogo
disponible**. Justificación:

- Es una función de primer nivel (encontrar música nueva) distinta de «mi
  música»; una pestaña propia deja Biblioteca intacta.
- La disponibilidad es **de compilación** (`JAMENDO_CLIENT_ID` por
  `--dart-define`), no de ejecución: el número de pestañas es estable en una
  build dada. Sin credencial la app queda idéntica a hoy (4 destinos), sin una
  pestaña vacía que no puede funcionar.
- Cumple el máximo de 5 destinos del DS.

> **D1 (decisión de producto, bloquea 3.2C, no bloquea 3.2B):** confirmar
> pestaña «Buscar» como 5.º destino y su etiqueta/posición (propuesta: entre
> Biblioteca y Playlists). 3.2B (estado/controlador/modelo) es independiente
> del punto de entrada.

Etiqueta de pestaña propuesta: **«Buscar»**. Título de pantalla: «Buscar».

---

## 3. Search contract

### 3.1 Contrato actual (se conserva tal cual)

```
CatalogSearch.search(CatalogSearchQuery) → Future<CatalogSearchPage>
CatalogSearchQuery { text?, artist?, tag?, limit = 20, offset = 0 }
CatalogSearchPage  { List<Song> songs, bool hasMore }
CatalogSearchFailure(message, {source, cause})  // red, credencial, parámetros
```

| Aspecto | Qué dice hoy el contrato | Implicación UX |
|---|---|---|
| **query** | Al menos uno de `text`/`artist`/`tag` no vacío (`trim`); si no, `ArgumentError`. | El controlador **nunca** construye una query en blanco (no se «captura» el `ArgumentError`). |
| **filtros** | `artist`, `tag` existen en el contrato. | La UI v1 usa solo `text`. Los filtros quedan disponibles para una fase posterior; no se diseña UI para ellos. |
| **source** | **No hay campo.** Cada `CatalogSearch` es de una fuente. | La elección de fuente es del registro (§7), no de `CatalogSearchQuery`. |
| **pagination** | `limit` > 0, `offset` ≥ 0; `hasMore` = «pedir `offset + limit` *puede* devolver más». | Paginación por offset. `hasMore` es una **pista**, no una garantía (§3.2). |
| **page size** | Default 20; Jamendo valida 1…200 (fuera de rango → `CatalogSearchFailure`). | La UI usa 20 (valor por defecto del contrato), no inventa otro. Ver D4. |
| **resultados** | `songs` ya mapeadas a `Song` universal (con `ArtworkReference` remota o `Unavailable`). | La UI no mapea nada del proveedor. |
| **error** | Una sola excepción tipada. No distingue red/credencial/parámetros de forma estructurada. | Mensaje genérico sin jerga + «Reintentar» (§11). |
| **empty** | `songs.isEmpty`, `hasMore == false` en la primera página. | `TakiEmptyState.noResults`, no error. |
| **loading** | No existe en el contrato (es del estado de UI). | Lo modela el estado (§4). |

### 3.2 Notas de contrato descubiertas en la auditoría

- **`hasMore` puede ser `true` y la página siguiente vacía.** En Jamendo
  `hasMore = rawCount >= limit`; si el total es múltiplo exacto de `limit`, la
  siguiente página llega vacía. Regla: una página vacía **posterior a la
  primera** significa «fin de la lista», nunca «sin resultados» ni error.
- **`hasMore` cuenta pistas en bruto**: una página puede traer menos de `limit`
  `Song` y `hasMore == true`. No se deduce el fin de la lista por
  `songs.length < limit`; se usa solo `hasMore`.
- **«Éxito con 0 resultados» intermitente (Jamendo)** ya lo mitiga la
  infraestructura (`emptyRetries`). Tras agotar reintentos, la capa de UI no
  puede distinguirlo de un vacío legítimo; **se muestra como vacío** (es lo que
  el contrato afirma). Ver §11 sobre la repetición manual.
- **No hay cancelación en el puerto.** `Future<CatalogSearchPage>` no se puede
  abortar. «Cancelar» = descartar el resultado obsoleto (§5), no abortar la
  petición HTTP.

### 3.3 Cambios propuestos al contrato

Único cambio necesario (aditivo, retro-compatible), **a documentar aquí y
aplicar en 3.2B con tests**:

> **C1 — Atribución viaja con la página de resultados.**
> `CatalogSearchPage` añade un campo opcional
> `Map<MusicIdentity, ProviderAttribution> attributions` (por defecto `const
> {}`). `JamendoCatalogSearch` lo rellena con `track.attribution` de cada
> track. Ver §9 para la justificación y alternativas.

No se propone ningún otro cambio a `CatalogSearchQuery`, `CatalogSearchFailure`
ni al puerto. En particular **no** se añade `source` a la query (§7).

---

## 4. Search state machine

El estado es un tipo sellado en `features/search/domain` (Dart puro, sin
Flutter), producido por un controlador de presentación (Riverpod `Notifier`).

```
sealed class CatalogSearchViewState
  SearchIdle                       // initial: sin query utilizable
  SearchTyping(text)               // typing/debounced: query en espera
  SearchLoading(query)             // primera página en vuelo
  SearchResults(query, items, hasMore, pagination)  // ≥1 resultado
  SearchEmpty(query)               // 0 resultados, sin error
  SearchFailed(query)              // fallo del proveedor
  SearchUnavailable                // ninguna fuente registrada
```

`pagination` (dentro de `SearchResults`): `idle | loadingMore |
loadMoreFailed`.

### Transiciones

```
              (texto < mín.)                      (sin fuentes)
   ┌────────────────────────────┐             ┌────────────────────┐
   ▼                            │             ▼                    │
SearchIdle ──escribe──▶ SearchTyping ──debounce──▶ SearchLoading
   ▲                      │  ▲                      │      │     │
   │ borra / < mín.       │  └──escribe de nuevo────┘      │     │
   └──────────────────────┘                                │     │
                                       ┌───────────────────┘     │
                                       ▼                         ▼
                              SearchResults ◀──retry──── SearchFailed
                                │   ▲  │                        ▲
                       loadMore │   │  └─ 0 resultados ▶ SearchEmpty
                                ▼   │
                     pagination: loadingMore / loadMoreFailed
```

Reglas:

| De → A | Condición |
|---|---|
| `Idle → Typing` | El texto cambia y tiene ≥ mínimo de caracteres. |
| `* → Idle` | El texto queda por debajo del mínimo o se borra (§5). Cancela lo pendiente y **descarta** resultados previos. |
| `Typing → Loading` | Vence el debounce con el mismo texto. |
| `Loading → Results / Empty / Failed` | Según `CatalogSearchPage` (≥1 song / 0 songs / `CatalogSearchFailure`). |
| `Results → Results(loadingMore)` | El usuario llega al final y `hasMore`. |
| `loadingMore → Results` | Página recibida (puede estar vacía → `hasMore = false`, §3.2). |
| `loadingMore → Results(loadMoreFailed)` | Falla la siguiente página: **se conservan** los resultados ya cargados; pie de lista con «Reintentar». No se pasa a `SearchFailed`. |
| `Failed → Loading` | Acción explícita del usuario «Reintentar» (misma query). |
| `Idle → Unavailable` | Solo si el registro no tiene fuentes (pantalla oculta en la práctica, ver §2; es defensa). |

### Datos parciales

El contrato actual **no** tiene resultados parciales (una sola fuente por
llamada; una página es completa o falla). Por tanto **no se modelan
`SearchPartial`**. Se reabre cuando exista una segunda fuente real (D6), igual
que ya se decidió para `SourceSongLookup`.

Mientras hay un `Typing` tras un `Results`, la lista previa **permanece
visible** hasta que `Loading` empiece (sin parpadeo a vacío al teclear).

---

## 5. Query lifecycle

| Aspecto | Comportamiento propuesto | Origen del valor |
|---|---|---|
| Normalización | `text.trim()`; el texto original del campo no se modifica. | Contrato (`_blank` usa `trim`). |
| Longitud mínima | El contrato exige ≥1 carácter no blanco. **Mínimo de UX: ver D2** (propuesta: 2). | Contrato = 1; UX **pendiente**. |
| Debounce | Aplicado en el controlador al pasar `Typing → Loading`. **Valor: ver D3** (propuesta de partida: 400 ms). | **Pendiente**; no hay valor existente en el repo. |
| Envío explícito | Acción «buscar» del teclado salta el debounce y lanza la búsqueda ya (si cumple el mínimo). | UX estándar. |
| Cancelación de la anterior | Cada búsqueda lleva un **token de generación**; al llegar un resultado cuyo token no es el vigente, se descarta. No se aborta el HTTP (el puerto no lo permite). | Limitación del puerto (§3.2). |
| Borrar la query | Texto vacío o bajo el mínimo → `SearchIdle`; cancela debounce y descarta resultado en vuelo. | — |
| Entrar a la pantalla | `SearchIdle` (o el estado conservado, ver abajo); **no** lanza ninguna petición por sí sola. El foco no se pide automáticamente (decisión D5). | — |
| Salir de la pantalla | Al cambiar de pestaña el estado **se conserva** (cada rama del shell conserva su estado). Una petición en vuelo termina y actualiza el estado. Al destruir la rama/proceso, se pierde (§10). | `StatefulShellRoute.indexedStack`. |
| Paginación | Offset = nº de `Song` ya cargadas **de esta query** (`offset += songs.length` de cada página recibida), `limit` = tamaño de página. Se pide la siguiente al acercarse al final del scroll y solo si `hasMore` y no hay otra petición en vuelo. | Contrato (`offset`/`limit`). |
| Repetición | Misma query ya mostrada (p. ej. reenviar con el teclado) → no relanza si el estado es `Results` de esa query; sí relanza desde `Failed` (botón). Una query nueva siempre reinicia a offset 0. | — |
| Errores | `CatalogSearchFailure` → `SearchFailed` (primera página) o `loadMoreFailed` (siguientes). **Sin reintentos automáticos** en presentation; el único reintento es el gesto explícito del usuario. | §11 / §12. |

Lo que **no** hace la UI: reintentar «porque llegaron 0 resultados». Eso
duplicaría la mitigación de infraestructura y rompería la semántica de vacío.

---

## 6. Result model

Un resultado se **presenta** con un modelo de presentación mínimo, sin
tipos de proveedor:

```
CatalogResultItem
  song:        Song                          // tal cual vino de CatalogSearch
  attribution: ProviderAttribution?          // metadata del proveedor (C1); null si no vino
  providerLabel: String?                     // derivado del registro (§7), no del Song
```

`CatalogResultItem` es un modelo de la feature `search` (no se añade a
`core`).

### Qué muestra cada fila (`TakiSongTile`, sin crear otro tile)

| Elemento | Fuente | Detalle |
|---|---|---|
| Artwork | `song.artwork` vía `AlbumArtworkBuilder.reference(size: TakiSongTile.artworkSize)` | Referencia remota → placeholder si falla o no hay (DS §7.2: «error de artwork no se muestra»). Decorativa (sin `semanticLabel`). |
| Título | `song.title` | Una línea, elipsis. |
| Artista | `song.artist ?? 'Artista desconocido'` | Lo resuelve el tile. |
| Álbum | `song.album` | `showAlbum: true` (en búsqueda ayuda a desambiguar). |
| Duración | `song.duration` | `showDuration: true`. |
| Estado de reproducción | `playback:` (`playing`/`paused`/`none`) comparando `song.musicIdentity` con `currentSongProvider` | Igual que `LibraryPage`: solo selecciona `musicIdentity` e `isPlaying`. |
| Favorito | `isFavorite:` desde `favoriteIdentitiesProvider` | Ya existe el mecanismo (identidad). Se conecta en 3.2D. |
| `available` | siempre `true` en búsqueda | «No disponible» pertenece a identidades guardadas (§11), no a resultados recién devueltos. |

### Acciones disponibles

| Gesto | Acción |
|---|---|
| Tap en la fila | Reproducir (§8). |
| `onMore` (⋯) / pulsación larga | `ShowSongActions`: reproducir a continuación, añadir a la cola, favorito, añadir a playlist. **Reutiliza `showSongActions`** (inyectado desde el router, como en las demás páginas). |
| Atribución (futuro) | Punto de acceso reservado en 3.2E (§9); no se dibuja en 3.2C. |

El nombre de proveedor **no** se muestra por fila en v1 (una sola fuente; ruido
visual). El campo `providerLabel` queda en el modelo para el día en que haya
varias o para 3.2E.

---

## 7. Provider abstraction

### Qué existe hoy

Solo `MusicIdentity.source` (cadena opaca) y `ProviderAttribution.providerName`.
No existe «metadata de proveedor» independiente ni forma de enumerar catálogos.

### Propuesta mínima y neutral (en `core/domain`, Dart puro)

```
CatalogProviderInfo                // value object, Equatable
  source: String                   // = MusicIdentity.source (opaca)
  label:  String                   // nombre para mostrar, p. ej. "Jamendo" (lo aporta el wiring)

CatalogSources                     // puerto: registro de catálogos disponibles
  List<CatalogProviderInfo> get available   // vacío = sin catálogo
  bool  get isAvailable                     // available.isNotEmpty
  CatalogSearch searchIn(String source)     // lanza si la fuente no está registrada
```

- **provider** = quien implementa `CatalogSearch` + `SongLookup` +
  `PlaybackResolver` para una etiqueta de fuente.
- **source** = `MusicIdentity.source`: la misma etiqueta opaca de siempre.
- **provider label** = `CatalogProviderInfo.label`, aportado en el cableado
  (`app/`), no derivado ni hardcodeado en presentation.
- **provider availability** = presencia en `CatalogSources.available`. Es
  estática por build (credencial). No se modela «proveedor caído»: eso es un
  `CatalogSearchFailure` en tiempo de búsqueda.

Implementación (3.2B): `SourceCatalogSources(Map<String, ({String label,
CatalogSearch search})>)` en `core/domain/services`, siguiendo el patrón de
`SourceSongLookup`/`SourcePlaybackResolver`; cableado en `app/` junto a
`jamendo_wiring.dart` (`buildCatalogSources(JamendoServices?)`), con un
provider Riverpod en `core/` análogo a `songLookupProvider`. **Presentation
solo importa `CatalogSources`**, nunca `jamendo_wiring` ni `features/jamendo`.

**Selección de fuente en v1:** con una única fuente, el caso de uso busca en
`available.single`. Con ≥2, la política (fan-out, «Todas», selector) es la
decisión D6 y **no se implementa**. No hay selector visual.

Esto se alinea con la regla ya adoptada en `SourceSongLookup`: aislar fallos por
fuente exige UI de resultados parciales y «se decidirá con la segunda fuente
real».

---

## 8. Playback interaction

```
Tap en resultado
   └─▶ Song (de CatalogResultItem)
        └─▶ PlaySongs(songs, index)        // caso de uso del Player, sin cambios
             └─▶ AudioPlayerPort.setQueue
                  └─▶ JustAudioPlayerAdapter._toSource
                       └─▶ PlaybackResolver (SourcePlaybackResolver)
                            └─▶ resolver de la fuente → PlaybackResource
```

Presentation solo conoce `Song` y `playSongsProvider`. El audio, la URL y el
resolver de la fuente son invisibles (`PlaybackResource` no sale del
adaptador).

**Cola:** al tocar la fila *i*, la cola es **la lista de resultados cargados**,
empezando en *i* (paridad con Biblioteca, que reproduce «la lista tal como se
ve»). Al cargar más páginas la cola ya creada **no cambia** (no se inyecta en
caliente).

> **D7 (a validar con medición en 3.2D):** `setQueue` resuelve **todas** las
> canciones de la cola al crearla (`Future.wait` sobre `_toSources`). Con
> resultados recién buscados salen de `JamendoAudioCache` (TTL 10 min), pero si
> el usuario tarda más de 10 min en tocar, se hará una consulta por canción.
> Mitigaciones sin tocar el Player: acotar la cola a los cargados (ya es así) y/o
> encolar solo desde la canción tocada. Se decide con datos en 3.2D.

### Casos de fallo

| Caso | Qué ocurre hoy (sin cambiar Player) | UX |
|---|---|---|
| `UnavailableResource` (sin audio) | Fuente no reproducible → `PlaybackError(song)` → salto a la siguiente. | Mensaje genérico: «No se pudo reproducir «X»». |
| URL temporal falla / caducó | Error de just_audio → mismo camino (`PlaybackError`). | Igual. Reintentar = volver a tocar: el resolver vuelve a pedir si la caché (TTL 10 min < caducidad observada ≥20 min) ya no la tiene. |
| Proveedor falla al resolver (`PlaybackResolutionError`) o `IdentityNotFound` | El adaptador lo convierte en `UnavailableResource` → `PlaybackError`. | Igual. |
| Sin fuente registrada | `IdentityNotFound` desde `SourcePlaybackResolver` → ídem. | Igual. |
| Fallo de artwork | Placeholder silencioso. | Ninguna (DS §7.2). |

**Limitación aceptada:** presentation no puede distinguir los motivos, porque el
Player (fuera de alcance) los colapsa en `PlaybackError`. Si 3.2D mide que la
distinción importa, se abre una fase para el Player; no se resuelve en la UI
con lógica de proveedor.

---

## 9. Attribution contract

### Problema (demostrado)

`ProviderAttribution` (identidad, `providerName`, `pageUrl`, `licenseUrl`,
`licenseName`) vive en `JamendoTrack.attribution`. Pero:

1. `songFromJamendoTrack(track)` produce una `Song` sin ella (correcto: no se
   mueve a `Song`).
2. `JamendoCatalogSearch.search` devuelve `CatalogSearchPage(songs, hasMore)`:
   el `JamendoTrack` se descarta dentro del puerto.
3. Cuando la UI recibe la página, **la atribución ya se perdió** y rehacerla
   obliga a volver a consultar al proveedor por id (`tracksByIds`).

Es incompatible con «Search Result → Song + provider metadata → Attribution UI
futura».

### Propuesta (C1)

`CatalogSearchPage` gana un campo **aditivo**:

```
CatalogSearchPage(songs, {required hasMore,
                          Map<MusicIdentity, ProviderAttribution> attributions = const {}})
```

- Clave = `song.musicIdentity` (ya hay invariante: `ProviderAttribution.identity`
  es esa identidad).
- Cero red extra: la atribución sale del mismo `JamendoTrack` que produjo la
  `Song`.
- **No** se mueven `shareUrl/licenseUrl/licenseName` a `Song`.
- Una fuente que no tiene atribución devuelve el mapa vacío; la UI debe tratar
  la atribución como **posiblemente ausente o incompleta** (`hasPageUrl`,
  `hasLicense`), según el contrato ya documentado de `ProviderAttribution`.

Alternativa descartada: un puerto `AttributionLookup(identity)` que re-consulta.
Útil más adelante para entradas que **no** vienen de una búsqueda (favoritos de
una canción remota, cola tras reinicio), pero para resultados de búsqueda
duplicaría una llamada que ya se hizo. Se evalúa en 3.2E si se muestra la
atribución fuera de Search.

### Recorrido

```
JamendoTrack ──songFromJamendoTrack──▶ Song
      └──.attribution───────────────▶ ProviderAttribution
                      ▼
       CatalogSearchPage(songs, attributions)
                      ▼
       CatalogResultItem(song, attribution)         (presentation, en memoria)
                      ▼
       Attribution UI futura (3.2E): proveedor + enlace + licencia, degradando con gracia
```

Ciclo de vida: la atribución vive **solo en memoria** con los resultados; no se
persiste (coherente con la doc de `ProviderAttribution`).

---

## 10. Favoritos / playlists: compatibilidad

No se implementa nada ni se toca SQLite, migraciones, `FavoritesRepository` ni
el repositorio de playlists. Compatibilidad **ya existente** a través de
`MusicIdentity`:

| Acción | Qué ocurre con un resultado remoto |
|---|---|
| **Play** | §8. |
| **Queue** (siguiente / al final) | `AudioPlayerPort` acepta `Song`; el audio se resuelve en `_toSource` cuando entra a la cola. Sin cambios. |
| **Favorito** | `FavoritesRepository.add(Song)` guarda `MusicIdentity` + copia de respaldo `title/artist/album/durationMs` (`path` = `null`, es remoto). **No** guarda artwork, audio ni atribución. Al abrir Favoritos, `GetFavoriteSongs` resuelve la identidad con `SongLookup` (Jamendo `tracksByIds`) y recupera `Song` y artwork frescos. |
| **Añadir a playlist** | `addSongsToPlaylistFlow(context, ref, [song])` ya es genérico sobre `Song`; guarda identidad. Igual que favoritos. |
| Corazón en el tile | `favoriteIdentitiesProvider` compara por `MusicIdentity`: un resultado de búsqueda ya marcado aparece como favorito sin código nuevo. |

Riesgos para 3.2D (a verificar, no resolver aquí):

- **R-FAV-1:** `SourceSongLookup` propaga el fallo de una fuente a **todo el
  lote**: si Jamendo no responde, la pantalla Favoritos entera falla aunque
  haya favoritos locales. Con favoritos remotos esto pasa a ser frecuente (sin
  red). Está documentado como diferido «hasta la segunda fuente», pero merece
  re-evaluarse al activar la acción «favorito» desde Search.
- **R-FAV-2:** `showSongActions` ofrece acciones de cola/favorito/playlist sin
  distinguir fuente; es lo deseado, pero hay que comprobar los textos (p. ej.
  «Quitar de…») con una `Song` remota.

---

## 11. Empty / error semantics

Cuatro situaciones distintas, **con superficies distintas**:

| Situación | Significado | Dónde ocurre | Superficie UI |
|---|---|---|---|
| **SEARCH EMPTY** | La búsqueda terminó bien y no hay canciones. | `CatalogSearchPage.songs.isEmpty` en la 1.ª página. | `TakiEmptyState(kind: noResults, icon: search_off_rounded, title: «Sin resultados para «…»»)`. Sin acción obligatoria (opcional terciaria «Limpiar búsqueda»). **No** es error. |
| **PROVIDER ERROR** | La fuente falló (red, credencial, parámetros). | `CatalogSearchFailure`. | `TakiErrorState(kind: error)` con «Reintentar» (acción explícita). En 2.ª+ página: pie con «Reintentar», lista intacta. |
| **LOOKUP MISSING** | Una identidad **guardada** no se pudo resolver porque la fuente no tiene esa canción. | `SongLookupResult.missing` (Favoritos/Playlists). | **No existe en Search.** Un resultado recién devuelto nunca está «missing». Se muestra como `TakiSongTile(available: false)` en Favoritos/Playlists, ya hecho. |
| **UNSUPPORTED** | Ninguna fuente registrada soporta esa identidad (config). | `SongLookupResult.unsupported`, `IdentityNotFound`. | En Search: no hay fuentes → entrada oculta o `SearchUnavailable` (defensa). En reproducción: ver §8. Nunca se presenta como «sin resultados». |

Reglas:

1. `SearchEmpty` y `SearchFailed` son tipos de estado distintos y widgets
   distintos; el controlador jamás convierte uno en otro.
2. «Missing Song» ≠ «Search empty»: el primero es un estado de una *identidad
   guardada*; el segundo, de una *consulta*.
3. Un fallo de **artwork** nunca produce estado de error.
4. Páginas posteriores vacías = fin de lista (§3.2), sin mensaje.

### Intermitencia de Jamendo

La mitigación (`emptyRetries`) está en infraestructura y **no se duplica** en
presentation: no hay reintento automático por «0 resultados», ni por error, ni
temporizadores de reintento. Si, tras la mitigación, aún llega un vacío falso,
el usuario lo ve como «Sin resultados» y puede reenviar la búsqueda (acción
manual normal: cambiar el texto o pulsar «buscar» de nuevo). **Decisión
consciente:** no se añade un botón «Reintentar» en el estado vacío (haría que el
vacío pareciera un fallo).

> Para que reenviar la misma query relance la petición (y no se ignore por la
> regla de «misma query ya mostrada», §5), la acción explícita de «buscar» del
> teclado sobre un `SearchEmpty` sí relanza. Detalle a fijar en 3.2B con test.

---

## 12. Accessibility

Requisitos (se verificarán en 3.2C/3.2D con tests de semántica, no se implementan
ahora):

| Elemento | Requisito |
|---|---|
| Campo de búsqueda | `Semantics(textField: true, label: 'Buscar canciones')`; botón «Borrar búsqueda» con `semanticLabel`; acción de teclado `search`; área táctil ≥ 48 dp. |
| Resultado | El `Semantics` de `TakiSongTile` ya anuncia «título, artista[, álbum], duración» + estado («Reproduciendo», «En pausa», «Favorita»). No se añade ruido. |
| Artwork | Decorativo (`ExcludeSemantics`, sin `semanticLabel`): la información ya está en el texto de la fila. |
| Botones | `TakiIconButton`/`TakiButton` con `semanticLabel`; «Más opciones» ya existe. |
| Carga | La primera página anuncia «Buscando…» (live region) y el spinner es el del DS (DS §17 «Loading»: semántica «Cargando»). Sin shimmer (DS §7.2). La carga de más páginas anuncia «Cargando más resultados». |
| Resultados listos | Anunciar el resultado una vez estable: «N resultados» (o «Sin resultados para …»). No anunciar en cada tecla (solo tras el debounce). |
| Error | `TakiErrorState` ya marca el título como `header`; el botón «Reintentar» recibe foco accesible. El mensaje no usa jerga técnica (DS §15). |
| Reproducción | Cambio de estado anunciado por el tile («Reproduciendo»). Un fallo de reproducción se anuncia vía SnackBar (live region). |
| Foco/teclado | Orden: campo → resultados. `TakiFocusRing` en filas. Al cerrar el teclado, el foco vuelve al campo. |
| Texto grande | Filas crecen (alto mínimo 64); el campo y los estados no truncan a 200 %. |

---

## 13. Design System mapping

Solo tokens y componentes Taki; **ningún color arbitrario**, ningún Material por
defecto visualmente incompatible.

| Necesidad | Componente / token | Estado |
|---|---|---|
| Fila de resultado | `TakiSongTile` (+ `AlbumArtworkBuilder.reference`, `TakiArtwork`) | Existe |
| Sin resultados | `TakiEmptyState(kind: noResults)` | Existe (caso «futuro» ya documentado, DS §14) |
| Error de búsqueda | `TakiErrorState` | Existe |
| Reintentar / acciones | `TakiButton` (`tertiary`/`primary`), `TakiIconButton` | Existe |
| Menú de acciones | `showSongActions` (bottom sheet `surfaceElevated`) | Existe |
| Fallo de reproducción | SnackBar DS §15 | Existe |
| Primer uso (query vacía) | `TakiEmptyState(kind: firstUse)` con texto que invite a buscar | Existe |
| Colores | `TakiColors` (`textPrimary`, `textSecondary`, `surface`, `surfaceElevated`, `primary`, …) | Existe |
| Tipografía / espacio / radio | `TakiTypography`, `TakiSpacing` (`pageGutter`), `TakiRadius` (`radiusFull` para el campo) | Existe |
| **Campo de búsqueda** | **`TakiSearchField`** | **Nuevo** (pendiente 3.2C) |
| **Carga de lista (primera página y «más»)** | **`TakiLoadingIndicator`/pie de lista** (spinner DS, sin shimmer) | **Nuevo** (pendiente 3.2C); hoy las pantallas usan `CircularProgressIndicator` directo |
| Pestaña «Buscar» | `NavigationDestination` con `search_rounded` | Cambio de `AppShell` (3.2C, tras D1) |

Componentes nuevos a documentar en `DESIGN_SYSTEM.md` cuando se implementen:

- **`TakiSearchField`**: píldora (`radiusFull`), fondo `surface`, icono
  `search_rounded` a la izquierda, botón «Borrar» a la derecha cuando hay
  texto, texto `body`, hint `textMuted`, estados de interacción del DS §17
  (focus ring `primary`, disabled al 38 %). Altura mínima 48. Sin
  `InputDecoration` Material por defecto sin tema.
- **Pie de lista paginado**: spinner + etiqueta accesible «Cargando más
  resultados»; variante de error con `TakiButton.tertiary` «Reintentar».

---

## 14. Navigation impact

| Cambio | Detalle |
|---|---|
| `AppRoutes` | Añadir `search = '/search'` (3.2C, tras D1). |
| `router.dart` | Nueva `StatefulShellBranch` con `SearchPage(onSongActions: showSongActions)`; el router de `app/` ya es el único que importa `showSongActions`. |
| `AppShell` | 5.º `NavigationDestination` («Buscar»), **condicional** a `CatalogSources.isAvailable`. El índice de las ramas debe construirse con esa condición para no desalinear `selectedIndex`. |
| `dependency_rules_test` | Si `search_page` reproduce vía `player_providers`, añadir la excepción `features/search/presentation/pages/search_page.dart -> features/player/presentation/providers/player_providers.dart` (mismo patrón que `library_page`) y, para favoritos, `... -> features/library/presentation/providers/favorites_providers.dart`. Se registra en `ARCHITECTURE.md` como las existentes. |
| MiniPlayer / Now Playing | Sin cambios. La pestaña Buscar queda dentro del shell: conserva MiniPlayer y barra. |
| Doble toque en la pestaña activa | Ya regresa a su raíz (`initialLocation`); para Search significa «reset a `Idle`». A confirmar en D5. |

---

## 15. Responsive / Android

| Aspecto | Comportamiento |
|---|---|
| Teclado | `Scaffold` con `resizeToAvoidBottomInset` (default): el campo permanece visible y la lista se recorta, no se desplaza el MiniPlayer. Al hacer scroll de resultados, el teclado se cierra (`keyboardDismissBehavior: onDrag`). |
| Scroll | Lista perezosa (`SliverPrototypeExtentList` como en Biblioteca, para que el alto siga el tamaño de texto). Paginación al acercarse al final; no se dispara con una lista que cabe entera sin scroll comprobando `hasMore` y la métrica de scroll. |
| Safe areas | Heredadas del `Scaffold`/shell; el pie de lista deja aire (DS §3: `TakiSpacing.lg`) para no quedar bajo el bloque MiniPlayer + barra. |
| MiniPlayer | Las listas reservan el alto del bloque inferior (ya lo hace el shell). |
| Resultados largos | Título/artista en una línea con elipsis; álbum se recorta primero (comportamiento del tile). Sin límite superior de resultados cargados en v1 (ver D4); la memoria es proporcional a las páginas pedidas. |
| Artwork | Resolución por `AlbumArtworkBuilder` con la `ArtworkCache` existente; 48 dp en filas. Sin layout específico por proveedor. |
| Orientación | Android es el objetivo; vertical primario. En horizontal la lista es de una columna (como Biblioteca); no se diseña un layout dedicado. |

Ningún layout depende del proveedor: la fila es la misma para cualquier fuente.

---

## 16. Result lifetime (qué se conserva y dónde)

| Dato | Dónde vive | Persistencia |
|---|---|---|
| Texto de la query, estado, páginas cargadas, `hasMore`, `attributions` | Estado del controlador de Search (memoria) | **Solo memoria.** Se pierde al cerrar la app. Se conserva mientras la pestaña viva (shell). |
| `Song` remota (metadata) | Memoria: resultados, y la cola del reproductor si se reproduce | No se persiste por buscar. Si se marca favorito/playlist: se guarda **identidad + copia de respaldo** `title/artist/album/durationMs` (comportamiento ya existente de 2.4). |
| `MusicIdentity` | Viaja por las abstracciones (cola, favoritos, playlists) | Persistente solo cuando el usuario guarda la canción. |
| URL de audio | `JamendoAudioCache` (memoria, TTL 10 min, capacidad 500) | **Nunca** a disco ni SQLite. |
| Artwork remoto (bytes) | `ArtworkCache` (memoria, LRU) | **No se persiste.** La `RemoteArtworkReference` tampoco: se vuelve a obtener por `SongLookup` al abrir Favoritos. |
| `ProviderAttribution` | En memoria con los resultados | No se persiste. |
| Resultados tras salir | Se descartan al destruir el estado; no hay «historial de búsquedas» ni caché de resultados en esta serie | — |

Al reproducir un resultado, la `Song` seguirá en la cola del reproductor aunque
el usuario salga de Search; su audio se resuelve de nuevo bajo demanda. Un
historial de búsquedas recientes (preferencias, no SQLite) queda fuera de 3.2.

---

## 17. Open decisions

| # | Decisión | Propuesta | Bloquea |
|---|---|---|---|
| **D1** | Punto de entrada: 5.º destino «Buscar», visible solo con catálogo disponible. Etiqueta y posición. | Pestaña «Buscar» entre Biblioteca y Playlists. | **3.2C** (no 3.2B) |
| D2 | Longitud mínima de la query (el contrato admite 1). | 2 caracteres. | 3.2B (parámetro del controlador) |
| D3 | Debounce. No hay valor previo en el repo. | 400 ms; medir en dispositivo. | 3.2B (parámetro) |
| D4 | Tamaño de página y tope de resultados cargados. | 20 (default del contrato), sin tope en v1. | 3.2B |
| D5 | Foco automático al entrar; doble toque en la pestaña = reset a `Idle`. | Sin foco automático; el doble toque limpia. | 3.2C |
| D6 | Política con ≥2 fuentes (fan-out, «Todas», selector, resultados parciales). | Diferida hasta la 2.ª fuente real. | Ninguno ahora |
| D7 | Cola al tocar un resultado (lista cargada vs. solo la canción) y coste de resolver toda la cola. | Lista cargada; medir en 3.2D. | 3.2D |
| D8 | Cambio C1 (`attributions` en `CatalogSearchPage`) vs. puerto `AttributionLookup`. | C1 ahora; `AttributionLookup` solo si 3.2E lo necesita fuera de Search. | 3.2B |
| D9 | Copy final (títulos, mensajes, hint del campo). | Redactar en 3.2C junto con el estado vacío/error. | 3.2C |

---

## 18. Implementation phases

División propuesta (se mantiene la sugerida; la auditoría la confirma, con una
corrección de reparto):

### 3.2B — Estado/controlador + modelo de presentación (neutral)

- `core/domain`: `CatalogProviderInfo`, puerto `CatalogSources`,
  `SourceCatalogSources`; **C1** (`attributions` aditivo en `CatalogSearchPage`
  + `JamendoCatalogSearch` lo rellena) con tests.
- `app/`: cableado `buildCatalogSources(JamendoServices?)` + provider
  Riverpod; `JamendoServices.search` pasa al registro.
- `features/search/domain`: `CatalogSearchViewState` (sellado), caso de uso
  `SearchCatalog` (fuente única, sin retries), `CatalogResultItem`.
- `features/search/presentation/providers`: controlador (debounce, mínimo,
  token de generación, paginación, `loadMoreFailed`) con reloj/debounce
  inyectables.
- **Tests:** máquina de estados completa; vacío ≠ fallo; página vacía posterior
  = fin; cancelación por token; sin reintentos; atribución conservada; regla de
  arquitectura (search no importa `jamendo`).
- Sin UI, sin navegación.

### 3.2C — Pantalla de búsqueda (UX)

- `TakiSearchField` y pie/loader de lista paginada (documentados en DS).
- `SearchPage` con los seis estados, lista con `TakiSongTile`.
- Pestaña «Buscar» condicional (tras D1) y excepciones en
  `dependency_rules_test`.
- Tap = reproducir (§8). Accesibilidad básica (§12).

### 3.2D — Interacciones de resultados

- Favorito, añadir a playlist, cola (`showSongActions`), corazón en el tile.
- Medir D7 y revisar R-FAV-1/R-FAV-2; mensaje de fallo de reproducción.

### 3.2E — UI de atribución

- Acceso a la atribución por resultado (`ProviderAttribution`: proveedor,
  enlace, licencia, degradación con gracia); decidir si se necesita
  `AttributionLookup` para canciones fuera de Search.

**Corrección de reparto respecto a la sugerencia inicial:** el contrato C1 y el
registro de fuentes se mueven explícitamente a 3.2B (si no, 3.2C no tendría de
dónde sacar el proveedor ni la atribución sin acoplarse a Jamendo).

---

## Resumen de código modificado en 3.2A

Ninguno. Solo este documento.
