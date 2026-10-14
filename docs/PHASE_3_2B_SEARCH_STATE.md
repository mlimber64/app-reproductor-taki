# Fase 3.2B — Estado y controlador de la búsqueda de catálogo

Implementa la capa de **estado/control** definida en
`PHASE_3_2A_CATALOG_SEARCH_UX_ARCHITECTURE.md`. No hay UI, ni navegación, ni
cambios en el Player, SQLite, artwork o HTTP.

Decisiones aprobadas: **D2** mínimo 2 caracteres · **D3** debounce 400 ms ·
**D4** página de 20. **D1** (entrada de navegación) sigue pendiente para 3.2C.

## Piezas

| Capa | Archivo | Qué es |
|---|---|---|
| `core/domain/entities` | `catalog_provider_info.dart` | `CatalogProviderInfo(source, label)` y `UnknownCatalogSource` |
| `core/domain/entities` | `catalog_search.dart` | `CatalogSearchPage.attributions` (C1) y `attributionOf(song)` |
| `core/domain/ports` | `catalog_sources.dart` | `CatalogSources`: registro de catálogos |
| `core/domain/services` | `source_catalog_sources.dart` | `SourceCatalogSources` + `CatalogSourceRegistration` |
| `core/catalog` | `catalog_sources_providers.dart` | `catalogSourcesProvider` (se sobrescribe en `main.dart`) |
| `app` | `jamendo_wiring.dart` | `buildCatalogSources(JamendoServices?)` — único sitio donde se registra Jamendo |
| `features/search/domain` | `catalog_search_state.dart` | Estado sellado |
| | `catalog_result_item.dart` | `CatalogResultItem`, `CatalogResultPage` |
| | `catalog_search_policy.dart` | Mínimo, debounce, tamaño de página |
| | `search_scheduler.dart` | Puerto de reloj inyectable |
| | `search_catalog.dart` | Caso de uso |
| `features/search/infrastructure` | `timer_search_scheduler.dart` | Reloj real (`Timer`) |
| `features/search/presentation/providers` | `catalog_search_providers.dart` | `CatalogSearchNotifier` y providers |

Cambios fuera de `search` (necesarios y mínimos): `main.dart` añade un override
de `catalogSourcesProvider`; `JamendoCatalogSearch` rellena `attributions`
(ver §10).

## 1. State machine

```
CatalogSearchState (sellado)
  SearchIdle                                   sin búsqueda
  SearchTyping(text, previous?)                esperando el debounce
  SearchLoading(query)                         primera página en curso
  SearchResults(query, items, hasMore,
                nextOffset, loadMore)          ≥ 1 resultado
  SearchEmpty(query)                           búsqueda válida sin resultados
  SearchFailed(query, failure)                 el catálogo falló
  SearchUnavailable                            no hay ningún catálogo
```

`loadMore` ∈ `idle | loading | failed` (parte de `SearchResults`).

| Estado | Datos | Significa | **No** significa |
|---|---|---|---|
| Idle | — | No hay búsqueda (texto vacío o por debajo del mínimo) | «sin resultados» |
| Typing | `text` crudo; `previous`: último estado asentado | El usuario edita; aún no toca buscar | que haya una petición |
| Loading | `query` | Primera página en vuelo | cargar más (eso es `loadMore: loading`) |
| Results | `query`, `items`, `hasMore`, `nextOffset`, `loadMore` | Hay resultados | — |
| Empty | `query` | La búsqueda terminó bien con 0 canciones | fallo ni «sin catálogo» |
| Failed | `query`, `failure` (`CatalogSearchFailure`) | El catálogo falló en la primera página | un vacío; ni un fallo de «cargar más» |
| Unavailable | — | No hay catálogos registrados | un vacío ni un fallo |

`Empty ≠ Failed ≠ Unavailable` son tipos distintos; el controlador nunca
convierte uno en otro.

Transiciones (`setQuery` = texto cambió, `submit` = «buscar» del teclado):

