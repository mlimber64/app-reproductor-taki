# Fase 3.1B — Proveedor Jamendo

Primer proveedor musical real de Taki. Solo lectura, **uso exclusivamente no
comercial**, sin UI. La app sigue funcionando solo con la biblioteca local si no
hay `client_id`.

## 1. Arquitectura

```
core/domain
  entities/catalog_search.dart     CatalogSearchQuery, CatalogSearchPage, CatalogSearchFailure
  ports/catalog_search.dart        CatalogSearch (contrato independiente de la fuente)
  services/source_playback_resolver.dart   enruta PlaybackResolver por MusicIdentity.source
  services/artwork_resolvers.dart  + SongArtworkResolver (devuelve Song.artwork, sin red)

features/jamendo            (depende solo de core; sin feature → feature)
  domain/entities   JamendoTrack, JamendoAttribution, JamendoTrackPage, JamendoException (sealed)
  domain/ports      JamendoApi        (sin HTTP/URI/JSON/client_id)
  domain/services   songFromJamendoTrack, JamendoSongLookup, JamendoPlaybackResolver,
                    JamendoCatalogSearch, JamendoAudioCache, CachingJamendoApi
  infrastructure    HttpJamendoApi, parseJamendoTracks, JamendoCredentials

app/jamendo_wiring.dart     construye todo; song_lookup_wiring.dart registra el lookup
main.dart                   resolver de playback, artwork resolver y loader remoto
```

No se tocó `Song`, `MusicIdentity`, `SongLookup`/`SourceSongLookup`, SQLite
(esquema), `TakiArtwork`, ni el comportamiento local. Los únicos cambios en
código existente son aditivos: `initPlayer(resolver:)`, wiring y manifest.

## 2. Source identifier

`jamendoSource = 'jamendo'`. `MusicIdentity('jamendo', track.id)`; el id es
siempre `String`, sin normalizar (`"0042"` ≠ `"42"`).

## 3. API client

`JamendoApi` (puerto) → `HttpJamendoApi`. Reutiliza `ArtworkHttpClient` /
`IoArtworkHttpClient` como transporte GET (no se añadió ninguna dependencia
HTTP). El nombre "Artwork" es histórico: **deuda** (renombrar a un
`HttpGetClient` genérico). Ninguna excepción incluye la URI ni la causa original.

## 4. Configuración

`JamendoCredentials` (`clientId`). `EnvironmentJamendoCredentials` lee
`--dart-define=JAMENDO_CLIENT_ID=…`; sin él, `buildJamendoServices` devuelve
`null` y Jamendo no se registra (lookup → `unsupported`, playback →
`IdentityNotFound`). `StaticJamendoCredentials` para tests. Ningún `toString`
revela el valor. Un valor pasado por `--dart-define` queda dentro del binario
de esa compilación (Jamendo lo trata como identificador de aplicación).

## 5. Búsqueda

`CatalogSearch.search(CatalogSearchQuery{text, artist, tag, limit, offset})` →
`CatalogSearchPage{songs, hasMore}`. Jamendo: `namesearch`, `artist_name`,
`tags`, `limit` (1–200, validado por la API → `CatalogSearchFailure`), `offset`.
`hasMore` = la API devolvió tantos resultados como el límite (no se lee `next`).

**Corrección al spike:** el spike concluyó que `search=` devuelve 0 resultados.
Era la **intermitencia** de §16, no un defecto de `search=`. Se usa
`namesearch=` por decisión del encargo.

## 6. Lookup

`JamendoSongLookup`: filtra identidades `jamendo`, deduplica y hace **una**
consulta con `id=a+b+c` (Jamendo acepta ≤ 50 valores separados por espacio/`+`;
`%2B` **no** funciona). `HttpJamendoApi` parte en lotes de 50. Ausente →
`missing`; identidades de otras fuentes → `unsupported` (igual que
`LocalSongLookup`); un track con id no pedido → `SongLookupFailure`; cualquier
error de la API → `SongLookupFailure(source: 'jamendo')`. Contrato 3.0 intacto,
sin resultados parciales.

