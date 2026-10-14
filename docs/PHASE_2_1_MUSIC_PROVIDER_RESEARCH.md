# Fase 2.1 — Investigación de proveedores musicales

**Fecha de consulta de todas las fuentes: 2026-09-30.**
**Alcance:** investigación y documentación. Sin código, dependencias, permisos, manifiestos ni UI. No se eligió proveedor ni se hizo ranking.

> **Aviso metodológico importante.** Las páginas se consultaron con una herramienta de descarga que devuelve un **resumen automático** del contenido, no el texto íntegro. Las «citas» de este documento son las que esa herramienta devolvió y **no se garantiza que sean literales**. Varias páginas renderizadas con JavaScript devolvieron solo la cabecera y no se pudieron leer (se marcan como **UNKNOWN**). Antes de tomar una decisión legal o de producto, cada afirmación crítica debe **reverificarse en la página oficial** (ver §16 y §18). Las sondas de API (una petición de solo lectura sin credenciales a Deezer, Audius, Internet Archive y Openverse) sirven para ver la forma de los datos, no implican permiso de uso.

---

## 1. Executive Summary

1. **Ningún proveedor comercial consultado ofrece, por API oficial, un mecanismo para que una app de terceros obtenga el audio completo y lo reproduzca con su propio motor** (en Taki, `just_audio`).
   - **Spotify:** el audio se reproduce por el Web Playback SDK (navegador, requiere Premium) o controlando la app oficial (Android App Remote). No hay URL de audio.
   - **Deezer:** su API pública da metadata y **previews de 30 s** con URL firmada y con caducidad; el audio completo aparece como capacidad solo para usuarios Premium a través de «API/Plugins», sin un mecanismo verificable hoy para apps nuevas.
   - **Apple Music:** existe MusicKit para Android con bibliotecas de autenticación y de reproducción (SDK propio, requiere Apple Developer Program y cuenta de Apple Music); el audio lo reproduce el SDK, no `just_audio`.
   - **YouTube:** la reproducción es solo mediante el reproductor oficial incrustado; las políticas prohíben separar el audio, reproducir desde un reproductor en segundo plano y almacenar contenido. No encaja con el reproductor de Taki.
2. **Las fuentes de contenido abierto/CC sí exponen audio completo por URL**, con condiciones: **Jamendo** (stream por API; CC por pista; sin uso comercial sin acuerdo; la app no debe diseñarse para caché/offline), **Audius** (URL de stream firmada; términos de API no verificados), **Internet Archive** y **Openverse** (licencia por elemento; a menudo ausente o no garantizada).
3. Lo anterior define **dos familias de reproducción**: por **URL** (encaja con `just_audio` y con el `PlaybackResolver` de Fase 2.0) y por **motor del proveedor** (SDK o control remoto; **no** encaja con un resolvedor que devuelva una URL). Este es el hallazgo que más afecta a la arquitectura (§15).
4. Las cuatro capacidades se separan: catálogo y metadata son accesibles en casi todos; artwork también; **reproducción completa** solo en las fuentes abiertas y, con SDK propio, en Apple Music.
5. La arquitectura de Fase 2.0 sigue siendo adecuada, con tres **ajustes conceptuales** (no de código) que se recomiendan recoger en las fases 2.2–2.4: (a) el resolvedor de recurso debe poder devolver algo distinto de una URL; (b) la persistencia de metadata de respaldo puede estar restringida por los términos de algunos proveedores; (c) la identidad externa debe ser una **cadena opaca** definida por cada fuente (p. ej. Internet Archive necesita ítem + archivo).
6. Muchos puntos siguen en **UNKNOWN** (p. ej. términos de API de Audius, requisitos exactos de MusicKit para Android, caducidad de las URL firmadas). Se listan en §16 y **no se convierten en suposiciones**.

**Conclusión:** PHASE 2.1 READY FOR ARCHITECTURE IMPLEMENTATION (limitada a las fases independientes del proveedor; ver §19).

---

## 2. Research scope

Investigado: Jamendo, Audius, Internet Archive, Openverse (agregador de contenido abierto), Spotify, Deezer, Apple Music, YouTube/YouTube Music, y una verificación breve de Free Music Archive y ccMixter. Para cada uno: catálogo, búsqueda, metadata, artwork, reproducción, autenticación, límites, licencias y términos, identidad, Android/Flutter.

No investigado: técnicas de extracción de audio, scraping o evasión de restricciones (excluidas por el encargo); proveedores sin API pública documentada; costes hipotéticos.

## 3. Methodology

1. Consulta de documentación y términos oficiales (desarrolladores, licencias, políticas). Fuentes secundarias solo para aclarar y **siempre marcadas**.
2. Sondas de solo lectura, una por API, sin credenciales, para observar la forma real de los datos: `api.deezer.com/track/…`, `api.audius.co/v1/tracks/trending` y `/tracks/search`, `archive.org/advancedsearch.php` y `/metadata/…`, `api.openverse.org/v1/audio/`.
3. Cada capacidad se registra con un valor descriptivo (YES / NO / LIMITED / CONDITIONAL / UNKNOWN) y su motivo.
4. Limitación ya indicada: resúmenes automáticos de las páginas. Lo que no pudo leerse queda **UNKNOWN**.

## 4. Sources and consultation dates

Todas consultadas el **2026-09-30**.