| Evento | Resultado |
|---|---|
| texto bajo el mínimo / vacío | `Idle`; cancela el debounce, invalida lo que esté en vuelo y **descarta** resultados previos |
| texto válido | `Typing(text, previous)` y se programa la búsqueda |
| vence el debounce / `submit` | `Loading(query)` → `Results` / `Empty` / `Failed` |
| `loadMore()` | `Results(loadMore: loading)` → `Results(idle)` o `Results(failed)` |
| `retry()` en `Failed` | `Loading(query)` |
| sin catálogo | `Unavailable` desde el inicio; todas las operaciones son no-ops |

## 2. Query lifecycle

- El texto se envía **sin modificar** al catálogo (sin `trim`, minúsculas,
  acentos ni transliteración).
- Solo para medir el mínimo se ignoran los espacios exteriores y se cuentan
  **puntos de código** (`trim().runes.length`): `""`, `"a"`, `"  a  "`, `"ñ"` y
  `"😀"` no buscan; `"ab"`, `" ab "` y `"😀😀"` sí. No muestra error ni «sin
  resultados»: el estado es `Idle`.
- `Typing` conserva `previous` (el último `Results`/`Empty`/`Failed`) para que
  una UI mantenga la lista mientras se teclea. Desde `Idle`, `previous` es
  `null`.
- Volver a la consulta ya asentada (teclear y borrar una letra) **restaura** el
  estado sin buscar de nuevo. No se restaura un `Failed`: se vuelve a buscar.
- Repetir el mismo texto no reinicia el debounce, ni la carga en curso, ni
  relanza un `Results`/`Empty` ya mostrado.
- `submit` salta el debounce. Relanza una consulta `Empty` o `Failed`; no repite
  una con resultados o en curso.
- Entrar/salir de la pantalla: el provider no es `autoDispose`, así que el
  estado vive con la app (la pestaña, en 3.2C, lo conserva). Al reconstruirse
  el controlador (`invalidate`), vuelve a `Idle`.

## 3. Debounce

400 ms (`CatalogSearchPolicy.defaultDebounce`). El reloj es un puerto
(`SearchScheduler.schedule(delay, action) → CancelScheduled`); la
implementación real usa `Timer` (`TimerSearchScheduler`) y los tests usan un
`ManualSearchScheduler` con `advance()`. No hay `Future.delayed` en el
controlador. `a → ab → 400 ms` produce **una** búsqueda; teclear reinicia la
espera; a 399 ms todavía no busca.

## 4. Generación / cancelación

`CatalogSearch` no se puede cancelar. Cada operación que reinicia la búsqueda
(`setQuery` que cambia el texto, `submit`/`retry`, desechar el controlador)
sube un contador de **generación**. Una respuesta —o un fallo— cuya generación
ya no es la vigente se **descarta**: no se aborta ninguna petición HTTP. Cubierto
en ambos órdenes (`be` responde antes o después de `beat`), con éxito, vacío y
fallo obsoletos, y tras borrar la consulta o desechar el controlador.

## 5. Paginación

- Tamaño de página: 20 (`limit`). Primera página: `offset = 0`.
- `nextOffset = offset + limit` de la página anterior. **No** `items.length`:
  una fuente puede descartar elementos inválidos y `hasMore` se calcula sobre
  los elementos en bruto; avanzar por `items.length` repetiría elementos.
  (Corrige la nota «offset += songs.length» de 3.2A.)
- `loadMore()` solo actúa en `Results` con `hasMore` y sin otra carga en curso.
- **Una página posterior vacía es el fin de la lista**: los resultados se
  conservan y `hasMore` pasa a `false` aunque el catálogo dijera `true` (si no,
  el controlador pediría páginas vacías sin fin). Nunca pasa a `Empty`.
- Una primera página vacía es `Empty` aunque traiga `hasMore: true`.
- La siguiente página se **añade**; no reemplaza.
- Una respuesta de `loadMore` de una generación anterior (el usuario tecleó) se
  descarta.