## 7. Song mapping

`id→identity`, `name→title`, `artist_name→artist`, `album_name→album`,
`duration*1000→durationMs` (≥0), `album_image→artwork`. Vacíos/ausentes →
`null` (o 0). Un track sin `id` o sin `name` se omite. `Song` no lleva audio,
`shareurl` ni licencia.

## 8. Playback

`JamendoPlaybackResolver.resolve(Song)` → `RemoteUriResource(audio)`. El audio
**no** está en `Song`: se consulta por `MusicIdentity` (o sale de la caché).
Sin audio → `UnavailableResource`; id inexistente → `IdentityNotFound`; error
de API → `PlaybackResolutionError`. `SourcePlaybackResolver`: `local` →
`LocalPlaybackResolver`, `jamendo` → Jamendo, otra → `IdentityNotFound` (el
adaptador la convierte en recurso no disponible, como antes).

## 9. Artwork

`album_image` con `width=300` forzado (conservando el resto de la query). Rango
verificado 25–600; **nunca 1000, ni sin `width`**. Resultado:
`RemoteArtworkReference(url, width:300, height:300)`; sin imagen válida →
`UnavailableArtworkReference`. Carga: `ArtworkCache` → `HttpRemoteArtworkLoader`
(ahora cableado en `main.dart`). `SongArtworkResolver` registrado para
`jamendo`: no hay llamada extra a Jamendo. La URL de artwork no lleva
`client_id`.

## 10. Attribution

`JamendoTrack` conserva `shareUrl` (`shareurl`) y `licenseUrl`
(`license_ccurl`) **dentro de la capa Jamendo**, no en `Song`; hoy no se
persiste ni se muestra. `JamendoTrack.attribution` los expone como
`ProviderAttribution` (contrato formal en la sección «Attribution contract» de
3.1C, más abajo). Para una futura pantalla: `JamendoApi.tracksByIds([id])`
→ `track.attribution` (una consulta por pista cuando se abra el detalle).
Requisito de licencia CC (BY-NC-*): mostrar autoría, licencia y enlace.

## 11. Error handling

HTTP 200 **no** implica éxito: se valida `headers.status`/`headers.code`.
`code 5` → `JamendoInvalidClientException`; `3` → `JamendoInvalidParameter…`;
`7`/otros → `JamendoApiException(code)`; HTTP no 2xx / red / timeout →
`JamendoNetworkException`; cuerpo no JSON / sin `headers`/`results` →
`JamendoMalformedResponseException`. "Track inexistente" no es excepción
(`missing`/`IdentityNotFound`). Sin `client_id` no se hace la llamada.

## 12. Caché en memoria

`JamendoAudioCache`: clave `MusicIdentity`, TTL 10 min (< ≥ 20 min observado),
máx. 500 entradas, solo memoria. La alimentan búsqueda y lookup
(`CachingJamendoApi`) y el resolver; evita que una cola de N canciones recién
buscadas cueste N llamadas.

## 13. Restricciones offline

Solo streaming. No hay caché de audio en disco, no hay offline, no se guardan
archivos de audio, ni URLs en SQLite.

## 14. Seguridad

`client_id` solo en infraestructura; ausente de dominio, `Song`, SQLite,
fixtures, logs, excepciones (los mensajes de la API se limpian de él) y tests
(`fake-test-client-id`). **`headers.next` no se lee, no se persiste ni se
loguea**; la paginación usa `offset`. Barrido final: ninguna aparición del
valor real en el árbol, ningún `print`/log en Jamendo.

## 15. Fixtures

`test/fixtures/jamendo/` (sanitizados, sin BOM): `tracks_search.json`,
`empty_results.json`, `error_invalid_client.json`, `error_bad_param.json`.
Todos los tests son offline.

## 16. Límites conocidos — respuestas vacías intermitentes (NUEVO)

