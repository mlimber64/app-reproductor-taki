# Fase 3.2E — Endurecimiento de datos de Search

Implementa lo que la Fase 3.2D dejó decidido: decodificador de entidades HTML
de Jamendo, deduplicación en el controlador de Search, contrato
`AttributionLookup` (con su implementación de Jamendo y su cableado) y los
textos finales D9. Sin UI nueva, sin navegación y sin tocar Player, Queue,
SQLite, `Song`, `MusicIdentity`, artwork, router ni MiniPlayer/Reproduciendo.

## 1. Objetivo

1. Que `Don&#039;t Cry` se muestre como `Don't Cry`.
2. Que una canción no aparezca dos veces en los resultados de Search.
3. Poder resolver la atribución por `MusicIdentity` aunque `SearchPage` ya no
   exista (contrato listo; **sin** UI de atribución).
4. Aplicar los textos de Search aprobados por producto.

## 2. Cambios

| Tema | Archivos |
|---|---|
| Decodificador | `features/jamendo/infrastructure/html_entities.dart` (nuevo); `jamendo_response_parser.dart` (lo usa) |
| Deduplicación | `features/search/presentation/providers/catalog_search_providers.dart` |
| Contrato de atribución | `core/domain/ports/attribution_lookup.dart`, `entities/attribution_lookup_result.dart`, `entities/attribution_lookup_failure.dart`, `services/source_attribution_lookup.dart`, `core/lookup/attribution_lookup_providers.dart` (todos nuevos) |
| Jamendo | `features/jamendo/domain/services/jamendo_attribution_lookup.dart` (nuevo) |
| Cableado | `app/jamendo_wiring.dart` (`JamendoServices.attribution`, `buildAttributionLookup`), `main.dart` (override de `attributionLookupProvider`) |
| Textos | `features/search/presentation/search_texts.dart`; `search_page.dart` (el vacío ya no lleva la consulta en el título) |

## 3. Decodificador HTML

Ubicación: **parser de la API de Jamendo** (infraestructura). Es el único punto
por el que pasan búsqueda, lookup (Favoritos/Playlists) y reproducción, así que
`JamendoTrack`, el mapper, `Song` y la atribución ya reciben texto limpio.
No hay HTML decoding en `Song`, en `core/domain`, en `SearchPage` ni en widgets.
Sin dependencias nuevas.

```
Jamendo API → parseJamendoTracks → decodeHtmlEntities (name, artist_name, album_name)
            → JamendoTrack → songFromJamendoTrack → Song → Search UI
```

Reglas de `decodeHtmlEntities`:

| Caso | Resultado |
|---|---|
| Nombradas | `&amp; &quot; &apos; &lt; &gt; &nbsp;` (sensibles a mayúsculas) |
| `&nbsp;` | un **espacio normal** (`Rock&nbsp;Music` → `Rock Music`) |
| Numéricas | decimal (`&#039;`) y hex (`&#x27;`, `&#X27;`) de un valor escalar Unicode válido (1…10FFFF sin D800–DFFF); `&#160;` da exactamente U+00A0 |
| **Una sola pasada** | `&amp;quot;` → `&quot;` (no `"`); lo decodificado no se reexamina |
| Intactas | desconocidas (`&foo;`), sin `;` (`&amp`), `&` suelto (`AT&T`), numéricas inválidas o malformadas (`&#0;`, `&#xD800;`, `&#1114112;`, `&#;`, `&#12a;`) |
| No interpreta HTML | `<b>`, `<script>`… quedan tal cual; no quita etiquetas; no toca espacios |

Campos que se decodifican: **título, artista y álbum**. No se tocan `id`,
`album_image`, `audio`, `shareurl` ni `license_ccurl` (hay tests que lo fijan).
Jamendo no expone etiquetas como texto, así que no aplica. La decodificación
ocurre **antes** de comprobar «nombre vacío» (un nombre `&nbsp;` se omite) y un
artista/álbum que solo sea espacios acaba como `null` en el mapper.

Las copias de respaldo de favoritos ya guardadas conservan el texto con
entidades; no se muestran (Favoritos muestra la `Song` resuelta por lookup) y
solo sirven para el reencuentro de canciones **locales**: no hay migración.

## 4. Deduplicación

Ubicación: **controlador de Search** (`CatalogSearchNotifier._withoutRepeats`).
Clave: **solo `MusicIdentity`** (fuente + id). No se compara título, artista,
carátula, duración ni URL. `local:42` y `jamendo:42` son identidades distintas.