## 6. Fallo de `loadMore`

`Results(loadMore: failed)`: los resultados, `hasMore` y `nextOffset` no cambian
y **no** se pasa a `Failed`. No hay reintento automático. Llamar a `loadMore()`
de nuevo reintenta la misma página (mismo `offset`). Si el usuario cambia de
consulta y vuelve, el `failed` se conserva en el estado restaurado.

## 7. Empty vs Failed

| Situación | Estado |
|---|---|
| Búsqueda válida, 0 canciones | `SearchEmpty` |
| `CatalogSearchFailure` en la primera página | `SearchFailed` |
| Error inesperado del catálogo | `SearchFailed` con un `CatalogSearchFailure` genérico (`cause` = tipo del error, sin detalles) |
| Fallo en una página posterior | `Results(loadMore: failed)` |
| Respuesta vacía de una página posterior | `Results` (fin de lista) |
| Sin catálogo registrado | `SearchUnavailable` |

Sin reintentos en presentation: cada operación del controlador es **una**
llamada lógica a `CatalogSearch` (verificado: un fallo = una llamada, aunque pase
el tiempo). La mitigación de la intermitencia de «éxito con 0 resultados» sigue
siendo exclusivamente de infraestructura; un vacío que sobreviva a ella se
muestra como `Empty`.

## 8. Unavailable

`searchCatalogProvider` es `null` si `CatalogSources.isAvailable` es `false`; el
controlador arranca en `SearchUnavailable` y `setQuery`/`submit`/`retry`/
`loadMore` no hacen nada (no programan nada ni llaman a nadie). Con ≥ 1 fuente
la búsqueda puede ejecutarse.

### Varias fuentes registradas — D6 sigue PENDIENTE

Con una sola fuente, se usa esa. Con **varias**, `searchCatalogProvider` toma la
**primera registrada** (`sources.available.first`). Esto es:

- un comportamiento **provisional y técnico**, solo para que el controlador
  tenga un `CatalogSearch` determinista; **no es una decisión de producto**;
- **D6 permanece pendiente**: hoy no existe ranking entre proveedores, ni
  selección manual del proveedor (ni selector visual), ni mezcla de resultados
  de varios proveedores;
- hoy solo hay un proveedor real (Jamendo), así que la regla no se ejerce en
  producción; está cubierta por un test únicamente para fijar el comportamiento
  provisional, no para consagrarlo.

La política multi-fuente (fan-out, «Todas», selector, resultados parciales)
se decidirá con la segunda fuente real.

## 9. Registro de proveedores

```
CatalogProviderInfo(source, label)       // source = la misma etiqueta que MusicIdentity.source
CatalogSources { available, isAvailable, searchIn(source) }   // UnknownCatalogSource si no existe
SourceCatalogSources(Iterable<CatalogSourceRegistration>)     // patrón de SourceSongLookup
```

- `source` es la etiqueta opaca de siempre, no un identificador nuevo; `label`
  la aporta el cableado. Ninguna lógica de proveedor.
- Una fuente repetida es un `ArgumentError` (error de configuración, no se
  elige una en silencio). El orden de registro se conserva.
- `buildCatalogSources(jamendo)` (en `app/`) registra Jamendo solo si está
  cableado; `main.dart` lo inyecta en `catalogSourcesProvider`.
- `features/search` solo ve `CatalogSources` y `CatalogSearch`.

## 10. Retención de la atribución (C1)

`CatalogSearchPage` gana `attributions: Map<MusicIdentity, ProviderAttribution>`
(por defecto vacío; cambio aditivo) y `attributionOf(song)`.
`JamendoCatalogSearch` lo rellena con `track.attribution` de cada track: **único
cambio en Jamendo** (una propiedad que ya existía, sin red extra), necesario
porque la atribución se descartaba dentro del puerto.

