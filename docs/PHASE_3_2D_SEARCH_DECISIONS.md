# Fase 3.2D — Decisiones de Search y endurecimiento (arquitectura)

Fase **de decisión y documentación**: no cambia código de producción ni tests,
ni UI, navegación, Player, Queue, SQLite, `Song`, `MusicIdentity`, artwork ni
Jamendo. Todo lo que requiere código queda descrito como trabajo de una fase
futura (§11).

Convenciones: **Decidido** = decisión técnica tomada aquí, dentro de lo que ya
aprobó el producto. **Recomendado** = propuesta con evidencia, pendiente de
confirmación de producto. **Diferido** = no hay evidencia para decidir.

---

## 0. Estado de implementación (actualizado en la Fase 3.2E)

| Tema | Estado |
|---|---|
| Decodificador de entidades HTML (Jamendo) | **Implementado** en el parser de Jamendo (`html_entities.dart`), sin dependencia nueva |
| Deduplicación entre páginas | **Implementada** en el controlador de Search, por `MusicIdentity`, sin tocar la paginación |
| Contrato `AttributionLookup` | **Implementado** (`core/domain`): puerto, `AttributionLookupResult`, `AttributionLookupFailure`, `SourceAttributionLookup`, `attributionLookupProvider` |
| `JamendoAttributionLookup` | **Implementado** y cableado en `app/` (sin UI) |
| Textos D9 | **Aplicados** (con los textos que fijó producto, ver `PHASE_3_2E_SEARCH_DATA_HARDENING.md`) |
| D6 | **Diferido** (segundo proveedor real) |
| D7 | **Resuelto en 3.2F**: el tap mantiene `PlaySongs` (reemplaza la cola); las acciones explícitas (⋯ / pulsación larga → «Reproducir a continuación», «Añadir a la cola», favorito, playlist) usan el `showSongActions` existente |
| D8 | `AttributionLookup` implementado (3.2E); **atribución presentada en Reproduciendo (3.2F)**. Ver `PHASE_3_2F_ATTRIBUTION_AND_SONG_ACTIONS.md` |

Refinamiento del contrato de atribución respecto a §4: el resultado distingue
**explícitamente** `found` y `absent` (cada identidad pedida cae en exactamente
uno), en lugar de «ausente = no aparece en el mapa»; un **fallo** sigue siendo
una excepción (`AttributionLookupFailure`) y nunca se disfraza de `absent`.
No se implementó la caché en memoria de atribuciones en `CachingJamendoApi`
(era opcional): cada lookup va a la API en lote.


## 1. Estado actual

| Tema | Estado hoy (verificado en el código) |
|---|---|
| Fuentes | Un único `CatalogSource` real (Jamendo), registrado desde `app/jamendo_wiring.dart` en `CatalogSources`. |
| Selección de fuente | `searchCatalogProvider` usa `sources.available.first` (provisional, técnico; no es decisión de producto). |
| Contrato | `CatalogSearchQuery{text, artist, tag, limit, offset}` **sin `source`**; `CatalogSearchPage{songs, hasMore, attributions}`; un fallo es `CatalogSearchFailure` (sin parciales por fuente). |
| Reproducir | `SearchPage._play` → `PlaySongs([song], 0)` → `setQueue` reemplaza la cola. |
| Atribución | `JamendoCatalogSearch` rellena `CatalogSearchPage.attributions`; `CatalogResultItem(song, attribution)` la conserva **solo en memoria**; la UI aún no la muestra. |
| Textos | Centralizados en `SearchTexts` (provisionales). Sin infraestructura de localización. |
| Entidades HTML | `JamendoTrack.name/artistName/albumName` se guardan **tal como llegan** (`_parseTrack` no decodifica); se ven `&amp;`, `&quot;`, `&#039;`. |
| Duplicados | `SearchResults.items` se concatena sin deduplicar. |
| Arquitectura | `features/search` importa solo `core` (+ su propio código) y, en `search_page.dart`, `player_providers.dart`. Ninguna mención a Jamendo en `lib/core` ni en `lib/features/search` (lo comprueban tests). |

---

## 2. D6 — Varias fuentes de catálogo