Verificado en esta fase: Jamendo responde a veces `success` con 0 resultados a
consultas que sí tienen resultados (10 %–40 % de las llamadas, también espaciadas
3 s; con `namesearch`, `search`, `tags` e `id`; típicamente todo o nada). Sin
mitigación, un lookup marcaría como `missing` pistas que existen. Mitigación:
`HttpJamendoApi` reintenta una respuesta vacía hasta 3 veces (pausa 300 ms).
Coste: una búsqueda o un id realmente inexistente cuesta 4 llamadas (~1 s).
Probabilidad residual de falso vacío ≈ p⁴ (≈ 2,5 % si p=0,4). **Riesgo
abierto:** un consumidor no debe tratar `missing` de Jamendo como borrado
definitivo.

Otros: `limit` ≤ 200; `id` ≤ 50 valores; lote ≤ 50.

## 17. Cuota

No determinada. Sin cabeceras de rate-limit; 40 peticiones seguidas pasaron.

## 18. Expiración del audio

No determinada. El token `from=` cambia en cada llamada; uno de ~20 min siguió
válido. La URL se trata como temporal.

## 19. Decisiones pendientes

- Fallos parciales entre fuentes (hoy un fallo de Jamendo rompe todo el lookup:
  `SongLookupFailure`; decisión del encargo: no tocar aún).
- Cómo se persiste/relaciona una canción remota en favoritos/playlists (hoy solo
  se verificó que `MusicIdentity('jamendo', id)` viaja por SQLite sin cambios).
- Dónde se configura el `client_id` en builds de release.
- Renombrar `ArtworkHttpClient` a un cliente GET genérico.

## 20. Riesgos

- Intermitencia de la API (§16) y cuota/expiración sin determinar.
- Una cola con pistas sin caché resuelve el audio con una llamada por pista
  (el adaptador resuelve toda la cola al hacer `setQueue`); podría agruparse.
- Licencias NC: prohibido uso comercial; falta UI de atribución.
- Dependencia de un servicio externo sin SLA.

## Android

Se añadió `android.permission.INTERNET` a `android/app/src/main/AndroidManifest.xml`
(antes solo existía en debug/profile). Sin otros permisos tocados.

## Validación

Ver el reporte de cierre: tests, mutation testing (0 survived), analyze,
arquitectura, build y prueba en `emulator-5554` (búsqueda real, lookup, artwork
10 447 bytes, reproducción con `JustAudioPlayerAdapter` + `SourcePlaybackResolver`,
seek a 60 s). El harness temporal usado se eliminó.

---

# Fase 3.1C — Hardening y contrato de atribución

Cierra los puntos de release, licencia y resiliencia de 3.1B sin rehacer el
proveedor. Sin UI, sin navegación, sin cambios de SQLite.

## Release configuration

- Variable: **`JAMENDO_CLIENT_ID`** (`EnvironmentJamendoCredentials.variableName`),
  leída con `String.fromEnvironment` (constante de compilación).
- Comando conceptual (sin ningún valor real; el valor lo pone quien compila):

  ```
  flutter build apk --release --dart-define=JAMENDO_CLIENT_ID=<CLIENT_ID>
  ```

- Debug y release se comportan igual: no hay lógica por modo.
- Se revisó el repositorio y la documentación: **no existe ningún typo**
  (`--dart-define=mendo` u otro); el único nombre usado es `JAMENDO_CLIENT_ID`.
- Comportamiento (todo vía `normalizeJamendoClientId`):

  | Entrada | Resultado |
  |---|---|
  | ausente / vacío / solo espacios | `null` → Jamendo no se registra |
  | formato inválido (`[A-Za-z0-9_-]{4,64}` tras recortar) | `null` → igual |
  | válido | se usa, recortado |

  Un valor inválido no llega a la red (`JamendoInvalidClientException`).
  Rechaza `&`, `=`, `?`, `/`, espacios, comillas, `client_id=…`, etc. Es laxo a
  propósito: Jamendo no documenta el formato (el observado son 8 hex).
- Verificación de release (con un valor **fake**, sin credenciales reales):
  `flutter build apk --release --dart-define=JAMENDO_CLIENT_ID=fake-test-client-id`
  deja el valor dentro de `libapp.so` (3 ABIs); `flutter build apk --release`
  **sin** define no contiene ni el fake ni el valor real. Es decir: el
  `client_id` queda **embebido en el binario** de esa compilación (Jamendo lo
  trata como identificador de aplicación, no secreto de servidor), y un APK
  compilado sin define simplemente no tiene Jamendo.