| Proveedor | Fuente (URL) | Tipo | Resultado |
|---|---|---|---|
| Jamendo | https://developer.jamendo.com/v3.0 | Oficial | Leída (resumen) |
| Jamendo | https://developer.jamendo.com/v3.0/tracks | Oficial | Leída |
| Jamendo | https://devportal.jamendo.com/api_terms_of_use | Oficial (términos) | Leída |
| Audius | https://docs.audius.co/developers/api , https://docs.audius.co/api , https://docs.audius.co/developers/guides/rest-api | Oficial | **Solo navegación; sin detalle** |
| Audius | https://cdn.jsdelivr.net/npm/@audius/sdk@15.3.1/README.md (README oficial del SDK) | Oficial | Leída |
| Audius | https://api.audius.co/v1/tracks/trending , /tracks/search | Sonda de API | Forma de datos observada |
| Audius | https://audius.co/legal/terms-of-use | Oficial (términos) | **Error 500; no leída** |
| Internet Archive | https://archive.org/developers/ , /developers/md-read.html | Oficial | Leídas |
| Internet Archive | https://help.archive.org/help/rights/ | Oficial | Leída |
| Internet Archive | https://archive.org/about/terms.php | Oficial (términos) | **Sin contenido útil** |
| Internet Archive | https://archive.org/advancedsearch.php , /metadata/thems-fightn-words-part-2 | Sonda de API | Observada |
| Openverse | https://api.openverse.org/v1/audio/ , https://docs.openverse.org/api/reference/made_with_ov.html | Oficial / sonda | Parcial |
| Spotify | https://developer.spotify.com/documentation/web-api , /web-playback-sdk , /android , /terms , /documentation/web-api/concepts/quota-modes , /documentation/web-api/references/changes/february-2026 , /blog/2024-11-27-changes-to-the-web-api | Oficial | Leídas (resumen) |
| Spotify (secundaria) | https://pub.dev/packages/spotify_sdk | Comunidad | Solo para «Spotify instalado» en Android |
| Deezer | https://developers.deezer.com/guidelines , /termsofuse | Oficial | Leídas |
| Deezer | https://developers.deezer.com/api (y /api/track) | Oficial | **Solo navegación** |
| Deezer | https://api.deezer.com/track/3135556 | Sonda de API | Observada |
| Deezer (secundaria) | Resultados de búsqueda sobre SDK/Connect (foros, prensa) | Secundaria | Indicio, **no concluyente** |
| Apple | https://developer.apple.com/musickit/ , /documentation/musickit.md , /documentation/applemusicapi.md , /programs/whats-included/ | Oficial | Leídas |
| Apple | https://developer.apple.com/terms/apple-music/ , /musickit/android/ | Oficial | **Sin términos de MusicKit; Android solo índice Javadoc** |
| YouTube | https://developers.google.com/youtube/terms/developer-policies , /youtube/v3/determine_quota_cost , /youtube/iframe_api_reference | Oficial | Leídas |
| FMA / ccMixter | Resultado de búsqueda (prensa / Creative Commons) | Secundaria | FMA cerrado en 2018 |

## 5. Provider-by-provider analysis

### 5.1 Jamendo (catálogo abierto, CC)