### Qué ya soporta la arquitectura

- `CatalogSources` enumera fuentes y devuelve `searchIn(source)`; `MusicIdentity.source`
  ya distingue el origen de cada canción, así que **no hay colisiones de
  identidad entre proveedores**.
- `SearchCatalog` recibe **un** `CatalogSearch` y es agnóstico; el controlador
  no sabe cuál es.
- Lo que **no** existe y habría que añadir (siempre de forma aditiva): una
  fuente elegida en el estado del controlador, un cursor de paginación por
  fuente y fallos parciales en la página.

### Alternativas

| | A. Selector | B. «Todos» (fan-out) | C. Default + selector | D. Combinados (fan-out + mezcla/ranking) | E. Default + «buscar también en…» |
|---|---|---|---|---|---|
| **UX** | El usuario elige fuente antes/durante la búsqueda | Una lista, sin elegir | Busca en la default; puede cambiar | Una lista mezclada | Busca en la default; una acción opcional amplía a otras |
| **Arquitectura** | `source` en el estado del controlador → `searchIn(source)`. Sin cambios en core | Un `CatalogSearch` compuesto (`FanOutCatalogSearch`) que implementa el mismo puerto | Igual que A + fuente por defecto en la política | B + capa de mezcla/ordenación | A para la primera pasada; segunda llamada a otra fuente bajo demanda |
| **Complejidad** | Baja | Alta | Baja–media | Muy alta | Media |
| **Paginación** | La de la fuente (offset/limit actual) | **Un offset no basta**: cada fuente avanza distinto → cursor por fuente (en el controlador o un cursor opaco en la página) | La de la fuente activa | Igual que B + reglas de mezcla (la página N depende de todas) | La de cada fuente por separado |
| **Orden** | El de la fuente | Concatenar por fuente o intercalar | El de la fuente | Requiere criterio de ranking entre catálogos con relevancias incomparables | El de cada fuente |
| **Errores parciales** | No aplica (una fuente) | Hay que mostrar «resultados de X, falló Y»: `CatalogSearchPage` necesita fallos por fuente | No aplica | Igual que B | Un fallo afecta solo a la acción ampliada |
| **Identidad** | `MusicIdentity` ya basta | Basta (incluye la fuente) | Basta | Basta; **«la misma canción» en dos fuentes es otro problema** (no lo resuelve `MusicIdentity`) | Basta |
| **Atribución** | Por canción, ya viaja en la página | Cada fuente aporta la suya (mapa por identidad) | Igual | Igual | Igual |
| **Coste de requests** | 1 por búsqueda/página | **N por búsqueda/página** (una por fuente) | 1 | N | 1 (+1 si amplía) |
| **Si una fuente falla** | Falla la búsqueda (hoy) | Degradar: mostrar el resto + aviso; o fallar todo | Falla la búsqueda; el usuario puede cambiar de fuente | Igual que B | La principal manda; la ampliación falla sola |

### Decisión

**Diferida hasta disponer de un segundo proveedor real.** Con una sola fuente
cualquier opción sería diseño especulativo (ranking, mezcla, cursores) sin
evidencia de cómo se comportan dos catálogos reales (calidad de relevancia,
latencia, límites, licencias).

**Decidido (técnico):**

- La regla «primera fuente registrada» **sigue siendo provisional** y está
  documentada como tal; no es política de producto.
- Ninguna alternativa queda bloqueada: el registro es neutral, la UI no nombra
  proveedores, no hay `if (provider == …)` y ningún tipo de proveedor entra en
  `core`. No se diseña ranking.
- Cuando llegue la segunda fuente, la **primera** pregunta de producto es
  «¿una lista o una lista por fuente?» (B/D frente a A/C/E). Las extensiones
  aditivas necesarias (fuente en el estado, cursor por fuente, fallos
  parciales) están identificadas arriba.

---

## 3. D7 — Reproducir un resultado y la cola

### Hechos verificados

- `PlaySongs.call(songs, index)` → `AudioPlayerPort.setQueue` + `play`. El
  adaptador resuelve **todas** las canciones de la cola a la vez
  (`Future.wait` en `_toSources`).
