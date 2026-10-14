# Fase 3.1A — Provider Selection & Integration Contract

Solo documentación. **Sin código, dependencias, Android, SQLite, Player, `Song`,
`MusicIdentity`, `SongLookup`, `ArtworkResolver` ni UI modificados.** No hay
puntuaciones ni ranking: el proveedor se elige **por eliminación contra
requisitos técnicos derivados del código y del README**, y cada afirmación lleva
su estado: **VERIFICADO**, **NO VERIFICADO** o **BLOQUEADOR**.

Fuentes: `PHASE_2_1_MUSIC_PROVIDER_RESEARCH.md` y
`PHASE_2_1B_PROVIDER_DOCUMENTATION_VERIFICATION.md` (2026-09-30) más una
re-consulta puntual de los puntos abiertos el **2026-10-01** (marcada «3.1A»).
La herramienta de descarga devuelve resúmenes, no texto íntegro: lo marcado
«3.1A» tiene confianza **media**.

## 1. Estado actual (puntos de extensión existentes)

| Capacidad | Pieza existente | Estado hoy |
|---|---|---|
| Identidad | `MusicIdentity(source, externalId)` opaca | Lista. La fuente es etiqueta abierta |
| Canción | `Song` universal (identidad, título, artista, álbum, duración, `artwork`) | Lista; no tiene campo de URL de página/atribución |
| Resolver identidad→Song | `SongLookup` (lote; `found/missing/unsupported`; `SongLookupFailure`) + `SourceSongLookup` | Lista; **se registra una línea** en `lib/app/song_lookup_wiring.dart` |
| Favoritos/playlists | Resuelven por `SongLookup`; reencuentro local solo para entradas locales `missing` | Listos para fuentes remotas |
| Reproducción | Puerto `PlaybackResolver` + `PlaybackResource` (`LocalUri`, `RemoteUri(uri, expiresAt)`, `Provider(engine, reference)`, `Unavailable`) | Puerto y recursos listos. **No existe router por fuente** |
| Adaptador del player | `JustAudioPlayerAdapter(resolver: …)`; `RemoteUriResource` → `AudioSource.uri(Uri.parse(uri))` | Acepta **un** resolver (por defecto el local); `initPlayer` no recibe ninguno. Resuelve **toda la cola de golpe** (`Future.wait`) al armar la cola. Ignora `expiresAt`; no envía cabeceras. `ProviderPlaybackResource` → no reproducible (`taki-unplayable`) |
| Artwork | `Song.artwork` (`Remote/Local/Unavailable`), `ArtworkCache` + `RemoteArtworkLoader`, `HttpRemoteArtworkLoader` + `IoArtworkHttpClient` (`dart:io`), `artworkResolverProvider` | Cargador HTTP listo pero **no conectado** (`remoteArtworkLoaderProvider` = `null`) |
| Notificación/lockscreen | `ArtworkFileCache` | Solo carátulas **locales** |
| Búsqueda/catálogo | — | **No existe ningún puerto de búsqueda ni `features/catalog`** |
| Autenticación | — | No existe (ni almacenamiento seguro) |
| Android | `INTERNET` solo en manifiestos *debug/profile*; sin `networkSecurityConfig` | El manifiesto principal no permite red |

Conclusión: casi todo existe. Lo que **falta** y no lo cubre ninguna abstracción
actual: (1) un **router de `PlaybackResolver` por fuente**, (2) un **puerto de
búsqueda**, (3) la **frontera de configuración/credenciales**, (4) `INTERNET`.
Los tres primeros siguen el patrón de los routers existentes; no se propone
ninguna abstracción nueva más allá de ellos.

## 2. Requisitos técnicos de selección (derivados del código)

| Id | Requisito | Origen |
|---|---|---|
| R1 | Audio **completo** entregado como URL reproducible por `just_audio` (`RemoteUriResource`), sin motor propio | El adaptador solo reproduce `LocalUri`/`RemoteUri`; `ProviderPlaybackResource` no tiene motor |
| R2 | Sin cuenta de usuario ni backend propio | README: «sin backend, sin cuentas, sin anuncios y sin telemetría» |
| R3 | Términos **legibles y verificados** que permitan reproducir en una app de terceros | Regla de 2.1B: la decisión no se toma con términos UNKNOWN |
| R4 | Reproducción en segundo plano con notificación y bloqueo | `audio_service` ya lo implementa |
| R5 | Identidad estable y artwork por URL con tamaño | `MusicIdentity` opaca; `RemoteArtworkReference(url, width, height)` |