- **Primera aparición gana** y se conserva el orden de llegada; vale también para
  repetidas dentro de una misma página (primera o posterior).
- La atribución que se conserva es la del elemento que se queda.
- **La paginación no cambia:** `nextOffset` sigue avanzando `offset + limit` del
  catálogo, nunca por lo visible; no se vuelve a pedir una página por tener
  menos de 20 elementos.
- **Fin de lista:** «página vacía ⇒ fin» se evalúa sobre la página **tal como
  llegó**, antes de deduplicar. Una página posterior **no vacía pero toda
  repetida** añade 0 elementos, no es `Empty`, y mantiene el `hasMore` del
  catálogo (el contrato no permite saber si hay más allá de lo que dice
  `hasMore`; no se inventó ninguna heurística). Una primera página no vacía pero
  toda repetida (`A A A`) es `Results` con un elemento, no `Empty`.
- **Sin bucles:** cada `loadMore` es una sola llamada con un `offset` nuevo; el
  fin llega por `hasMore == false` o por una página vacía. Una cadena de páginas
  repetidas avanza una a una hasta terminar.
- Consecuencia asumida: el número visible puede no ser múltiplo de 20.
- Con identidades únicas en la lista, la identidad puede usarse como clave de
  fila sin riesgo.

## 5. Atribución

Contrato (provider-agnostic, en `core`); **no** hay campos de proveedor en `Song`
ni Jamendo en `core/domain`:

```
AttributionLookup.findAll(Iterable<MusicIdentity>) → AttributionLookupResult{ found, absent }
                                                   | throws AttributionLookupFailure
```

| Situación | Resultado |
|---|---|
| Atribución encontrada (incluso incompleta) | `found[identity]` |
| Sin atribución (fuente local, fuente sin lookup registrado, canción que la fuente ya no conoce) | `absent` — **no** es un error |
| Fallo real (red, credencial, contrato roto) | `AttributionLookupFailure` — **nunca** se convierte en `absent` |

- Cada identidad pedida cae en **exactamente un** cubo. Lote de identidades de
  **varias fuentes**: `SourceAttributionLookup` (mismo patrón que
  `SourceSongLookup`) agrupa por `identity.source`, llama una vez por fuente, en
  paralelo, y cada lookup concreto solo recibe las suyas.
- Como en `SourceSongLookup`, el fallo de una fuente propaga y hace fallar el
  lote entero (no se disfraza de ausencia). Los parciales por fuente se
  decidirán con la segunda fuente real (D6).
- `SourceAttributionLookup` hace cumplir el contrato: una atribución bajo una
  identidad que no es la suya, o para una identidad no pedida, es un
  `AttributionLookupFailure`.
- **`JamendoAttributionLookup`**: reutiliza el mismo `JamendoApi` (el existente,
  con su `client_id`, parser y reintentos) y la operación en lote
  `tracksByIds`; **una** consulta para todos los ids (el cliente ya los parte en
  trozos si hace falta). La atribución es la de `JamendoTrack.attribution`. Los
  ids que no devuelve son `absent`; las identidades de otras fuentes son `absent`
  y no generan llamada.
- Cableado: `JamendoServices.attribution`, `buildAttributionLookup` y
  `attributionLookupProvider` (con override en `main.dart`). Nadie lo consume
  todavía: **no se modificaron** Reproduciendo, Favoritos ni Playlists, y no hay
  UI.
- Nada se persiste (ni atribución, ni URLs, ni licencia). No se implementó
  la caché en memoria opcional de 3.2D: cada lookup va a la API en lote.

## 6. Textos (D9)

Se aplicaron **los textos que fijó producto en esta fase** (que difieren en
algunos puntos de la propuesta de 3.2D):

| Pieza | Texto |
|---|---|
| Título / pestaña | Buscar |
| Pista del campo | Buscar canciones |
| Idle | **Buscar música** · Escribe al menos 2 caracteres para empezar. |
| Vacío | **No encontramos música** · Prueba con otro título. |
| Error | **No pudimos buscar** · Revisa tu conexión e inténtalo de nuevo. · Reintentar |
| No disponible | **Búsqueda no disponible** · Esta función no está disponible en esta versión. |
| Fallo de página siguiente | No pudimos cargar más resultados · Reintentar |
| Semántica | Buscando… · Cargando más resultados · Borrar búsqueda |

