# Fase 3.2F — Atribución en Reproduciendo + acciones de canción desde Search

## 1. Objetivo

1. Mostrar el origen y la licencia de la canción que suena (Reproduciendo), usando
   el contrato provider-agnostic `AttributionLookup` (3.2E).
2. Dar a los resultados de Search las acciones de canción que ya existen
   (⋯ / pulsación larga), sin crear un segundo sistema.

No cambia: `PlaySongs`, Player, cola, `TakiAudioHandler`, resolvers, SQLite,
`Song`, `MusicIdentity`, paginación/debounce de Search, D6.

## 2. UX

- **Tap** en un resultado: reproduce (`PlaySongs`), como antes. No construye cola.
- **⋯** (y pulsación larga): abre `showSongActions` (el menú de siempre).
- **Reproduciendo**: bajo el botón «Cola», una sección secundaria y compacta
  (caption en `textSecondary`, botones `tertiary`), sin tokens nuevos:
  `Origen · <proveedor>`, `Licencia · <nombre>` y `Ver canción` / `Ver licencia`.
  Cada pieza aparece **solo si existe**: sin `licenseName` no hay línea de
  licencia; sin `pageUrl`/`licenseUrl` (o si no son http/https) no hay botón.
  Con atribución ausente no se reserva ni se dibuja nada.

## 3. Acciones de canción

`SearchPage` recibe `ShowSongActions onSongActions` por constructor (como
Biblioteca/Favoritos/Playlist); el router le pasa `showSongActions`. Search no
importa `app/` ni Jamendo. Las acciones son las del menú existente, sin
política nueva: **Reproducir a continuación, Añadir a la cola, Favorito, Añadir a
una playlist**. Con una canción `jamendo:<id>`: el favorito y la entrada de
playlist guardan `source + external_id` (sin `path`, no se convierte en local) y
la cola recibe la misma `Song` (tests en `song_actions_remote_identity_test.dart`).
Un fallo de reproducción usa el comportamiento existente (sin textos de proveedor).

## 4. Atribución

- `attributionProvider` (`features/player/.../attribution_providers.dart`):
  `FutureProvider.autoDispose.family<ProviderAttribution?, MusicIdentity>` sobre
  `attributionLookupProvider.findAll([identity])`.
- Estados: *loading* → nada; *found* → sección; *absent* (`data(null)`) → nada;
  *failed* (`AsyncError`) → nada, sin error visible ni bloqueo. El fallo **no** se
  convierte en ausencia en el provider (test lo fija); es la pantalla la que decide
  no mostrarlo.
- `Song` no cambia y no lleva campos de proveedor.
- Sin caché nueva ni persistencia. Si las consultas resultan caras, se puede
  añadir una caché en memoria (p. ej. en `CachingJamendoApi`) más adelante.

## 5. Ciclo de vida (respuesta tardía)

La familia está **por identidad**: A y B son entradas distintas; una respuesta
tardía de A no puede escribirse en la entrada de B. Además la sección descarta
una atribución cuya `identity` no sea la de la canción actual. Tests: A→B, B
responde, A responde tarde → solo B (widget y Reproduciendo completo).

## 6. Enlaces

`core/domain/services/external_url.dart` (`openableUrl`, `openableUrlFromText`):
solo `http`/`https` con host, sin espacios, sin reescribir. `ExternalLinkOpener`
(puerto) + `UrlLauncherLinkOpener` (`core/links`, `url_launcher`, navegador del
sistema, nunca lanza). Si no se abre: SnackBar «No se pudo abrir el enlace».
Dependencia nueva: `url_launcher ^6.3.2` (no había infraestructura de enlaces) y
`<queries>` http/https en `AndroidManifest.xml`.

### Auditoría de `url_launcher` y cobertura

- No existía infraestructura equivalente: el único `MethodChannel` del proyecto
  es el de MediaStore (audio). La dependencia solo se usa en
  `core/links/external_link_providers.dart`, para los enlaces de atribución.