## 3. Evidencia por candidato

Estados: **V** verificado · **NV** no verificado · **B** bloqueador.

### Audius
- A Catálogo: V (SDK: `searchTracks`, `getTrack`, `getBulkTracks`; 2.1B). REST: NV (referencia no legible; re-comprobado 3.1A: sigue sin contenido).
- B Identidad: V (`id` corto, p. ej. `mWB22`); **hay un segundo id numérico en la URL de stream** → hay que fijar uno canónico. `permalink` no apto.
- C Playback: URL `stream.url` **firmada** con `signature`/`timestamp` (observación); TTL **NV**; endpoint documentado de stream **NV** (3.1A: la documentación REST no devolvió contenido).
- D Artwork: 150/480/1000 (observación; no documentado) — V parcial.
- E Auth: V (API key pública; bearer solo backend).
- F Términos: Open Music License + Terms of Use **V** (permiten stream a «Music Players»; licencia alternativa por pista posible, incluidas NC/ND). **API Terms: B — ilegibles** (HTTP 500 en 2.1B y de nuevo el 2026-10-01).
- G Android: HTTP/JSON; sin SDK Flutter; límites Free 10 req/s y 500 000/mes (V).
- **Bloqueador: B — API Terms ilegibles**; sin ellos no se puede afirmar uso comercial/condiciones de la API (R3).

### Apple Music
- A Catálogo: V (Apple Music API).
- B Identidad: `MusicItemID` cadena; estabilidad NV.
- C Playback: **motor propio** (MusicKit for Android, `MediaPlayerController`) → solo `ProviderPlaybackResource`, que hoy no tiene motor (R1 ✗). Uso desde Flutter: NV.
- D Artwork: plantilla de URL con ancho/alto (NV en detalle).
- E Auth: developer token JWT ES256 (requiere clave privada del Apple Developer Program, 99 USD/año) + Music User Token manual en Android → **cuenta de usuario** (R2 ✗). Emitir el token sin backend: NV.
- F Términos: **NV** (no localizados).
- **Bloqueadores: R1, R2 y términos NV.**

### Deezer
- A Catálogo/metadata: V (observación, sin credenciales).
- B Identidad: numérica estable; ISRC no apto.
- C Playback: API pública = **previews de 30 s**, URL con expiración. Audio completo para apps nuevas: **NV (UNKNOWN)**; página del SDK 404. «Full-length track URLs must never be accessible to the end-user»; almacenamiento local de audio prohibido (V).
- D Artwork: 56/250/500/1000 (V observación).
- E Auth: datos públicos sin auth; usuario NV. Registro de apps nuevas NV.
- F Términos: **uso estrictamente no comercial** (V).
- **Bloqueador: R1 (solo 30 s verificado) y R3 (audio completo UNKNOWN).**

### Jamendo
- A Catálogo: V (`/v3.0/tracks` y entidades; cientos de miles de pistas). Metadata: V (`id`, `duration`, `album_id`, `album_name`; 3.1A: la página de `/tracks` **no enumera** el resto de campos de respuesta — `name`/`artist_name` son esperables pero **NV hasta verlos en una respuesta real**).
- B Identidad: `id` numérico (V observación, p. ej. `29866`); estabilidad formal NV.
- C Playback: `audio` = URL de **stream completo** (V, 3.1A: «contain respectively the stream and download urls»); `audioformat` mp31/mp32/ogg/flac (V). Caducidad de la URL: **NV**. Si el stream exige `client_id` o cabeceras: **NV** (3.1A: no documentado). Comportamiento real de `just_audio` con esas URLs: **NV** (nunca probado en el proyecto).
- D Artwork: `image`/`album_image`, parámetro `imagesize` ∈ {25…600} (V, 3.1A). Reglas de caché/hotlink: NV.
- E Auth: `client_id` por aplicación en **cada** llamada (V). Es «privado»; credenciales «strictly personal» (cl. 2, V en 2.1B). Cómo distribuir un `client_id` en una app sin backend: **NV (pregunta abierta)**. No hay cuenta de usuario para consultar el catálogo (V).
- F Términos (3.1A, texto de la cláusula): uso libre **no comercial**; comercial = contactar a ventas (3.3); la app **no debe diseñarse para cachear contenido ni ofrecer acceso offline** (3.3); atribución a miembros y a Jamendo **con enlace directo** a cada contenido (4.1); al terminar, retirar contenido y referencias (7). Reproducción en segundo plano y en apps móviles: **no tratadas** (ni permitidas ni prohibidas). Licencia CC **por pista** (3.1).
- G Android: HTTP/JSON, sin SDK. Límite: 2.1B indicó 35 000 peticiones/mes (no comercial); la página de autenticación (3.1A) cita **500 000 hits** como umbral para contactarles → **cifras inconsistentes, NV**.
- **Sin bloqueador documental.** Condiciones: producto no comercial, sin diseño de caché/offline, atribución con enlace, licencias CC por pista.

