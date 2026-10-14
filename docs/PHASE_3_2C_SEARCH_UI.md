# Fase 3.2C — Pantalla de búsqueda

Primera capa de UI sobre el estado de la Fase 3.2B (`catalogSearchProvider`).
La pantalla solo presenta ese estado y le pasa lo que hace el usuario: no busca,
no hace debounce, no reintenta por su cuenta y no conoce a ningún proveedor.

## 1. Objetivo

Entrar a «Buscar», escribir, ver cargando / resultados / vacío / error /
no disponible, paginar, reintentar manualmente un fallo de página siguiente y
reproducir un resultado con un toque, conservando MiniPlayer y Reproduciendo.

## 2. Decisiones aplicadas

**D1 — pestaña «Buscar».**
- Quinto destino, **solo** si `catalogSourcesProvider.isAvailable`. Sin catálogo
  la barra conserva sus 4 destinos de siempre.
- Posición: **entre Biblioteca y Playlists** (la de 3.2A). Si se prefiere al
  final, es un cambio de una línea en `router.dart` (ramas y destinos van en el
  mismo orden).
- La disponibilidad es de la build (credenciales), así que se lee una vez en
  `routerProvider`.

**D5 — foco.**
- El campo recibe el foco tras el primer frame al entrar y el teclado se abre.
- «Entrar» = la pestaña pasa a estar activa (`TickerMode` de su rama): primera
  visita **y** cada vuelta a la pestaña. Un rebuild o cambiar la consulta **no**
  vuelve a pedir el foco.
- Al salir de la pestaña, el campo suelta el foco (el teclado no queda abierto
  sobre otra pestaña).
- Al tocar un resultado: se cierra el teclado y se reproduce. Solo toque normal.

## 3. Componentes

| Pieza | Archivo | Nota |
|---|---|---|
| `TakiSearchField` | `core/widgets/taki_search_field.dart` | Componente del Design System (§9b de `DESIGN_SYSTEM.md`). Sin lógica de búsqueda. |
| `SearchPage` | `features/search/presentation/pages/search_page.dart` | Observa `catalogSearchProvider`. |
| `SearchTexts` | `features/search/presentation/search_texts.dart` | Textos **provisionales** centralizados (pendientes de D9). |

La app no tiene infraestructura de localización (todo el texto está en español,
en el código); por eso los textos nuevos viven juntos en `SearchTexts`, para
sustituirlos de una vez. Reutiliza `TakiSongTile`, `TakiArtwork` (vía
`AlbumArtworkBuilder.reference(song.artwork)`), `TakiEmptyState`,
`TakiErrorState` y `TakiButton`. No se creó ningún tile, artwork ni color nuevo.

## 4. Estados

| Estado 3.2B | Qué se ve |
|---|---|
| Idle | `TakiEmptyState` de primer uso: «Busca música» y el mínimo **tomado de la política** (hoy 2). |
| Typing | Con resultados previos: se conservan. Sin ellos —o con un vacío/error previo—: la vista inicial (no se muestra «sin resultados» ni un error que no es de esta consulta). |
| Loading | Sin resultados previos: spinner centrado. Con resultados previos: la lista sigue visible con un avance fino (2 px, reservado siempre) arriba, sin saltos. |
| Results | Lista de `TakiSongTile`. |
| Empty | `TakiEmptyState` `noResults`, «Sin resultados para «…»», **sin** botón. |
| Failed | `TakiErrorState` con «Reintentar» → `retry()`. |
| Unavailable | `TakiEmptyState` informativo («Búsqueda no disponible»), campo deshabilitado, sin «Reintentar». |

Los resultados previos durante Loading son memoria **de la pantalla**
(`_lastResults`); se olvidan al pasar a Idle, Empty o Failed. No se cambió el
estado de 3.2B.

## 5. Paginación

- La pantalla pide `loadMore()` cuando faltan ≈ 5 filas por desplazar
  (`extentAfter < 5 × 64`), tanto al desplazar como al cambiar las métricas (una
  lista corta que no llena la pantalla también pide la siguiente). La llamada se
  difiere un microtask para no tocar el estado durante el layout.
- Solo con `loadMore == idle`: **tras un fallo no se reintenta por desplazarse**.
  Que haya más páginas y que no se esté buscando otra cosa lo vigila el
  controlador.
- Pie: cargando → spinner pequeño; fallo → «No pudimos cargar más resultados» +
  «Reintentar» (llama a `loadMore()`, que reintenta la misma página); resto →
  nada. Con una búsqueda nueva en curso el pie no se muestra.
- Una página posterior vacía es fin de lista: ni vacío ni error ni pie.

## 6. Reproducción

Tap en un resultado → `FocusScope.unfocus()` → `playSongsProvider([song], 0)` →
`notificationPermissionProvider.requestIfNeeded()` (igual que Biblioteca). La
UI no resuelve URLs ni conoce el proveedor; el audio lo resuelve el resolver ya
cableado. La fila que suena se marca como en Biblioteca. MiniPlayer y
Reproduciendo no cambian.