- Es la vía estándar para abrir una URL externa; sin ella habría que escribir un
  canal nativo propio. Resuelve a `url_launcher 6.3.2` / `url_launcher_android
  6.3.30` (sin actualizar nada).
- `<queries>` http/https: **solo es imprescindible para `canLaunchUrl`**, que no
  se usa (se llama a `launchUrl` directamente, que devuelve `false` si no hay app).
  Es por tanto configuración prescindible; se deja hasta el smoke test en
  Android y se puede quitar después si el enlace abre bien sin ella.
- **Unit tests** cubren la política (`openableUrl*`: esquemas, host, espacios,
  vacío, sin reescritura), que `UrlLauncherLinkOpener` rechaza esquemas no
  http(s) sin tocar la plataforma, y la UI (qué botón sale y a qué URL llama el
  `ExternalLinkOpener` falso).
- **Dependiente de plataforma** (sin test automático, por inestable bajo
  `testWidgets`): la llamada real a `launchUrl` y su captura de errores. Se valida
  con el smoke test en Android.

## 7. Accesibilidad

Botones con etiqueta semántica: «Ver «<título>» en <proveedor>» y «Ver la licencia
de «<título>»». El ⋯ de la fila usa la etiqueta compartida de `TakiSongTile`
(«Más opciones»); la fila ya anuncia el título, pero el ⋯ **no** repite el título
(ver §10).

## 8. Arquitectura

`features/player` no importa ni menciona Jamendo (test nuevo). `features/search` →
`core` (+ la excepción `search_page → player_providers` ya existente). Sin
excepciones nuevas. `Song` sin campos de proveedor.

## 9. Tests y validación

| Qué | Dónde |
|---|---|
| Search: tap reproduce / ⋯ y long-press abren acciones con la identidad correcta | `search_page_test.dart` |
| Acciones con identidad `jamendo:123` | `test/app/song_actions_remote_identity_test.dart` |
| Sección de atribución (found/absent/fallo, nulos, URLs, A/B) | `attribution_section_test.dart` |
| Provider (found/absent/fallo≠ausencia/familia) | `attribution_providers_test.dart` |
| Reproduciendo (integración, no bloquea, layouts) | `now_playing_page_test.dart` |
| URLs | `external_url_test.dart` |
| Arquitectura | `dependency_rules_test.dart` (12) |

Antes: 1476. Después: 1524 (1 saltado). `flutter analyze` limpio; arquitectura
12/12; `flutter build apk --debug` OK. **Android:** sin dispositivo/emulador, la
validación visual y el smoke test están pendientes.

### Mutation testing (26 mutantes)

| Resultado | N | Detalle |
|---|---|---|
| Killed | 20 | atribución siempre ausente, enrutado por identidad, sin guarda de identidad, URLs sin validar (page/license), enlace cruzado, licencia vacía visible, sin aviso al fallar, solo `http`, cualquier esquema, sin host, espacios, ⋯ que reproduce / ausente, sin long-press, tap que abre acciones, playNext↔addToQueue, playlist no-op; **fallo→ausente** (matado tras añadir `attribution_providers_test`) |
| Survived reales | 0 | (1 inicial —fallo→ausente a nivel de provider, que la UI no distingue— corregido con test y re-matado) |
| Survived esperados | 3 | sin `autoDispose` (solo memoria); esquema sin `toLowerCase` (`Uri.scheme` ya lo normaliza); `return` tras favorito (nada después) |
| Compile-invalid | 3 | no cuentan como killed |

## 10. Pendientes

- Validación Android (smoke test del §23 del encargo).
- El ⋯ de `TakiSongTile` no incluye el título en su etiqueta semántica
  (cambiarla afecta tests de otras pantallas; se deja como mejora).
- El botón ⋯ de la barra superior de Reproduciendo sigue sin acciones (I14).
- Caché en memoria de atribuciones si hace falta; el fallo de una fuente sigue
  tumbando el lote (revisar con la 2.ª fuente).
- D6 diferido.