El «2» del mensaje inicial sigue saliendo de la política. El título del vacío ya
no incluye la consulta. No hay infraestructura de localización; los textos siguen
centralizados en `SearchTexts`. Ninguno menciona proveedor, API, HTTP ni
credenciales (un test lo comprueba).

## 7. Tests

| Archivo | Cubre |
|---|---|
| `test/features/jamendo/html_entities_test.dart` | nombradas, decimal, hex, apóstrofo, comillas, `&`, `<`/`>`, nbsp, varias entidades, texto normal, desconocidas, incompletas, numéricas inválidas y malformadas, Unicode válido, vacío, **una sola pasada** |
| `test/features/jamendo/jamendo_entities_parser_test.dart` | parser: campos decodificados, URLs/ids/licencia intactos, sin doble decodificación, `&nbsp;` |
| `test/features/search/catalog_search_dedupe_test.dart` | sin repetidas, intra-página, entre páginas (A B C + C D E), primera posición, misma identidad con otro título, mismo título con otra identidad, fuentes distintas, página toda repetida, offset intacto, sin bucles, atribución |
| `test/core/domain/services/source_attribution_lookup_test.dart` | enrutado, lote multi-fuente, ausente vs fallo, contrato, paralelismo, provider |
| `test/features/jamendo/jamendo_attribution_lookup_test.dart` | Jamendo: lote, ausente, ajenas, fallos, wiring |
| `test/features/search/search_texts_test.dart` y `search_page_test.dart` | textos D9 |

## 8. Mutation testing

Mutantes manuales: cada uno se aplica, se corre el subconjunto de tests y se
restaura el archivo; los de compilación inválida se cuentan aparte y no cuentan
como matados. 27 mutantes: **23 killed**, **0 survived reales**,
**1 survived esperado**, **3 compile-invalid** (no cuentan como killed).

| Área | Killed | Survived | Compile-invalid |
|---|---|---|---|
| Decodificador (`html_entities.dart`) | `amp`, `apos`, `nbsp` rotos; `&#0;` aceptado; rango `> 0x110000` (lanza `RangeError`); sustitutos aceptados; radix hex→10; desconocida eliminada en vez de intacta | — | segunda pasada recursiva (no compila) |
| Deduplicación (`catalog_search_providers.dart`) | sin deduplicar; `nextOffset` por `items.length`; fin de lista sin mirar página vacía; fin de lista según lo deduplicado | `Empty` evaluado tras deduplicar: **equivalente**, una página no vacía siempre conserva su primer elemento | clave por título (`Set<MusicIdentity>.add(String)`); orden invertido (sintaxis) |
| Enrutado de atribución (`source_attribution_lookup.dart`) | primera fuente en vez de la propia; `unrouted` perdido; atribución ajena aceptada; identidad no pedida aceptada; `absent` no contabilizado | — | — |
| Ausencia vs fallo | fallo de fuente convertido en `absent`; Jamendo: fallo→vacío | — | — |
| Jamendo lookup | sin filtro de fuente; ausentes perdidos; track ajeno aceptado; sin lote (solo 1 id) | — | — |

## 9. Arquitectura

```
features/search ──▶ core/domain ◀── app wiring ──▶ features/jamendo ──▶ core/domain
```

- `features/search` no importa Jamendo ni `app/`; `core` no menciona Jamendo;
  `Song` no cambió. La única excepción feature → feature de `search`
  (`search_page → player_providers`) sigue igual.
- El decodificador vive en `features/jamendo/infrastructure`; el contrato de
  atribución, en `core/domain`; su implementación, en `features/jamendo`.

## 10. Riesgos y trabajo pendiente

- **Texto del vacío (resuelto en el cierre):** Search solo busca por **título**
  (`name`), así que el texto es «Prueba con otro título.». Si algún día se busca
  también por artista, el texto deberá revisarse.
- Atribución: el contrato está listo, **sin consumidor**. Falta la UI
  (Reproduciendo y/o detalle) y la decisión de producto de dónde se muestra.
- El fallo de una fuente hace fallar todo el lote de atribuciones (igual que el
  de canciones); revisar con la segunda fuente (D6).
- Sin caché de atribuciones: si una pantalla la pide con frecuencia habrá que
  añadirla (en memoria, en `CachingJamendoApi`).
- Sin decodificar etiquetas ni otros campos de texto que Jamendo pudiera añadir;
  si aparecen más entidades nombradas, se amplía el mapa.
- D6 (varias fuentes) diferido; D7: Search sigue usando `PlaySongs` tal cual
  (reemplaza la cola).