- Tests: `jamendo_credentials_test.dart` (válida, ausente, vacía, inválida,
  efecto en la app). La rama `String.fromEnvironment` con valor se prueba
  ejecutando `flutter test --dart-define=JAMENDO_CLIENT_ID=<fake|inválido> …`
  (sin define ese test se salta).

## Credential handling

El `client_id` sale de `JamendoCredentials` y solo se usa en `HttpJamendoApi`
(query de la request). No existe en dominio, `Song`, `MusicIdentity`, SQLite,
fixtures, logs ni excepciones; los mensajes de error de la API se limpian del
`client_id` **y de cualquier URL** (`<url>`). `toString` de las credenciales no
revela el valor. Un test lee los fuentes de `lib/features/jamendo` y falla si
aparecen `print`, `debugPrint`, `log(`, `stdout`/`stderr`.

## Attribution contract

```
JamendoTrack ──.attribution──▶ ProviderAttribution ──▶ (futura Attribution UI)
 (shareurl, license_ccurl)      (core/domain, sin Jamendo)
```

`ProviderAttribution` (core, neutro de proveedor):

| Campo | Garantía |
|---|---|
| `identity` | siempre; a qué contenido pertenece (`MusicIdentity('jamendo', id)`) |
| `providerName` | siempre (`"Jamendo"`) |
| `pageUrl` | `Uri?` ← `shareurl`; `null` si falta o no es http(s) válida |
| `licenseUrl` | `Uri?` ← `license_ccurl`; mismas reglas |
| `licenseName` | `String?` derivado **solo** de `licenseUrl` si es una URL CC reconocible (`…/licenses/by-nc-nd/3.0/` → `CC BY-NC-ND 3.0`); si no, `null` |
| `hasPageUrl` / `hasLicense` / `isComplete` | para que la UI degrade con gracia |

- **Qué necesita la UI:** nombre del proveedor, enlace directo al contenido,
  licencia (nombre + enlace). Artista/título ya están en `Song`.
- **`shareurl` null:** `pageUrl == null`; **no** se fabrica un enlace desde el
  id (aunque el patrón `jamendo.com/track/<id>` se observó, no es contrato).
  La UI debe mostrar el proveedor sin enlace.
- **`license_ccurl` null:** `licenseUrl == null` y `licenseName == null`; la UI
  muestra «licencia no disponible».
- **¿Puede faltar?** Sí, total o parcialmente (`isComplete == false`). Los
  términos de Jamendo (3.1A) piden atribución con enlace directo: una pista con
  `pageUrl == null` no puede cumplirla y la futura UI deberá decidir qué hacer.
- **Cómo se obtiene:** `JamendoApi.tracksByIds([id])` → `track.attribution`
  (bajo demanda; no se persiste; `Song` no la lleva).
- Tests: `jamendo_attribution_test.dart` (contrato, nulos, licencias por pista,
  nombres CC, igualdad).

## License metadata

El spike observó **CC BY-NC-ND** (`…/by-nc-nd/3.0/`) y **CC BY-NC-SA**
(`…/by-nc-sa/3.0/`). **No se asume** una licencia única: la licencia es de cada
pista, vive en `JamendoTrack`/`ProviderAttribution` y **no** es una propiedad de
`Song` ni global (tests lo comprueban). No hay filtros de licencia (fase
posterior). Todo el uso sigue siendo no comercial.

## Empty-success resilience

Auditoría exacta de `HttpJamendoApi`:

- **Intentos:** 1 inicial + `emptyRetries = 3` → **4 intentos como máximo**.
- **Pausa:** `retryDelay = 300 ms` antes de cada reintento (≈ 0,9 s en el peor
  caso, más la latencia de red).
- **Qué lo usa:** todas las operaciones sobre `/tracks` (`searchTracks` y cada
  lote de `tracksByIds`, por separado). Ningún otro camino.