- Jamendo: `JamendoAudioCache` guarda la URL **en memoria**, TTL 10 min,
  capacidad 500. Una búsqueda deja las URLs en caché; si expira, el resolver
  hace **una consulta `tracksByIds` por canción**.
- Una canción que no se puede resolver o abrir se convierte en una fuente no
  reproducible: se emite `PlaybackError` y el reproductor salta a la siguiente.
- Existen `PlayNext` y `AddToQueue` (menú de acciones `showSongActions`). **No
  existe** un caso de uso «reproducir esta ya conservando la cola».

### Alternativas

| | A. Solo la tocada, reemplaza la cola (**actual**) | B. La tocada + cola con los resultados | C. La tocada y se conserva la cola | D. A + acción separada «Agregar a la cola» |
|---|---|---|---|---|
| **UX** | Simple y predecible; al acabar, se detiene | Estilo «radio»: sigue con el resto de resultados | No interrumpe lo que había, pero ¿qué suena y qué se pierde? | Control explícito |
| **Coste de resolver** | 1 canción | Hasta N canciones (20, 40, … según páginas cargadas) en paralelo | 1 | 1 por acción |
| **URLs remotas / caché** | La URL está en caché (la búsqueda acaba de traerla) | Dentro de 10 min: sin consultas. Pasados 10 min: **N consultas paralelas** (y los reintentos de infraestructura multiplican) | Igual que A | Igual que A |
| **No reproducible** | Salta: no hay siguiente → se detiene | Salta a la siguiente (mejor), pero errores en cascada si falla la caché | Igual | Igual |
| **MiniPlayer / Reproduciendo** | Sin cambios | Sin cambios; la cola crece | Cola mixta local+remota | Sin cambios |
| **Favoritos / Playlists** | Sin efecto | Sin efecto | Sin efecto | Compatible: son acciones de `showSongActions` |
| **Cola actual (Cola)** | Se pierde al tocar | Se pierde y se sustituye | Se conserva | Se conserva |
| **Trabajo** | Ninguno | Medir; decidir si encolar solo hasta la tocada o también los siguientes | **Player nuevo** (insertar + saltar) | Menú ⋯ / pulsación larga con `showSongActions` (ya existe) |

### Decisión

**Search usa el comportamiento existente de `PlaySongs`; D7 sigue pendiente si
se desea una semántica específica para resultados de búsqueda.** No se toca
Player, Queue, `TakiAudioHandler`, `PlaybackResolver`, `SourcePlaybackResolver`,
`setQueue` ni `player_providers`.

**Recomendado:** mantener A y entregar D (acciones por fila con el
`showSongActions` existente: «reproducir a continuación», «agregar a la cola»,
favorito, playlist) en la fase de acciones (§11). B es una opción de producto
legítima, pero **solo tras medir** el coste de resolver la cola con la caché
caducada; C exige trabajo de Player y no se recomienda ahora.

---

## 4. D8 — Atribución de proveedor

### Requisito (documentado en 3.1B/3.1C)

Los términos de Jamendo piden atribución con enlace directo a la pista y
licencia **por canción**. `ProviderAttribution` (core, neutral) ya modela
`identity`, `providerName`, `pageUrl`, `licenseUrl`, `licenseName` y su carácter
**opcional/incompleto**. `Song` **no** la lleva y no debe llevarla.

### Problema

La atribución hoy llega **solo con una página de búsqueda** y vive en memoria
mientras la lista exista. Pero una canción de Jamendo puede:

- guardarse en Favoritos o en una playlist (se persiste **identidad**, no
  atribución) y reproducirse días después;
- estar en la cola o en Reproduciendo sin que Search exista.

La atribución **no puede depender de que la lista de búsqueda siga viva.**

### Alternativas