### Internet Archive
- A Catálogo: `advancedsearch`/metadata V, pero es un archivo genérico de audio, no un catálogo musical.
- B Identidad: de **dos partes** (ítem + archivo).
- C Playback: URL oficial de descarga **NV**.
- F Términos: sin garantía de copyright, licencia declarada por el subidor y a menudo ausente (V); Terms vigentes **NV**.
- **Bloqueadores: URL de descarga NV, Terms NV, licencia no garantizada (R3).**

### Spotify
- Catálogo/metadata V. **No existe entrega de audio utilizable por `just_audio`**: solo Web Playback SDK (navegador, Premium) o control de la app oficial; streaming solo Premium; apps de streaming sin uso comercial.
- **Bloqueadores: R1, R2 (cuenta Premium).**

### YouTube / YouTube Music
- YouTube: solo reproductor incrustado oficial; prohibidos audio aislado, reproducción en segundo plano y caché (V). **Bloqueador: R1 y R4.**
- YouTube Music: API pública oficial **NV** (no hallada). Sin evidencia para evaluarlo.

## 4. Matriz comparativa factual

| Proveedor | Catalog | Identity | Playback | Artwork | Auth | Android | Restricciones | Bloqueadores |
|---|---|---|---|---|---|---|---|---|
| Audius | V (SDK) / NV (REST) | V (dos ids) | URL firmada, TTL NV, endpoint NV | V parcial (150/480/1000) | V (API key pública) | HTTP/JSON | OML/ToU V; licencia por pista | **B: API Terms ilegibles** |
| Apple Music | V | NV | Motor del SDK (`ProviderPlaybackResource`) | NV detalle | Developer token + token de usuario | SDK nativo; Flutter NV | Términos NV | R1, R2, términos NV |
| Deezer | V | V | Solo 30 s (completo NV) | V | Público sin auth | HTTP/JSON | No comercial; sin almacenamiento de audio | R1/R3 (audio completo NV) |
| Jamendo | V | V (id numérico) | URL completa V; expiración NV; just_audio NV | V (`imagesize` 25–600) | `client_id` por app; distribución NV | HTTP/JSON | No comercial; sin caché/offline; atribución con enlace; CC por pista | **Ninguno documental** |
| Internet Archive | V (genérico) | V (2 partes) | URL de descarga NV | Limitado | Ninguna | HTTP/JSON | Licencia no garantizada | URL NV, Terms NV |
| Spotify | V | V | Sin audio utilizable | V | OAuth, Premium | SDK de control | No comercial streaming | R1, R2 |
| YouTube | V | V | Solo reproductor oficial | V | Key/OAuth | WebView | Sin audio aislado/segundo plano/caché | R1, R4 |
| YouTube Music | NV | NV | NV | NV | NV | NV | NV | Sin API pública hallada |

## 5. Proveedor elegido para la implementación posterior

**Jamendo.** Motivo técnico, por eliminación contra los requisitos de §2:

- R1: solo Jamendo (y Audius) entregan **audio completo por URL** verificado; Apple exige motor propio (no existe), Deezer solo verifica 30 s, Spotify y YouTube no entregan audio, Internet Archive no tiene URL de descarga verificada.
- R2: Jamendo no requiere cuenta de usuario ni backend para el catálogo (Apple y Spotify sí).
- R3: **los términos de Jamendo están leídos y verificados**; los de Audius (API Terms) **no se pueden leer** — es un bloqueador documental vigente, no una suposición.
- R5: id numérico estable y artwork con tamaño elegible.