- **Cuándo reintenta:** solo si `headers.status == "success"` y `results` está
  vacío (`rawCount == 0`). **No** reintenta: errores de API (`status != success`,
  códigos 3/5/7…), fallos de red/timeout/HTTP no 2xx, respuestas malformadas, ni
  resultados parciales (`rawCount > 0`; lo observado era todo-o-nada).
- **Tras agotar:** devuelve lista/página vacía (sin excepción). En lookup →
  `missing`; en búsqueda → página vacía (`hasMore = false`); en playback →
  `IdentityNotFound`.
- **Un error de la API nunca se confunde con un vacío** (tests con códigos 3, 5,
  7 y sin código, todos con `results_count: 0`: 1 sola request y excepción).

> **Riesgo explícito:** un *empty success* tras agotar los reintentos **no es
> certeza** de que el track no exista. Con p ≈ 0,1–0,4 de vacío espurio, la
> probabilidad residual de **falso `missing`** es ≈ p⁴ (0,01 %–2,6 %). Hay un
> test que lo documenta (`RIESGO DOCUMENTADO`). `SongLookupResult` no gana un
> bucket nuevo en esta fase: **ningún consumidor debe tratar el `missing` de
> Jamendo como borrado definitivo** (p. ej. no eliminar favoritos por ello).

## Fixture security

Inventario (coincide con lo documentado): `tracks_search.json`,
`empty_results.json`, `error_invalid_client.json`, `error_bad_param.json`; todos
usados por tests. `jamendo_security_test.dart` verifica que son exactamente
esos, que todos se usan, y que ninguno contiene `client_id`, `secret`,
`next` con URL, BOM, ni tokens `from=` distintos de `<TOKEN>`. Barrido adicional
fuera del test: el `client_id` real no aparece en el árbol.

### `next`

Auditado de nuevo: ningún código lee, guarda, loguea ni propaga `next` (test que
lo busca en `lib/features/jamendo` y `jamendo_wiring.dart`). La paginación es
por `offset`; no se conserva ninguna URL. Se endureció el parser: los mensajes
de error de la API se limpian de cualquier URL (`http`/`https`, sin distinguir
mayúsculas), de modo que ni un `next` ni otra URL con credenciales pueden salir
en una excepción.

## Audio cache (reauditada)

Solo memoria (`JamendoAudioCache`), clave `MusicIdentity`, TTL 10 min, máx. 500,
sin archivos, sin SQLite, sin offline (un test comprueba que `lib/features/jamendo`
no usa `dart:io`, `sqflite`, `path_provider`, `File(`…). TTL **no** aumentado y
**sin** renovación automática. La expiración real de la URL de audio **sigue sin
estar determinada** (≥ 20 min observados).

## Artwork (reauditado)

`width` siempre presente y ahora **acotado a 25–600** (`ArgumentError` fuera de
rango: nunca 1000 ni sin `width`); no hay llamada extra a Jamendo (la referencia
viene en `Song.artwork`); se reutiliza `HttpRemoteArtworkLoader`; hay un único
cliente HTTP en `lib` (`IoArtworkHttpClient`, verificado por test). `TakiArtwork`
no se tocó.

## Persistencia

Sin cambios de SQLite. `MusicIdentity('jamendo', id)` viaja por favoritos y por
playlists (test con `"0042"`). Ni `core`, ni los dominios/infraestructura de
library/playlists, ni `Song`/`MusicIdentity` mencionan Jamendo (test).

## Known provider instability

- Respuestas vacías intermitentes (arriba).
- Cuota no determinada; expiración del audio no determinada.
- `limit` ≤ 200; `id` ≤ 50 valores; `%2B` no sirve como separador.
- La API puede cambiar sin aviso (sin SLA).

## Decisiones pendientes / deuda

- Bucket distinto para «desconocido por fallo de proveedor» en `SongLookupResult`.
- Qué hace la UI de atribución cuando `pageUrl == null`.
- Renombrar `ArtworkHttpClient` a un cliente GET genérico.
- Dónde se inyecta el `client_id` en el pipeline real de release.