| | Qué es | ¿Cubre Favoritos/Playlists/Now Playing tras cerrar Search? | Veredicto |
|---|---|---|---|
| A | Solo en `CatalogSearchPage` | No | Insuficiente |
| B | Asociada al resultado mientras dure Search (**ya implementado**, 3.2B) | No | Útil, pero solo dentro de Search |
| C | `AttributionLookup`: `MusicIdentity → ProviderAttribution?` | **Sí**, para cualquier identidad | Necesario |
| D | Acceso desde acciones de canción / detalle | Depende de C fuera de Search | Es **dónde se muestra**, no de dónde sale |
| E | Visible en Reproduciendo | Depende de C | Idem |
| **F** | **B dentro de Search + C para todo lo demás; D/E son superficies de UI** | Sí | **Recomendado** |

### Decisión

**Recomendado F.** Search sigue usando la atribución que ya trae el resultado
(cero red extra) y se añade un puerto por identidad para el resto de la app.
**Justificado** (no es opcional): sin él, Favoritos, Playlists, la cola y
Reproduciendo no tienen forma de obtener la atribución.

### Contrato propuesto (provider-agnostic, en `core`)

```
// core/domain/ports/attribution_lookup.dart
abstract interface class AttributionLookup {
  /// Atribución de cada identidad que la fuente puede dar. Una identidad sin
  /// atribución (fuente local, fuente sin atribución, canción desconocida)
  /// simplemente NO aparece en el mapa: no es un error.
  Future<Map<MusicIdentity, ProviderAttribution>> findAll(
      Iterable<MusicIdentity> identities);
}
```

| Pregunta | Respuesta |
|---|---|
| **Quién lo implementa** | Cada fuente: Jamendo (`JamendoAttributionLookup`, vía `tracksByIds` → `track.attribution`). La fuente local no tiene: devuelve vacío. |
| **Dónde vive** | Puerto y router en `core/domain` (`AttributionLookup`, `SourceAttributionLookup`); implementación en `features/jamendo/domain/services`; provider en `core/` (como `songLookupProvider`) y cableado en `app/`. |
| **Cómo se registra** | Igual que `SourceSongLookup`: mapa `source → AttributionLookup` en el wiring de `app/`. Una fuente **sin** registro → sus identidades no aparecen (no se inventa nada). |
| **Sin atribución** | La UI recibe `null` / ausencia y degrada con gracia (proveedor sin enlace, «licencia no disponible»), como ya dicta `ProviderAttribution`. |
| **Por `MusicIdentity`** | Sí. Por lotes (mismo motivo que `SongLookup`: una llamada para muchas). |
| **Fallos** | Un fallo transitorio se lanza como excepción propia (`AttributionLookupFailure`), **no** como «sin atribución» (misma distinción que `SongLookupFailure` vs `missing`). |
| **Persistencia** | **Ninguna.** No se persiste atribución (ni URLs, ni licencia). Solo memoria/caché de sesión. |
| **No cambia** | `Song`, `MusicIdentity`, SQLite, `FavoritesRepository`, `PlaylistRepository`. Sin campos de Jamendo en `core`. |

**Optimización interna de Jamendo (detalle de implementación, no de contrato):**
`CachingJamendoApi` ya observa cada `JamendoTrack` que pasa; puede conservar su
atribución en memoria (como hace con la URL de audio) para que el lookup acierte
sin red cuando el track ya se vio en esa sesión. Si no está, una consulta
`tracksByIds` (la 3.1B ya preveía «una consulta por pista cuando se abra el
detalle»).

### Dónde se muestra (decisión de producto, pendiente)

Mínimo razonable: **Reproduciendo** (siempre hay una canción actual, siempre hay
identidad) y/o **detalle/acciones de canción**. Search puede añadir una
indicación por fila usando la atribución ya cargada. Qué superficie(s) y con qué
nivel de detalle es una **decisión de producto** y no bloquea el puerto.

---

## 5. D9 — Textos finales de Search

### Auditoría y propuesta

Criterios: corto, natural, no técnico, sin «Jamendo/API/proveedor», sin
alarmismo; coherente con el tono actual («No pudimos leer tu música», «No
encontramos canciones»). Títulos sin punto final; mensajes con punto.