La selección **no** dice que Jamendo sea «mejor»: Audius quedaría elegible en cuanto se puedan verificar sus API Terms y el endpoint de stream. Es la **única** opción sin bloqueador documental hoy.

**Condiciones de producto que la selección da por necesarias** (y que el
propietario debe confirmar antes de 3.1B; ver §15):
1. Taki se usa y distribuye de forma **no comercial** (sin ingresos, publicidad ni afiliación). El README promete «sin anuncios»; **no declara** explícitamente que sea no comercial.
2. Dónde vive el `client_id` (no hay backend).
3. Aceptación de las restricciones: sin diseño de caché/offline para contenido de Jamendo y atribución con enlace.

## 6. Contrato del proveedor

Cuatro capacidades, qué existe y qué hay que añadir (**no se implementa ahora**):

| Capacidad | Contrato | ¿Existe? |
|---|---|---|
| Búsqueda | `Provider → Song`: nuevo puerto de búsqueda (p. ej. `SongSearch.search(query, {limit, offset}) → List<Song>`, error `SongSearchFailure`) | **No** (falta; sin consumidor en la UI actual) |
| Lookup | `MusicIdentity → Song`: `JamendoSongLookup implements SongLookup` (lote) | Puerto sí; implementación nueva |
| Reproducción | `Song → PlaybackResource`: `JamendoPlaybackResolver implements PlaybackResolver` + **router `SourcePlaybackResolver`** (mismo patrón que `SourceArtworkResolver`) + pasar el resolver a `initPlayer`/`JustAudioPlayerAdapter` | Puerto sí; router y wiring **no** |
| Artwork | `Song.artwork = RemoteArtworkReference(url, width, height)` ya al mapear; `HttpRemoteArtworkLoader(IoArtworkHttpClient)` conectado a `remoteArtworkLoaderProvider` | Modelo y cargador sí; falta conectar |

Capacidad que **el proveedor no da**: reproducción por motor propio (no la
necesita) y búsqueda por varias fuentes (solo Jamendo). El enlace a la página
del contenido (atribución) **no tiene dónde vivir** en `Song` (ver §14).

## 7. Source identity

```
MusicIdentity(source: 'jamendo', externalId: <id de pista de Jamendo como cadena decimal>)
```
- `source = 'jamendo'`: etiqueta opaca, en minúsculas, estable, específica del proveedor. Es la **clave** del mapa en `buildSongLookup`, del router de reproducción y de artwork.
- `externalId`: el `id` de la pista **tal como lo entrega la API**, convertido con `toString()` si llega numérico; **sin** recortar, rellenar ni normalizar (la regla de `MusicIdentity`). Un `id` ausente o vacío invalida la pista (no se mapea).
- No depende de URLs, ISRC ni nombres.

## 8. Song mapping

| `Song` | Jamendo | Si falta |
|---|---|---|
| `musicIdentity` | `('jamendo', id)` | Sin `id`: pista descartada |
| `title` | `name` (esperado; **NV** hasta ver una respuesta real) | Sin título: pista descartada (`Song.title` no admite null) |
| `artist` | `artist_name` (NV) | `null` |
| `album` | `album_name` | `null` |
| `durationMs` | `duration` (segundos) × 1000 | `0` |
| `artwork` | `RemoteArtworkReference(image, width: s, height: s)` con `s` = `imagesize` pedido | `UnavailableArtworkReference` (nunca se inventa una URL) |

Notas: el tamaño de portada pedido es una decisión de 3.1B (la UI pide hasta ~342 dp × dpr; el máximo de Jamendo es 600). `image` vacío se prueba con `album_image` antes de `Unavailable`. **El mapeo exacto de campos debe fijarse con una respuesta real grabada como fixture en 3.1B** (hoy NV).

## 9. Playback contract

Decisión: `RemoteUriResource(uri: audio, expiresAt: null)`; `UnavailableResource` si `audio` está vacío o el recurso no existe. **No** necesita `ProviderPlaybackResource` ni motor; **no** usa `LocalUriResource`.