**D7 sigue pendiente.** `PlaySongs` siempre reemplaza la cola, así que hoy el
toque reproduce solo la canción tocada y la cola queda con esa canción. Es un
comportamiento mínimo para ejecutar el toque, no una decisión de cola; está
aislado en `SearchPage._play`.

## 7. Arquitectura

- `features/search` no importa `features/jamendo` ni `app/` (tests de 3.2B).
- **Una única excepción feature → feature nueva, mínima:**
  `search/presentation/pages/search_page.dart` →
  `player/presentation/providers/player_providers.dart` (`playSongsProvider`,
  `currentSongProvider`, `playbackStateProvider`,
  `notificationPermissionProvider`), el mismo patrón que `library_page`.
  Añadida a `_allowedCrossFeature` (ahora 7) y a `docs/ARCHITECTURE.md`. Un
  test fija que es la única de `search`.
- `app/router.dart` conoce `SearchPage` (el router de `app/` es quien compone
  features). `AppShell` pasa a recibir `hasSearch` (obligatorio).
- Los tests que montan `TakiApp` necesitan `catalogSourcesProvider`;
  `libraryOverrides` lo pone «sin catálogo» por defecto.

## 8. Tests

| Archivo | Cubre |
|---|---|
| `test/core/widgets/taki_search_field_test.dart` | render, pista, escribir, enviar, borrar (vacía, avisa, deja el foco), foco/anillo, deshabilitado, controller, alto, semántica |
| `test/features/search/presentation/search_page_test.dart` | los 7 estados, retención de resultados, reintentar, `loadMore`, fallo y reintento de `loadMore`, página vacía, tap/teclado/foco, `TickerMode` |
| `test/app/router_shell_test.dart` | 5 pestañas con catálogo, 4 sin él, índices, ruta, foco al entrar/salir, estado conservado |
| `test/architecture/dependency_rules_test.dart` | `search` solo importa el provider del Player |

Sin `sleep` arbitrarios: el debounce usa el reloj manual de 3.2B y las
respuestas pendientes se controlan con `Completer`.

## 9. Mutation testing

Mutantes manuales (script propio; cada uno se aplica, se corre el subconjunto de
tests y se restaura el archivo) sobre `SearchPage`, `router.dart` y
`TakiSearchField`: estados, retención, reintentos, `loadMore`, disponibilidad,
navegación condicionada, foco y borrado del campo.

| Resultado | Cantidad |
|---|---|
| KILLED | 70 |
| SURVIVED real | 0 |
| SURVIVED esperado (mutante de control inocuo: `Unavailable` nunca llega a Loading) | 1 |
| COMPILE/INVALID (no cuentan como killed) | 3 en una pasada intermedia (el `switch` dejaba de ser exhaustivo); se reescribieron como mutantes válidos |

Supervivientes iniciales que llevaron a cambios: guardas redundantes en la
pantalla (`hasMore`, «no se está buscando»; las vigila el controlador) y
`&& enabled` en el anillo (el `TextField` ya pierde el foco al deshabilitarse)
**se eliminaron**; se añadieron tests para el pie fallido durante una búsqueda
nueva, el olvido de resultados tras Empty/Failed/Idle, el listener del
controller viejo, el nombre del botón «Borrar búsqueda» y el alto con texto
pequeño.

No detectables sin una herramienta de fugas: que `dispose()` libere el
`FocusNode`/`TextEditingController` de la pantalla (no se muta ese código; el
test comprueba que desmontar no falla).

## 10. Validación

Ver el reporte de cierre. Prueba manual en emulador Android (AVD `Pixel_10`,
`flutter run` con la credencial por `--dart-define`, nunca en el código):

1. 5 pestañas con Jamendo disponible ✔
2. Entrar a Buscar: foco con anillo naranja y teclado abierto ✔
3. «beat»: resultados reales con artwork remoto ✔
4. Tap: teclado se cierra, suena, MiniPlayer visible, fila marcada ✔
5. Desplazamiento más allá de la primera página (más de 20 filas) ✔
6. Sin resultados («zzqxjkwv») ✔; sin red → «No pudimos buscar» + Reintentar,
   y al volver la red «Reintentar» recupera los resultados ✔
7. **No reproducido de forma controlada:** el fallo de `loadMore` (solo en tests).

El emulador `peru_api35` renderiza negro con Flutter en esta máquina (y la
build instalada con `adb install` cerraba el proceso en Pixel 10); con
`flutter run` en `Pixel_10` funcionó. Es un asunto del entorno, no de la app.

## 11. Pendientes y deuda

- **D6** (política con ≥ 2 fuentes), **D7** (cola), **D8**
  (`AttributionLookup`), **D9** (textos finales): sin resolver.
- Deuda de datos fuera de alcance: Jamendo entrega entidades HTML sin decodificar
  en algunos campos (`Bessonn&amp;sa`, `&quot;`). Se ven tal cual en la lista.
- Sin acciones por fila (⋯, favorito, playlist): 3.2D. Sin UI de atribución:
  3.2E.
- Sin deduplicación entre páginas: la lista no usa la identidad como clave.
- No hay historial de
  búsquedas.