| Texto | Hoy | Propuesta |
|---|---|---|
| Título (AppBar y pestaña) | Buscar | **Buscar** (sin cambio) |
| Pista del campo | Buscar canciones | **Buscar canciones** (sin cambio; la consulta busca por título) |
| Idle — título | Busca música | **Busca música** (sin cambio) |
| Idle — mensaje | Escribe al menos 2 caracteres para empezar. | **Escribe al menos 2 caracteres.** (valor tomado de la política) |
| Loading (semántica) | Buscando… | **Buscando…** (sin cambio) |
| Vacío — título | Sin resultados para «x» | **Sin resultados para «x»** (sin cambio) |
| Vacío — mensaje | Prueba con otras palabras o revisa la ortografía. | **Prueba con otro título o revisa la ortografía.** (la búsqueda es por título) |
| Error — título | No pudimos buscar | **No pudimos buscar** (sin cambio) |
| Error — mensaje | Hubo un problema al consultar el catálogo. Inténtalo de nuevo. | **Revisa tu conexión e inténtalo de nuevo.** (quita «catálogo»; la causa más común) |
| Reintentar | Reintentar | **Reintentar** (sin cambio) |
| No disponible — título | Búsqueda no disponible | **Búsqueda no disponible** (sin cambio) |
| No disponible — mensaje | La búsqueda de catálogo no está disponible en este momento. | **La búsqueda en línea no está disponible en esta versión.** (es una condición de la build, no un fallo pasajero) |
| Fallo de página siguiente | No pudimos cargar más resultados | **No pudimos cargar más resultados** (sin cambio) + **Reintentar** |
| Cargando más (semántica) | Cargando más resultados | **Cargando más resultados** (sin cambio) |
| Borrar | Borrar búsqueda | **Borrar búsqueda** (sin cambio) |

**Por qué «Revisa tu conexión» y no un mensaje genérico:** `CatalogSearchFailure`
no distingue la causa; la red es la causa dominante y accionable. Si más
adelante el contrato distingue causas, el texto podrá variar.

**Hueco de accesibilidad detectado (no de textos):** 3.2A previó anunciar «N
resultados» al terminar; no está implementado. Candidato para la fase de
accesibilidad/acciones.

### Aplicación

No se aplica en esta fase (solo propuesta). Aplicarla es editar las constantes
de `SearchTexts` y las **pocas cadenas literales** que los tests de
`search_page_test.dart` comparan sin pasar por la constante
(«Escribe al menos 2 caracteres para empezar.», «Sin resultados para …»). No hay
sistema de localización; no hace falta crearlo para esto.

---

## 6. Entidades HTML de Jamendo

### Observado

`Bessonn&amp;sa`, `Energetic Upbeat Rock &quot;Flaring…`, `Don&#039;t Cry`. El
texto llega codificado desde la API; `_parseTrack` lo guarda tal cual.

### Dónde normalizar

| Capa | ¿Sirve? | Motivo |
|---|---|---|
| **Parser de la API** (`jamendo_response_parser.dart`, infraestructura) | **Sí — recomendado** | Es el **único** punto por el que pasan búsqueda, lookup (Favoritos/Playlists) y reproducción. «Parsear en el borde»: `JamendoTrack` queda ya limpio y todo lo de aguas abajo (mapper, `Song`, atribución) lo hereda. |
| Mapper (`songFromJamendoTrack`) | Posible | Cubriría `Song` pero dejaría `JamendoTrack` con texto sucio; hay que acordarse de cada consumidor. |
| Dominio / `Song` / core | **No** | Es un defecto de **un** proveedor; `Song` es universal. |
| Presentation | **No** | Arregla un síntoma por pantalla y no los demás consumidores (Favoritos, cola, Reproduciendo, notificación). |

### Qué decodificar y con qué

- Campos: `name`, `artist_name`, `album_name` (texto para mostrar). **No** URLs,
  ids ni licencia.
- Alcance: **un decodificador propio, pequeño y aislado** en
  `features/jamendo/infrastructure/` que soporte: entidades **numéricas**
  decimales y hexadecimales (`&#039;`, `&#39;`, `&#x27;`) y las nombradas
  `&amp; &quot; &apos; &lt; &gt; &nbsp;`. Una sola pasada, de izquierda a
  derecha: **no recursivo** (`&amp;quot;` → `&quot;`, no `"`). Lo desconocido
  (`&foo;`), un `&` suelto (`AT&T`) y los numéricos inválidos (`&#0;`,
  surrogates, fuera de rango) **se dejan intactos**.