```
CatalogSearchPage(songs, attributions)
   → SearchCatalog → CatalogResultItem(song, attribution?)
   → SearchResults.items
```

- `Song` no cambia; `shareUrl`/`licenseUrl`/`licenseName` no se mueven.
- La atribución viaja **junto a** la canción y puede ser `null` (fuente sin
  atribución, o canción sin entrada): la UI futura debe degradar con gracia.
- Se conserva al paginar (cada página aporta la suya; las anteriores no se
  tocan) y al restaurar la consulta asentada.
- Solo en memoria. No se creó `AttributionLookup` (C1 no lo requiere).
- `song.musicIdentity` viaja en cada resultado para que 3.2D reutilice las
  acciones existentes (favoritos, playlists, cola) sin tocar repositorios.

## 11. Frontera de arquitectura

```
features/search ──▶ core abstractions ◀── app wiring ──▶ features/jamendo
```

Tests de `dependency_rules_test.dart` añadidos:

- `features/search` no importa **ninguna** otra feature (ni Jamendo);
- no importa `features/jamendo/` directamente;
- no depende de `app/`;
- ningún archivo de `lib/features/search` menciona a un proveedor concreto;
- no se añadieron excepciones feature → feature para `search`.

El test existente de `jamendo_security_test` («el core no conoce Jamendo») sigue
vigente y obligó a no nombrar a Jamendo en `core/`.

## 12. Estrategia de pruebas

| Archivo | Qué cubre |
|---|---|
| `test/features/search/catalog_search_notifier_test.dart` | Máquina de estados, mínimo, debounce, `submit`/`retry`, generación y carreras deterministas, paginación, fallo de `loadMore`, atribución, disponibilidad |
| `test/features/search/search_catalog_test.dart` | `SearchCatalog`, `CatalogSearchPage`, igualdad de estados, `TimerSearchScheduler` |
| `test/core/domain/services/source_catalog_sources_test.dart` | `CatalogProviderInfo` y `SourceCatalogSources` |
| `test/features/jamendo/jamendo_catalog_attribution_test.dart` | `JamendoCatalogSearch` conserva la atribución |
| `test/app/jamendo_wiring_test.dart` | `buildCatalogSources` |
| `test/architecture/dependency_rules_test.dart` | Frontera de `search` |
| `test/helpers/catalog_fakes.dart` | `FakeCatalogSearch`, `ManualSearchScheduler`, páginas y atribuciones falsas |

Las carreras se prueban con `Completer`s resueltos en el orden deseado, sin
esperas reales. Mutation testing: ver el reporte de cierre.

## 13. Decisiones pendientes

| # | Decisión | Estado |
|---|---|---|
| D1 | Pestaña «Buscar» como 5.º destino | Pendiente (3.2C) |
| D5 | Foco automático; doble toque en la pestaña = reset a `Idle` (hoy no existe un `clear()`; basta `setQuery('')`) | Pendiente (3.2C) |
| D6 | Política con ≥ 2 fuentes. **Pendiente.** Hoy: primera fuente registrada, provisional y técnico (no es decisión de producto); sin ranking, sin selección manual y sin mezcla | Diferida hasta la 2.ª fuente real |
| D7 | Cola al tocar un resultado y coste de resolver toda la cola | Medir en 3.2D |
| D8 | `AttributionLookup` para canciones fuera de Search | Evaluar en 3.2E |
| D9 | Copy final (títulos, mensajes, hint) | 3.2C |

## 14. Límites conocidos

- El estado vive mientras viva el `ProviderContainer`; no hay historial ni
  persistencia de búsquedas (por diseño).
- `hasMore` es una pista: puede haber una última página vacía (cubierto).
- `SearchFailed` no distingue red / credencial / parámetros (el contrato no lo
  hace).
- No hay deduplicación entre páginas: si el catálogo cambia entre peticiones,
  podría repetirse una canción. Una UI con claves por identidad deberá tenerlo
  en cuenta (riesgo para 3.2C).