Hechos de diseño que condicionan 3.1B:
1. **`Song` no lleva la URL de audio** y esta no debe inventarse. La URL de stream se obtiene de la API (`audio`) por pista, por lo que el resolver necesita un origen de la URL: una **caché en memoria dentro del adaptador de Jamendo** (identidad → `audio`) que se rellena cuando la búsqueda o el lookup devuelven la pista, con *re-fetch* por `id` como respaldo. Es una caché operativa de sesión, sin disco, coherente con la cláusula 3.3 («solo lo razonablemente necesario»), interna al adaptador y **sin cambiar ninguna abstracción**.
2. **Resolución eager**: `JustAudioPlayerAdapter` resuelve toda la cola al armar la cola; sin la caché anterior serían N llamadas a la API (límite de cuota). Con la caché, normalmente es gratis.
3. **Sin router de reproducción por fuente**: hay que añadir `SourcePlaybackResolver` (local + `jamendo`) y pasarlo a `initPlayer`; hoy el adaptador usa solo el local, que lanza `IdentityNotFound` para otras fuentes.
4. **NV**: caducidad de la URL, si necesita `client_id` o cabeceras, y que `just_audio` reproduzca esas URLs (HTTP/HTTPS, redirecciones). **El primer paso de 3.1B es una prueba de reproducción con una URL real.**
5. Requisitos de plataforma: `INTERNET` en el manifiesto principal (hoy solo debug/profile) y HTTPS (Android bloquea HTTP en claro por defecto).
6. Notificación/lockscreen: `ArtworkFileCache` es solo local → la pista de Jamendo no tendría carátula en la notificación en 3.1B (usar la URL directa como `artUri` es **NV**; guardar el archivo chocaría con la cláusula 3.3 de no diseñar caché).

## 10. Artwork contract

Basta `Song.artwork = RemoteArtworkReference(url, width, height)`; **no se necesita `ArtworkResolver`** (la URL viene en el listado, como previó 2.8B). Falta únicamente conectar `HttpRemoteArtworkLoader(const IoArtworkHttpClient())` en `remoteArtworkLoaderProvider` (en `lib/app`). El `ArtworkCache` es en memoria y no persistente, compatible con la cláusula 3.3. Reglas de caché/hotlinking de las imágenes de Jamendo: **NV**.

## 11. Auth contract

- Credencial: `client_id` de aplicación en cada petición. Sin OAuth, sin token de usuario, sin caducidad conocida.
- El adaptador recibe la credencial por **inyección** (parámetro de configuración); nunca va en el dominio, en `Song`, en SQLite ni en el repositorio.
- **Dónde se obtiene en tiempo de ejecución es una decisión de producto abierta** (§15): variable de compilación no versionada para desarrollo; la distribución con un `client_id` embebido choca con «credentials strictly personal» (NV si es admisible).
- Fallo de credencial (ausente/inválida): ver §12.

## 12. Failure contract

| Situación | Tratamiento | Alcance |
|---|---|---|
| Pista no existe en Jamendo / fue retirada | `missing` | Una canción (se oculta, no se borra) |
| `audio` vacío o descarga no permitida | `UnavailableResource` | Una canción |
| `image` vacío | `UnavailableArtworkReference` | Una canción (placeholder) |
| Fuente sin lookup registrado | `unsupported` | Las identidades de esa fuente |
| Red caída / timeout / 5xx | `SongLookupFailure(source: 'jamendo')` (lookup); `UnavailableResource` o fallo de carga (playback) | **Hoy falla el lote** — ver abajo |
| `client_id` inválido o cuota agotada (4xx / estado de error en el cuerpo: forma **NV**) | `SongLookupFailure` con causa de autenticación/cuota | La fuente entera |
| Respuesta malformada / pista sin `id` o `name` | La pista se descarta; si la respuesta entera es ilegible, `SongLookupFailure` | Una canción / la fuente |
| Artwork no descargable | `null` en `ArtworkCache` (sin memoizar) → placeholder | Una imagen |

**Incompatibilidad real descubierta con la arquitectura actual:**
`SourceSongLookup` propaga el fallo de una fuente y **falla el lote entero**
(decisión documentada en 3.0). Con Jamendo registrado, **estar sin conexión** —el
caso normal en un móvil— haría fallar también la resolución de los favoritos y
playlists **locales** (la pantalla de Favoritos mostraría error, no las
canciones locales). Es el único cambio a una abstracción existente que la
integración exige y debe hacerse **antes** de registrar el lookup de Jamendo:
aislar el fallo por fuente (nuevo cubo/valor `failed` en `SongLookupResult`,
entradas ocultas sin borrarse) manteniendo el error visible si falla la fuente
local, como hoy. Se especifica en 3.1B; **no se modifica en 3.1A**.