- Dependencia: **ninguna nueva**. `html_unescape` decodificaría ~2 200 entidades
  nombradas que no aparecen y añadiría una dependencia (cada dependencia nueva es
  una decisión aparte; no se permiten upgrades en esta fase). Si algún día se
  observan más entidades nombradas, se añaden al mapa o se reevalúa el paquete.
- Orden: decodificar **antes** de la comprobación «nombre vacío» del parser
  (`&nbsp;` solo debe contar como vacío).

### Efectos laterales

- Los favoritos guardados guardan una copia de respaldo con el título tal como
  llegó. Hoy esa copia **no se muestra** (Favoritos muestra la `Song` resuelta
  por lookup, que sí quedará decodificada) y solo sirve para el reencuentro de
  canciones **locales**; no hay que migrar nada.
- No cambia `MusicIdentity` ni el esquema.

### Tests necesarios (fase de implementación)

Decodificador: cada entidad anterior; hex y decimal; mayúsculas en hex;
no recursivo; desconocida, `&` suelto y numéricos inválidos intactos; sin `;`;
cadena vacía. Parser: un fixture con entidades en `name/artist_name/album_name`
(y que `audio`/`shareurl` no se toquen); un nombre `&nbsp;` se omite como vacío.
Integración: el `Song` de búsqueda y el de lookup salen decodificados.

**No se implementa en esta fase:** aunque es pequeño y aislado, toca el parser
de Jamendo (fuera del alcance permitido). Se hace primero en la siguiente fase.

---

## 7. Duplicados entre páginas

### Dónde deduplicar

| Opción | Evaluación |
|---|---|
| A. Adaptador del proveedor | Es **sin estado** entre llamadas: no ve las páginas anteriores. Solo podría limpiar duplicados dentro de su propia página. |
| B. `CatalogSearch` | Igual que A (una llamada = una página). Útil solo intra-página. |
| **C. Controlador de Search** | **Recomendado.** Es quien acumula las páginas y puede descartar identidades ya vistas. Aplica a **cualquier** proveedor y a la mezcla futura (D6). |
| D. UI | Demasiado tarde: el estado ya está sucio y cada consumidor lo repetiría. |

### Reglas recomendadas (para la fase de implementación)

- Clave: `MusicIdentity` (incluye la fuente, así que dos proveedores nunca
  chocan; «la misma canción» en dos proveedores sigue siendo otro problema).
- Se **conserva la primera aparición** y el orden de llegada; sirve igual para
  duplicados **dentro** de una misma página.
- **No cambia la paginación**: `nextOffset` sigue avanzando por `limit`, nunca
  por `items.length` (ya es así) y `hasMore` sigue el del catálogo.
- **Fin de lista**: la regla «página vacía ⇒ fin de lista» se evalúa sobre la
  página **cruda, antes de deduplicar**. Una página no vacía pero toda
  duplicada **no** es fin de lista: añade 0 elementos y mantiene `hasMore`.
- Consecuencia asumida: el número visible puede no ser múltiplo de 20.
- Efecto en UI: con identidades únicas en la lista, la identidad puede usarse
  como `ValueKey` de fila sin riesgo.

Tests: duplicado entre páginas, duplicado intra-página, página toda duplicada
(sin fin de lista), `nextOffset` intacto, atribución del primero conservada.

**No se implementa en esta fase** (pedido explícito).

---

## 8. Revisión de arquitectura

```
features/search ──▶ core/domain (puertos, entidades) ◀── app (wiring) ──▶ features/jamendo
```