- **API:** oficial, v3.0; catálogo de «cientos de miles de pistas», álbumes, artistas y playlists; OAuth2 para cuentas de usuario.
- **Catalog/Search/Metadata:** YES (búsqueda del catálogo, pistas, álbumes, artistas).
- **Artwork:** YES. El parámetro `imagesize` acepta 25…600 px; campos `image` y `album_image`.
- **Playback:** YES (URL de audio completa). `/tracks` devuelve `audio` (URL de **stream**) y `audiodownload`; `audioformat` ∈ {mp31, mp32, ogg, flac}, por defecto mp31 (96 kbps). `audiodownload_allowed` indica si la descarga está permitida (si es falso, `audiodownload` llega vacío). Observado indirectamente en Openverse: URL directa `https://prod-1.storage.jamendo.com/?trackid=…&format=mp32` (A – direct audio URL; caducidad UNKNOWN).
- **Auth:** API key/credenciales de desarrollador (personales, «no deben compartirse») + OAuth2 solo para funciones de usuario. Cómo se obtiene: UNKNOWN en detalle.
- **Límites:** apps no comerciales: hasta **35 000 peticiones/mes** (página de desarrolladores). Jamendo se reserva imponer límites adicionales.
- **Términos de API (https://devportal.jamendo.com/api_terms_of_use):**
  - Uso libre **no comercial**; «comercial» = cualquier uso dirigido a ventaja comercial o compensación monetaria, incluidos ingresos por afiliación o publicidad → requiere contactar a Jamendo.
  - La app «**must not be specifically designed to cache the content nor offering an offline access to the content**»; la caché solo en lo razonablemente necesario.
  - **Atribución obligatoria:** créditos a los miembros de Jamendo como creadores, a Jamendo como proveedor y **enlace directo** de cada contenido a su página.
  - La app no debe replicar la experiencia global de Jamendo ni parecerse de forma confusa a su diseño.
- **Licencia del contenido:** cada contenido está bajo una licencia **Creative Commons** distinta (campo `license_ccurl`). Una sonda de Openverse mostró una pista de Jamendo con `by-nc-nd` (NC = no comercial; ND = sin obras derivadas). Por tanto, **la licencia varía por pista**.
- **Utilizable por Taki (técnicamente):** catálogo, búsqueda, metadata, artwork y reproducción por URL. **Condicionado** por: uso no comercial, atribución con enlace, no diseñar para caché/offline y licencia por pista.

### 5.2 Audius

- **API:** oficial; REST + SDK JavaScript/TypeScript. Plan Free: **10 peticiones/s y 500 000/mes**, «siempre gratuito»; plan Unlimited bajo contacto (README del SDK).
- **Auth:** se obtiene una **API Key** (segura en código de cliente) y un **Bearer Token** (solo backend; «Never include your bearer token in frontend code»). Sondas sin credenciales a `/v1/tracks/trending` y `/tracks/search` devolvieron datos (una petición; no prueba que la API siga abierta sin clave).
- **Catalog/Search/Discovery/Metadata:** YES (búsqueda, tendencias, metadata de pista y usuario).
- **Artwork:** YES. Objeto `artwork` con variantes `150x150`, `480x480`, `1000x1000` y espejos.
- **Playback:** la respuesta de pista incluye `stream.url` con **parámetros de firma** y `mirrors`, `is_streamable`, `access` y `stream_conditions`. Clasificación provisional **B – signed/expiring URL (caducidad UNKNOWN)**. El contenido puede tener condiciones de acceso (`stream_conditions`); en la muestra era `null`.
- **Identidad:** `id` es una cadena corta (p. ej. `mWB22`), más `permalink` (`/artista/titulo`, que no debe usarse como identidad porque puede cambiar).
- **Licencia de contenido:** campo `license` = `null` en la muestra → **UNKNOWN** por pista.
- **Términos de API / de uso de terceros:** **UNKNOWN** (la página de términos devolvió error 500; la documentación de API solo dio navegación). No se puede afirmar si una app de terceros puede reproducir el audio con su propio motor bajo sus condiciones, aunque técnicamente la API devuelve la URL de stream.
- **Pregunta crítica del encargo:** «¿la API permite realmente que una app de terceros reproduzca audio directamente?» → **Técnicamente sí** (URL de stream en la respuesta); **contractualmente UNKNOWN**.

### 5.3 Internet Archive / contenido abierto

- **Catalog/Search:** YES (`advancedsearch.php`; la sonda `collection:opensource_audio AND mediatype:audio` devolvió ~2,96 millones de elementos: **no es un catálogo musical**; incluye cualquier audio).
- **Metadata:** YES (`/metadata/{identifier}`: `files` con `name`, `format`, `size`, `md5`…; `metadata` con `mediatype`, `collection`, `title`…).
- **Artwork:** LIMITED. Hay derivados de imagen por ítem (`__ia_thumb.jpg`, PNG); no es artwork de álbum normalizado.
- **Playback:** los archivos existen como ficheros descargables (A – direct file URL). El formato exacto de URL de descarga **no se verificó** en la documentación consultada (UNKNOWN en esta investigación). Descarga técnica ≠ permiso de uso.
- **Identidad:** el ítem se identifica por `identifier` (cadena); una «pista» es un **archivo dentro de un ítem** → la identidad de pista requiere (ítem, archivo).
- **Licencia:** por ítem y declarada por el subidor. En dos registros consultados, **`licenseurl`, `rights` y `possible-copyright-status` estaban ausentes**. Internet Archive declara: «does not make guarantees as to the copyright status of items» y que el usuario debe asegurar un uso no infringente; las licencias CC o similares valen «en la medida en que confíes en la declaración». Terms of Use: sin contenido útil leído.
- **Utilizable por Taki:** catálogo/metadata/audio técnicamente; **solo con filtrado por licencia explícita** verificable (p. ej. `licenseurl` CC presente), y aun así la fiabilidad la deja el subidor. No hay garantía de uso legal por defecto.
- **Límites/rate limits/costes:** UNKNOWN.

### 5.4 Openverse (agregador de contenido abierto)

- **Observado:** `GET /v1/audio/?q=…` devolvió, sin credenciales, un resultado con `id` UUID, `url` (al proveedor original, en la muestra Jamendo), `license`, `license_url`, `creator`, `provider`/`source`, `foreign_landing_url`, `thumbnail`, `duration` y `audio_set`.
- **Valor:** licencia normalizada por elemento y enlace al origen. Advierte que «no puede hacer afirmaciones sobre la exactitud de la información de licencia» y que debe verificarse.
- **Límites, registro, términos de uso de la API:** UNKNOWN (la página de referencia leída no los detalla).
- **Relación con Taki:** es una capa de descubrimiento sobre otras fuentes; no sustituye los términos del proveedor de origen (Jamendo exige sus condiciones aunque se llegue vía Openverse; afirmación inferida, no verificada).

### 5.5 Spotify

- **Web API:** metadata, búsqueda, control de reproducción, biblioteca; autenticación por Authorization Code (+PKCE) o Client Credentials. La documentación indica: **«You need a Spotify Premium account to use the Web API»**.
- **Modos de cuota:** *development mode*: hasta **5 usuarios** autenticados permitidos explícitamente y **el propietario de la app debe tener Premium**; *extended quota mode*: usuarios ilimitados pero para **organizaciones** (desde 2025-05-15), con requisitos como entidad legal, servicio lanzado y **mínimo 250 000 MAU** y viabilidad comercial.
- **Cambios recientes (oficiales):** 2024-11-27: las apps nuevas o en development mode pierden Audio Features, Audio Analysis, Recommendations, Related Artists, playlists editoriales y las previews de 30 s en respuestas multi-get (`SimpleTrack`); 2026-02: se eliminan endpoints de navegación del catálogo y de obtención múltiple, se quitan campos como `popularity` y `available_markets`, y el `limit` de `/search` baja a un máximo de 10.
- **Playback:** 
  - *Web Playback SDK:* biblioteca JavaScript «client-side only» que crea un dispositivo Spotify Connect **en el navegador**; requiere **Premium**; «must not be used in commercial projects without Spotify's prior written approval».
  - *Android SDK:* **control remoto** de la app de Spotify («interact with the Spotify app running in the background as a service»; «Processing of playback and caching as well as network traffic is accounted for by the Spotify app»). Un paquete de comunidad indica que la app de Spotify debe estar instalada.
  - No existe URL de audio.
- **Términos (extracto):** el *streaming* solo para suscriptores Premium; prohíbe facilitar «stream ripping»; limita el almacenamiento local a metadata, artwork o sincronización offline con tiempo limitado; prohíbe entrenar modelos de ML/IA con el contenido; las apps de streaming no pueden usarse comercialmente salvo excepciones. Detalle exacto de almacenamiento: reverificar.
- **Pregunta crítica:** *¿Puede Taki obtener una canción de Spotify y reproducir directamente su audio usando solo una API oficial de terceros?* → **NO**, según la documentación consultada: la reproducción es por SDK web (navegador, Premium) o por control de la app oficial; no hay acceso al audio.

### 5.6 Deezer

- **API pública:** la sonda sin credenciales devolvió los datos de una pista: `id`, `title`, `isrc`, `duration` (s), `link`, `rank`, `release_date`, `artist`, `album` y `cover_small/medium/big/xl` (56, 250, 500, 1000 px).
- **Preview:** campo `preview` (mp3 de 30 s) con URL **firmada con expiración** (`hdnea=exp=…`). **F – preview only; B – expiring.**
- **Full playback:** las directrices oficiales indican «30-second extracts» para todos y «Full Track / Unlimited» para usuarios Premium/HiFi/Family «via API/Plugins»; además: «Full-length tracks URLs must never be accessible to the end-user from your application», «Local Storage/Offline Storage of audio data is strictly forbidden». Las páginas de SDK no se pudieron leer y fuentes secundarias indican que los SDK ya no están documentados → **mecanismo oficial de reproducción completa para apps nuevas: UNKNOWN / INSUFFICIENT INFORMATION.**
- **Términos:** uso «strictly limited for a non-commercial purpose and in a non-commercial environment»; sin cláusula de caché explícita en lo leído; debe respetarse la marca/logos.
- **Auth/límites/registro:** datos públicos accesibles sin autenticación (sonda); autenticación para funciones de usuario y límites: UNKNOWN. Estado actual del registro de nuevas apps: UNKNOWN.

### 5.7 Apple Music

- **Apple Music API:** catálogo completo (canciones, álbumes, artistas, playlists, vídeos, estaciones, listas), búsqueda, metadata y biblioteca del usuario; recomendaciones con autorización. Dispone de objetos `Artwork` y `Preview`. Autenticación: **developer token** (firmado con clave privada de un identificador de MusicKit) y **Music User Token** para datos de usuario.
- **MusicKit:** la página oficial lista **iOS, iPadOS, macOS, tvOS, visionOS, watchOS, Android y Web**. «MusicKit for Android lets you build native Apple Music features into your Android app. Libraries are available to let users sign in to their Apple Music account and play music directly from your app». Dos bibliotecas: **Authentication** (tokens) y **Media Playback** («play songs, albums, and playlists on Apple Music without leaving your app»; controles en pantalla de bloqueo/segundo plano).
- **Playback:** **D – SDK required** (motor propio, no `just_audio`). Requiere cuenta de Apple Music del usuario (implícito en la oferta de suscripción del framework; los requisitos específicos de Android no se pudieron leer → UNKNOWN).
- **Costes/requisitos:** Apple Developer Program **99 USD/año** (página oficial); exención para entidades elegibles. MusicKit/Apple Music API incluidos: no confirmado en esa página.
- **Términos de MusicKit/API:** no localizados (la página de acuerdos solo es un índice) → **UNKNOWN**.
- **Flutter:** no se encontró plugin oficial; la integración sería por canal de plataforma con las bibliotecas nativas (inferencia; Taki ya usa ese patrón con MediaStore).

### 5.8 YouTube / YouTube Music

- **YouTube Data API:** metadata y búsqueda de vídeos. Cuota por defecto según la página oficial (extracto): 10 000 unidades/día para el resto de endpoints y un límite específico de 100 `search.list` al día (el extracto podría estar incompleto: reverificar).
- **Playback:** únicamente mediante el reproductor oficial incrustado (IFrame Player API), en una página/WebView, con viewport mínimo 200×200 px.
- **Políticas (developer policies):** prohíbe «separate, isolate, or modify the audio or video components» del contenido audiovisual (III.I.7); funciones de reproducción **desde un reproductor en segundo plano** no mostrado en la pantalla (III.I.9); «download, import, backup, cache, or store copies» sin aprobación escrita (III.E.1.a); reproducción sin conexión (III.E.1.b); modificar o bloquear funcionalidad del reproductor (III.I.6).
- **Consecuencia:** el reproductor en segundo plano con notificación y controles de bloqueo de Taki es incompatible con esas condiciones. **Clasificación: E – official player required; NOT SUITABLE para el objetivo actual.**
- **YouTube Music:** en la documentación consultada **no apareció una API oficial específica** para terceros. La ausencia en una búsqueda no prueba su inexistencia → **INSUFFICIENT INFORMATION**.
- No se investigó ningún método no oficial.

### 5.9 Otros

- **Free Music Archive:** cerrado en 2018 por falta de financiación (fuente secundaria: prensa) → **NOT SUITABLE** (sin servicio vigente confirmado; una reapertura posterior no se verificó).
- **ccMixter:** comunidad de remixes CC con una API beta histórica; estado actual UNKNOWN → **INSUFFICIENT INFORMATION**.

---

## 6. Capability matrix

Valores: YES / NO / LIMITED / CONDITIONAL / UNKNOWN (con motivo).

| Provider | Search | Catalog/Discovery | Metadata | Artwork | Playback | Auth | API pública | Commercial use | License/Terms |
|---|---|---|---|---|---|---|---|---|---|
| **Jamendo** | YES | YES | YES | YES (600 px máx. vía `imagesize`) | YES – URL de stream completa | API key/credenciales; OAuth2 para usuario | YES (registro) | **NO sin acuerdo** (no comercial libre) | Términos de API + CC por pista |
| **Audius** | YES | YES (tendencias, búsqueda) | YES | YES (150/480/1000) | CONDITIONAL – URL firmada; términos UNKNOWN | API key (pública) + bearer (backend) | YES (plan Free) | UNKNOWN | UNKNOWN (términos no leídos); `license` a menudo `null` |
| **Internet Archive** | YES | LIMITED (2,96 M ítems de audio genérico, no catálogo musical) | YES | LIMITED (derivados por ítem) | CONDITIONAL – archivos descargables; uso según licencia del ítem | No (en las sondas) | YES | CONDITIONAL – según licencia por ítem | Sin garantía de copyright; licencia declarada por el subidor, a menudo ausente |
| **Openverse** | YES | LIMITED (agregador CC) | YES | YES (miniatura) | CONDITIONAL – URL al proveedor de origen | No en la sonda; resto UNKNOWN | YES | CONDITIONAL – según licencia (p. ej. `by-nc-nd`) | Licencia normalizada, sin garantía de exactitud |
| **Spotify** | YES (límite 10 por página desde 2026-02) | LIMITED (endpoints de navegación eliminados) | YES | YES | **NO como audio**; SDK web (Premium) o control de la app oficial | OAuth (code/PKCE/client credentials) | YES, con cuotas restrictivas | **NO** para apps de streaming | Developer Terms / Policy; Premium para streaming |
| **Deezer** | YES | YES | YES | YES (56–1000 px) | LIMITED – preview 30 s; completo UNKNOWN | Público sin auth (sonda); usuario: UNKNOWN | YES (estado de registro UNKNOWN) | **NO** (uso no comercial) | Términos: no comercial; sin almacenamiento local de audio |
| **Apple Music** | YES | YES (charts, recomendaciones) | YES | YES | CONDITIONAL – MusicKit Android (SDK propio) | Developer token (JWT) + Music User Token | YES, con Apple Developer Program | UNKNOWN | Términos de MusicKit no localizados |
| **YouTube** | YES (cuota restrictiva) | LIMITED | YES | YES (miniaturas) | **Reproductor oficial incrustado únicamente** | API key / OAuth | YES | UNKNOWN | Developer Policies: sin audio aislado, sin segundo plano, sin caché |
| **YouTube Music** | UNKNOWN | UNKNOWN | UNKNOWN | UNKNOWN | UNKNOWN | UNKNOWN | **INSUFFICIENT INFORMATION** (no se halló API oficial) | UNKNOWN | UNKNOWN |

## 7. Playback matrix

Clases: A directo · B firmada/caduca · C HLS/DASH · D SDK · E reproductor oficial · F solo preview · G app externa · H no disponible.

| Provider | Clase(s) | Mecanismo oficial | ¿Encaja con `just_audio`? | Observaciones |
|---|---|---|---|---|
| Jamendo | **A** | `audio` (stream) en `/tracks`; formatos mp3/ogg/flac | Conceptualmente sí (URL) — **no verificado en esta fase** | Caducidad UNKNOWN. Términos: sin diseño para caché/offline |
| Audius | **B** (probable) | `stream.url` firmada + `mirrors` | Conceptualmente sí | Caducidad y términos UNKNOWN; `stream_conditions`/`access` pueden limitar |
| Internet Archive | **A** (archivo) | Ficheros del ítem (`files`) | Conceptualmente sí | Formato de URL de descarga no verificado; licencia por ítem |
| Openverse | **A** (vía proveedor) | `url` del resultado | Sí, como el proveedor de origen | Hereda términos del origen |
| Spotify | **D / G** (no audio) | Web Playback SDK (navegador, Premium); Android App Remote controla la app Spotify | **No** | Sin URL de audio. Apps de streaming: sin uso comercial |
| Deezer | **F** (+ **B** en la URL) | `preview` 30 s firmada con expiración | Solo previews | Completo: UNKNOWN; URL completa nunca expuesta al usuario; sin almacenamiento local |
| Apple Music | **D** | MusicKit for Android (Media Playback) | **No** (motor del SDK) | Cuenta de Apple Music; términos Android UNKNOWN |
| YouTube | **E** | IFrame Player en WebView | **No** | Políticas prohíben audio aislado y segundo plano |

*Preview ≠ streaming completo:* Deezer (30 s) no equivale a reproducción completa.

## 8. Authentication matrix

| Provider | Credenciales de la app | Usuario final | ¿Secreto fuera de la app? | Notas |
|---|---|---|---|---|
| Jamendo | API key/credenciales personales | No para catálogo; OAuth2 para cuenta | No se sabe (UNKNOWN) | «No compartir» las credenciales (términos) |
| Audius | API Key | No para consultas públicas | Bearer token **solo backend**; la API key es pública | Plan Free con límites |
| Internet Archive | Ninguna en sondas | No | — | Límites UNKNOWN |
| Openverse | Ninguna en la sonda | No | — | Registro/límites UNKNOWN |
| Spotify | Cliente registrado (Client ID) | Premium (web playback); usuarios permitidos en dev mode (≤5) | Client Credentials/PKCE | Propietario de la app con Premium en dev mode |
| Deezer | Ninguna para datos públicos (sonda) | UNKNOWN para Premium | UNKNOWN | — |
| Apple Music | Developer token JWT (clave privada de Apple Developer Program) | Music User Token | **Sí: la clave privada no debe estar en la app**; cómo evitar un backend en Android: UNKNOWN | 99 USD/año |
| YouTube | API key / OAuth | No para búsquedas | — | Cuotas |

## 9. License/terms analysis

Separación pedida: **API license · Content license · App license · User license.**

| Provider | API license/terms | Content license | App (condiciones a la app de Taki) | User (condición al oyente) |
|---|---|---|---|---|
| Jamendo | No comercial libre; comercial por acuerdo; sin caché/offline deliberado; atribución con backlink | CC por pista (variable; vista `by-nc-nd`) | No replicar la experiencia/estética de Jamendo | Ninguna cuenta necesaria para escuchar (no verificado) |
| Audius | UNKNOWN | UNKNOWN por pista (`license` null en muestra) | UNKNOWN | UNKNOWN |
| Internet Archive | Sin términos de API útiles leídos | Por ítem; **sin garantía**; a menudo no declarada | Responsabilidad del uso en quien usa | — |
| Openverse | UNKNOWN | CC/dominio público normalizado, sin garantía | Hereda la del origen | — |
| Spotify | Developer Terms: streaming solo Premium; sin stream ripping; sin ML/IA; caché restringida | © del catálogo (no redistribuible) | Sin uso comercial para apps de streaming | Premium |
| Deezer | No comercial; sin almacenamiento local de audio | © del catálogo | Logos y marcas controladas | Premium/HiFi/Family para completo |
| Apple Music | UNKNOWN (no localizados) | © del catálogo | UNKNOWN | Cuenta de Apple Music |
| YouTube | Developer Policies: sin audio aislado, sin segundo plano, sin caché | © de los creadores | Reproductor sin modificar | — |

Distinción clave (un proveedor puede permitir consultar metadata sin permitir descargar, almacenar, redistribuir, reproducir fuera de su app ni usar comercialmente). En lo consultado: **Spotify, Deezer y YouTube permiten metadata sin permitir reproducción propia del audio**; **Jamendo permite reproducir pero restringe caché/offline y uso comercial**; **Internet Archive y Openverse delegan la licencia en cada elemento**.

## 10. Artwork analysis

| Provider | Origen | Tamaños | Autenticación | Caducidad | Hotlink/caché local |
|---|---|---|---|---|---|
| Jamendo | URL (`image`, `album_image`) | `imagesize` 25…600 | No indicada | UNKNOWN | Términos: sin diseño para caché del *contenido*; artwork UNKNOWN |
| Audius | URL + mirrors | 150, 480, 1000 | No en sonda | UNKNOWN | UNKNOWN |
| Internet Archive | Derivados por ítem | Variable | No | — | UNKNOWN |
| Openverse | `thumbnail` propio (proxy) | UNKNOWN | No en sonda | UNKNOWN | UNKNOWN |
| Spotify | Imágenes en la API | (no verificado aquí) | Token | UNKNOWN | Términos: metadata/artwork cacheables de forma limitada (reverificar) |
| Deezer | URL por tamaños | 56, 250, 500, 1000 | No (datos públicos) | No observada en portadas | UNKNOWN; logos controlados |
| Apple Music | Plantilla de URL con ancho/alto (objeto `Artwork`) | A petición (no verificado) | Developer token | UNKNOWN | UNKNOWN |
| YouTube | Miniaturas | Fijas | Key | UNKNOWN | UNKNOWN |

Observación común: el artwork remoto es **URL + tamaño (o plantilla/variantes)**, no `albumId` entero. Las reglas de caché local y hotlinking quedan **UNKNOWN** para casi todos y deben confirmarse antes de extender `ArtworkCache`/`ArtworkFileCache`. No se implementó descarga ni caché.

## 11. Identity analysis

| Provider | Tipo de ID | Ejemplo observado | Estabilidad | Namespace necesario |
|---|---|---|---|---|
| Jamendo | Numérico (pista) | `29866` | Estable (no verificado formalmente) | Sí |
| Audius | Cadena corta | `mWB22` | Estable (no verificado); `permalink` **no** apto | Sí |
| Internet Archive | `identifier` de ítem (+ archivo) | `thems-fightn-words-part-2` | Estable por ítem; archivo por nombre | Sí; **identidad de 2 partes** |
| Openverse | UUID propio | `fb073ace-…` | Propio de Openverse, no del origen | Sí (y el origen real está en `provider`/`foreign_landing_url`) |
| Spotify | Identificadores propios | (no verificado aquí) | UNKNOWN | Sí |
| Deezer | Numérico | `3135556` (+ `isrc`) | Estable | Sí |
| Apple Music | `MusicItemID` (cadena) | — | UNKNOWN; hay «equivalencias» entre versiones | Sí |
| YouTube | `videoId` | — | UNKNOWN | Sí |

Conclusión para la identidad `source + externalId` de Fase 2.0: **confirmada y suficiente si `externalId` es una cadena opaca definida por cada fuente.** Números y cadenas caben; Internet Archive necesita una cadena compuesta (ítem + archivo). El ISRC (visto en Deezer) **no** puede ser la identidad de Taki (no todos lo exponen). Ninguna identidad depende de la URL.

## 12. Cost/rate-limit analysis

| Provider | Coste de API | Límites | Requisitos de cuenta/producción |
|---|---|---|---|
| Jamendo | Gratuita no comercial | 35 000 peticiones/mes (no comercial); límites adicionales reservados | Comercial: contacto con ventas |
| Audius | Plan Free gratuito | 10 req/s, 500 000/mes; Unlimited por contacto | API key |
| Internet Archive | UNKNOWN | UNKNOWN | — |
| Openverse | UNKNOWN | UNKNOWN | — |
| Spotify | Gratuita | Dev mode ≤5 usuarios; extended mode organizaciones con ≥250 000 MAU | Premium del propietario en dev mode |
| Deezer | Gratuita (datos públicos) | UNKNOWN | UNKNOWN |
| Apple Music | 99 USD/año (Developer Program) | UNKNOWN | Identificador + clave privada |
| YouTube | Gratuita con cuota | Extracto: 10 000 unidades/día y límite de `search.list`; reverificar | Política de revisión |

No se calculan costes hipotéticos.

## 13. Android/Flutter considerations

- **Flutter:** no se halló ningún SDK oficial de Flutter en los proveedores consultados. Para Jamendo, Audius, Deezer (datos públicos), Internet Archive y Openverse el acceso es **HTTP/JSON** (un cliente HTTP de Dart sería suficiente; no se añade ahora). Para Spotify hay paquetes **de comunidad** (`spotify_sdk`) que envuelven el control remoto de la app de Spotify. Para Apple Music y YouTube (WebView) haría falta integración de plataforma (canales o WebView); inferencia, no verificada.
- **Motor de audio:** Taki usa `just_audio` + `audio_service`. Las fuentes por URL encajan conceptualmente con `AudioSource.uri` (API documentada de la librería; **no verificado en esta fase en dispositivo**). Las fuentes por SDK (Apple Music) o control remoto (Spotify) **no** pasan por `just_audio` y exigirían un motor/puerto de reproducción adicional.
- **Segundo plano/bloqueo:** YouTube lo prohíbe por política; Apple MusicKit Android lo declara soportado; Spotify lo delega a su app; Jamendo/Audius dependerían del motor propio de Taki (donde ya existe).
- **Red/permisos:** cualquier fuente remota requeriría `INTERNET` en el manifiesto principal (hoy solo en debug/profile). No se modifica en esta fase.

## 14. Scenario analysis

| Escenario | ¿Posible según la investigación? | Fuentes que lo habilitan | Condiciones/riesgos |
|---|---|---|---|
| **A** Catálogo + metadata, reproducción local | **Sí, técnicamente** | Deezer, Spotify, Apple, Jamendo, Openverse, etc. | Términos de uso de metadata/artwork por proveedor (almacenamiento, atribución, uso no comercial) |
| **B** Catálogo + metadata + reproducción remota | **Sí, solo con fuentes por URL abiertas**, o por SDK propio (Apple) | Jamendo, Audius, IA/Openverse; Apple con motor propio | Licencias CC por pista; términos de Audius UNKNOWN; Jamendo no comercial y sin caché/offline |
| **C** Catálogo abierto + reproducción directa | **Sí** | Jamendo, Audius, (IA/Openverse filtrando licencia) | Como B; verificación de licencia explícita |
| **D** Varios proveedores | **Sí, arquitectónicamente**, con **dos familias de reproducción** (URL vs motor del proveedor) | Combinación | Complejidad del motor de reproducción y de las políticas por fuente |

Excluidos por la investigación: reproducción propia del audio de Spotify, YouTube y Deezer completo (sin mecanismo oficial verificado para una app nueva).

## 15. Architectural impact

Relación con Fase 2.0:

| Decisión de 2.0 | ¿Sigue válida? | Hallazgo |
|---|---|---|
| Identidad `(fuente, id externo)` | **Sí** | IDs numéricos, cadenas, UUID e IA (2 partes) caben como **cadena opaca**; ningún ID es una URL |
| `Song` = identidad + metadata; recurso por puerto resolvedor | **Sí, con ajuste** | Un resolvedor que devuelva solo una URL **no cubre** Apple (SDK) ni Spotify (control remoto). El resultado de resolución debería poder expresar: «recurso por URL» (con caducidad/cabeceras), «reproducir con el motor del proveedor» o «no disponible/requiere app externa» |
| Resolución anticipada vs perezosa | Sigue abierta | URLs firmadas (Audius, previews de Deezer con `exp`) favorecen la resolución **perezosa y renovable** |
| `features/catalog` separado, dependencias solo hacia `core` | **Sí** | Las reglas de atribución (Jamendo) y de marca (Deezer) son de presentación del catálogo: encajan en `catalog/presentation` y callbacks de `app/` |
| Adapters de proveedor en `catalog/infrastructure/<proveedor>` | **Sí** | Los DTO y la autenticación (p. ej. token JWT de Apple, bearer de Audius) son del adapter; el secreto nunca en el dominio |
| Favoritos/playlists con referencia + respaldo de metadata | **Sí, con cautela** | Algunos términos restringen el almacenamiento local de metadata/artwork (Spotify) o de audio (Deezer, Jamendo, YouTube). Conviene que el **respaldo de metadata sea opcional y dependiente de la fuente** |
| Artwork `(fuente, id)` a largo plazo | **Sí, con ajuste** | El artwork remoto es URL + tamaño/variantes; la referencia de artwork debería poder ser una **URL + política de tamaño**, no solo un id. Reglas de caché local UNKNOWN |
| `ArtworkFileCache` (lockscreen) | Reabrir | Si una fuente prohíbe almacenar, guardar el artwork remoto en archivo podría incumplir términos; o la notificación puede usar URL remota |
| Frontera de autenticación | Nueva precisión | Autenticación **por adapter**; Apple exige un secreto de firma que no debe vivir en la app → posible componente de backend (UNKNOWN) |
| Privacidad | Sin cambio de código | La promesa del README («sin backend, sin cuentas, sin telemetría») cambiaría con cualquier fuente; decisión de producto |

**Ningún hallazgo obliga a cambiar el código en esta fase.** Dos cambios de **diseño** a incorporar al trabajo de 2.3 y 2.5: el **resultado de resolución** no es solo una URL, y la **referencia de artwork** no es solo un entero.

## 16. Known unknowns

(No se convierten en suposiciones.)

1. Audius: términos de uso/API de terceros; caducidad de `stream.url`; licencia por pista.
2. Jamendo: proceso exacto de clave de API; caducidad de las URL de stream; licencias comerciales concretas.
3. Internet Archive: formato oficial de URL de descarga; rate limits; términos de uso de API.
4. Openverse: límites, registro, términos de API.
5. Spotify: detalle literal de las cláusulas de almacenamiento; requisitos exactos de Android App Remote (app instalada, Premium) en la documentación oficial; formatos de ID.
6. Deezer: mecanismo oficial vigente de reproducción completa para apps nuevas; estado del registro de aplicaciones; límites.
7. Apple Music: términos de MusicKit/API; requisitos concretos de MusicKit para Android (suscripción, versión mínima, estado de la biblioteca); cómo emitir el developer token sin exponer la clave en Android; integración Flutter.
8. YouTube Music: existencia de una API oficial para terceros; YouTube Data API: cifras de cuota exactas.
9. Reglas de caché/hotlinking de artwork en todos los proveedores.
10. Comportamiento real de `just_audio` con URLs http(s) (y con cabeceras) en este proyecto.
11. Free Music Archive y ccMixter: estado actual (solo fuentes secundarias).

## 17. Deferred decisions

| Decisión | Motivo |
|---|---|
| Elegir proveedor(es) | Falta verificar términos UNKNOWN y decidir producto (comercial/no comercial) |
| Modelo de negocio (¿Taki es comercial?) | Jamendo, Deezer y Spotify lo condicionan |
| Motor de reproducción adicional (SDK/control remoto) | Solo si se elige una fuente por SDK |
| REST/GraphQL, cliente HTTP, almacenamiento de credenciales | Dependen del proveedor |
| Backend propio para tokens (Apple) | Dependería de una decisión de proveedor |
| Política de caché de artwork y de metadata de respaldo | Dependen de los términos de cada fuente |
| Política de deduplicación local/remoto | Decisión de producto (heredada de 2.0) |
| Cambios de README/manifiesto (`INTERNET`, privacidad) | Decisión de producto |

**DECIDED (heredado y confirmado):** identidad `(fuente, id externo)` como cadena opaca; recurso reproducible separado de la identidad; `features/catalog` independiente del Player; adapters por proveedor; `SongMatcher` es una política de la fuente local.

**RECOMMENDED NEXT STEP:** ver §18.

## 18. Recommended next phase

**Phase 2.2 — Identidad musical (aditiva, independiente de proveedor)**, como estaba prevista, con estos requisitos derivados de la investigación:

1. `externalId` como **cadena opaca** (soporta ids numéricos, cadenas y compuestos como ítem+archivo de Internet Archive).
2. La fuente es una **etiqueta abierta**; ningún proveedor en el dominio.
3. No introducir todavía el resolvedor ni cambios de SQLite.

Trabajo previo o paralelo recomendado (**Phase 2.1b, verificación**): reverificar directamente en las páginas oficiales los puntos UNKNOWN críticos (términos de Audius, términos de MusicKit/Android, términos completos de Jamendo, estado de Deezer y URL de descarga de Internet Archive), y registrar los resultados. Es documentación, sin código.

Orden sugerido posterior (sujeto a 2.1b): 2.3 (resolvedor con resultado más rico que una URL, prototipo con `just_audio` y URL de prueba), 2.4 (persistencia de identidad), 2.5 (referencia de artwork), 2.6 (esqueleto de `catalog`).

## 19. Final factual conclusion

**PHASE 2.1 READY FOR ARCHITECTURE IMPLEMENTATION** — limitado a las fases independientes del proveedor (2.2 a 2.4), porque:

- Está claro qué fuentes dan **catálogo** (todas las consultadas excepto YouTube Music y FMA), **metadata** (todas), **artwork** (todas, con reglas de caché UNKNOWN), **previews** (Deezer, y objetos `Preview` en Apple/Spotify con limitaciones), **reproducción completa** (Jamendo y Audius por URL, con condiciones; Internet Archive/Openverse según licencia por ítem; Apple Music con SDK propio) y **no disponible como audio** (Spotify, YouTube, Deezer completo).
- Las restricciones legales y técnicas relevantes están identificadas (uso no comercial, sin caché/offline, atribución, Premium, políticas de YouTube, licencias CC por pista) y los puntos desconocidos están enumerados sin suposiciones.
- La arquitectura de Fase 2.0 sigue siendo adecuada, con dos ajustes de diseño (resultado de resolución más rico que una URL; referencia de artwork no entera) y una precaución (metadata de respaldo opcional por fuente).
- **No se selecciona ningún proveedor**: esa decisión queda para después de 2.1b y de la decisión de producto sobre uso comercial.

### Validación

- Único archivo de esta fase: `docs/PHASE_2_1_MUSIC_PROVIDER_RESEARCH.md`. Sin cambios en `lib/`, `test/`, `pubspec.*`, `android/` ni `assets/`. Sin commit ni push.