## 13. Riesgos

1. Cumplimiento: uso **no comercial** obligatorio; si Taki se monetizara, Jamendo exigiría un acuerdo comercial.
2. Atribución con enlace directo por contenido (4.1) sin dónde guardar la URL de la página (`Song` no tiene el campo): requiere decisión (campo, puerto de atribución o pantalla específica). Obligatoria para cualquier distribución pública.
3. Licencia CC por pista (algunas `by-nc-nd`): hay que respetarla; conviene exponer/filtrar (`ccnd`, `ccnc`, `ccsa` son filtros de la API).
4. Restricción de «no diseñar para caché/offline»: afecta a la caché de URLs de audio, al `ArtworkFileCache` y a cualquier descarga futura.
5. Cuotas inconsistentes (35 000/mes vs umbral de 500 000) y `client_id` personal sin forma de distribuirlo.
6. Caducidad de URLs y comportamiento de `just_audio`: sin verificar.
7. Eliminación del contenido al terminar el acuerdo (cl. 7) vs favoritos/playlists que guardan respaldo de metadata de pistas de Jamendo.
8. Fallo por lote (§12).
9. Cambia la promesa de privacidad del README («sin backend… sin telemetría»): hay tráfico a un tercero (la consulta y el `client_id` revelan al proveedor el uso).
10. Licencias de la API y del contenido son independientes: se deben cumplir ambas.

## 14. Preguntas abiertas

Para el propietario (bloquean el **inicio** de 3.1B):
1. ¿Taki es y será **no comercial** (sin ingresos, anuncios ni afiliación)?
2. ¿Dónde vive el `client_id`: variable de compilación personal (no distribuible), configuración del usuario, otra?
3. ¿Se acepta la restricción «sin caché/offline» para contenido de Jamendo y que la notificación de pistas remotas no lleve carátula en 3.1B?
4. ¿Se acepta cambiar `SourceSongLookup` para aislar fallos por fuente (§12)?

Técnicas (se resuelven dentro de 3.1B): campos exactos de la respuesta de `/tracks`; caducidad y requisitos del `audio`; `just_audio` con esas URLs; tamaño de portada; forma del error por `client_id` inválido; cuota real; dónde ubicar el enlace de atribución; formato de URL de página del contenido (`shareurl`, NV).

## 15. Alcance exacto de la futura Fase 3.1B

**Gate (paso 0, antes de escribir código de producción):** (a) las 4 preguntas del propietario respondidas; (b) *spike* con un `client_id` real: una petición `/v3.0/tracks` guardada como fixture (campos, `audio`, `image`, error de credencial) y una prueba de reproducción con `just_audio` en dispositivo (sin código en `lib/`).

**Dentro de 3.1B** (sin UI):
1. `SongLookupResult.failed` + aislamiento por fuente en `SourceSongLookup` y en los casos de uso (favoritos/playlists), con tests; local sigue mostrando error si falla.
2. `SourcePlaybackResolver` y cableado en `initPlayer`.
3. Puerto de búsqueda + `JamendoSongSearch`, `JamendoSongLookup`, `JamendoPlaybackResolver` (con la caché en memoria de URLs) y el mapper `Track → Song`, sobre `ArtworkHttpClient`/`dart:io`, **sin dependencias nuevas**.
4. Registro en `buildSongLookup`, router de reproducción y `remoteArtworkLoaderProvider`; `INTERNET` en el manifiesto principal.
5. Tests con HTTP falso y fixtures; mutation testing; documentación.

**Fuera de 3.1B:** pantalla de búsqueda y atribución (3.1C), carátula en la notificación, descargas/offline, cuentas de usuario, otros proveedores, y cualquier cambio de `Song`/`MusicIdentity`/SQLite.

## 16. Validación de esta fase

Solo documentación. Se ejecutaron `flutter analyze`, `flutter test`, el test de arquitectura y `flutter build apk --debug` (resultados en el informe de la fase); `git diff` sin cambios en `pubspec`, `android/`, SQLite, Player ni UI.