| Comprobación | Resultado |
|---|---|
| `features/search` sin Jamendo, `app/`, HTTP ni modelos de proveedor | Cumple (tests de `dependency_rules_test`, incluida la búsqueda de la palabra «jamendo» en `lib/features/search`) |
| `lib/core` sin Jamendo | Cumple (`jamendo_security_test`) |
| Selección de fuente en la UI | Ninguna: `SearchPage` no sabe de fuentes |
| Excepción `search_page → player_providers` | **Se mantiene.** Es la **mínima** necesaria: `SearchPage` necesita `playSongsProvider`, `currentSongProvider`, `playbackStateProvider` y `notificationPermissionProvider`, y esos providers son la API pública de `player`. Es el mismo patrón que `library_page`/`favorites_page`/`playlist_detail_page`. Eliminarla exigiría mover esa API a `core` (puertos + providers de reproducción), un refactor mayor que beneficiaría a las cuatro pantallas y no corresponde a Search. Las acciones por fila **no** añadirán otra: `showSongActions` se inyecta desde el router (`app/`). |

Sin cambios de arquitectura necesarios en esta fase.

---

## 9. Decisiones

### Decididas (técnicas)

| # | Decisión |
|---|---|
| D6 | La arquitectura **no bloquea** ninguna alternativa; «primera fuente» sigue provisional; no hay ranking. |
| D7 | Search usa el comportamiento existente de `PlaySongs` (A). Sin cambios de Player/Queue. |
| D8 | Contrato **provider-agnostic** definido: `AttributionLookup` por identidad, por lotes, solo en memoria; ausencia ≠ error; fallo ≠ ausencia. |
| HTML | Normalizar en el **parser de Jamendo**, decodificador propio, sin dependencia, no recursivo. |
| Duplicados | Deduplicar en el **controlador de Search** por `MusicIdentity`, primera aparición, sin tocar la paginación. |
| Arquitectura | Excepción `search_page → player_providers` justificada y se mantiene. |

### Recomendadas (esperan confirmación de producto)

| # | Recomendación |
|---|---|
| D7 | Mantener A; añadir D (acciones «reproducir a continuación / agregar a la cola») con `showSongActions`. Considerar B solo tras medir. |
| D8 | Mostrar la atribución al menos en **Reproduciendo** y/o detalle de canción. |
| D9 | Aplicar la tabla de textos de §5. |

### Diferidas

| # | Hasta cuándo |
|---|---|
| D6 | Un segundo proveedor real. |
| Aplicar D9 en código | Aprobación de los textos. |

---

## 10. Cosas que requieren decisión de producto

1. **D6:** cuando exista el 2.º proveedor, ¿una lista unificada o una lista por
   fuente?
2. **D7:** ¿se quiere que tocar un resultado construya una cola con los
   resultados (B)? Si no, se mantiene A.
3. **D8:** ¿en qué superficie(s) se muestra la atribución y con qué detalle?
4. **D9:** ¿se aprueban los textos de §5?

---

## 11. Consecuencias para las siguientes fases

Reparto propuesto (renumera las subfases de 3.2A, que ya se cubrieron en parte):

| Fase | Contenido | Código |
|---|---|---|
| **Endurecimiento de datos** | Decodificador HTML en el parser de Jamendo + deduplicación en el controlador (con tests). Pequeña, sin UI | Parser Jamendo, `CatalogSearchNotifier` |
| **Atribución** | `AttributionLookup`, `SourceAttributionLookup`, `JamendoAttributionLookup`, provider, caché de atribución en `CachingJamendoApi`; luego la UI en la(s) superficie(s) que apruebe producto | `core`, `jamendo`, `app`, UI |
| **Acciones por fila** | `onLongPress`/⋯ con `showSongActions` inyectado desde el router (cola, favorito, playlist). Corazón en el tile. Revisar R-FAV-1 (un fallo de fuente tumba todo el lote de Favoritos) | `SearchPage`, router |
| **Textos y accesibilidad** | Aplicar D9; anunciar «N resultados» | `SearchTexts`, `SearchPage` |
| **Segunda fuente** | Resolver D6 con evidencia real | Controlador/registro |

Impacto de lo decidido aquí en esas fases:

- Nada de lo implementado hasta 3.2C tendrá que rehacerse: `CatalogSources`,
  el controlador y `CatalogResultItem` ya admiten las extensiones aditivas
  descritas.
- `SearchTexts` y `_play` son los puntos aislados para D9 y D7.
- No se añade ninguna excepción feature → feature nueva en las fases previstas.

---

## 12. Cambios en esta fase

Solo este documento. Sin código, sin tests nuevos, sin dependencias.
