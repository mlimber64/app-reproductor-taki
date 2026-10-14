# Fase 2.1B — Verificación documental de proveedores

**Fecha de consulta: 2026-09-30.** Complementa (no sustituye) `docs/PHASE_2_1_MUSIC_PROVIDER_RESEARCH.md`, que se conserva íntegro.
**Alcance:** auditoría documental de las afirmaciones críticas de la Fase 2.1. Sin código, dependencias, permisos, manifiestos ni UI. **No se elige proveedor.**

---

## 1. Executive Summary

- **Audius:** queda resuelto lo principal. Los documentos oficiales (Terms of Use del 2025-10-05 y **Open Music License** del 2025-07-02, leídos como texto íntegro desde los PDF oficiales) **conceden expresamente a las aplicaciones «Music Player» el derecho a reproducir (stream) el contenido** accesible por la API, salvo que el creador lo haya excluido u ofrezca una **licencia alternativa** por pista. **Siguen sin poder leerse los API Terms** (error 500), por lo que límites, uso comercial a nivel de API y otras condiciones quedan **UNVERIFIED**.
- **Apple Music:** verificado que existe **MusicKit for Android** con bibliotecas oficiales de autenticación y de reproducción, que el *Music User Token* en Android es manual y que el *developer token* exige pertenecer al Apple Developer Program (JWT ES256, caducidad máx. 6 meses). **No verificados:** términos de uso, requisito explícito de suscripción en Android, versión mínima y cualquier mención a Flutter.
- **Deezer:** verificado que la API pública solo entrega **extractos de 30 s** («no audio streaming available except 30s extracts»), que el audio completo se vincula a usuarios Premium y a «Plugins/SDK nativos», que el almacenamiento local de audio está prohibido y que los términos limitan a uso **no comercial**. **Sigue UNKNOWN** si hoy existe un mecanismo de reproducción completa para **apps nuevas** (la página del SDK devuelve 404 y el registro de apps no pudo consultarse).
- **Jamendo:** verificado en lo esencial: `client_id` obligatorio, licencia **Creative Commons por contenido** que el desarrollador debe respetar, uso libre **solo no comercial**, **sin diseño para caché ni offline**, atribución con enlace, y obligación de retirar el contenido al terminar el acuerdo.
- **Internet Archive:** verificado que **no garantiza** el estado de copyright de ningún elemento y que la responsabilidad del uso recae en el usuario; los metadatos de licencia los declara el subidor y a menudo faltan. La página de Terms of Use no pudo leerse íntegra; el formato oficial de URL de descarga **no se verificó**.
- **Spotify:** verificado con la política oficial: el streaming es solo para suscriptores **Premium**, las apps de streaming no pueden explotarse comercialmente, y los únicos mecanismos oficiales de reproducción **controlan** la reproducción (Web Playback SDK en navegador; SDK de Android que gobierna la app de Spotify). **No se documenta ningún mecanismo que entregue audio utilizable como `AudioSource` de `just_audio`.**
- **YouTube:** verificado con las políticas oficiales: reproducción solo con el reproductor oficial sin modificar; prohibidos separar audio de vídeo, reproducir desde un reproductor en segundo plano y almacenar/cachear el contenido. **YouTube Music:** no se halló API oficial pública para terceros; se mantiene **UNKNOWN**.
- **Openverse:** verificado como **índice** de obras CC/dominio público **sin garantía de exactitud de la licencia**; no es un proveedor de reproducción.
- **Arquitectura: ARCHITECTURE UNCHANGED.** Ninguna verificación contradice Phase 2.0; refuerzan tres puntos ya anotados: identidad como cadena opaca, resultado de reproducción más rico que una URL y metadata de respaldo opcional/limitada por fuente.

**Conclusión: PHASE 2.1B PARTIALLY VERIFIED** (§17).

---

## 2. Verification methodology

1. Solo fuentes oficiales del proveedor. Fuentes secundarias (pub.dev, foros, prensa) **no** se usan como prueba definitiva; cuando aparecen se indican y no cambian el estado.
2. Calidad de la evidencia, de mayor a menor:
   - **Texto íntegro:** PDF oficiales de Audius (Terms of Use y Open Music License) convertidos a texto con PyMuPDF; documentación de Apple en Markdown sin procesar (`.md`).
   - **Resumen automático de la página oficial:** la herramienta de descarga devuelve un resumen, no el texto literal. Las citas de estos casos no se garantizan literales. Se marcan con confianza **Media**.
   - **Observación de la API:** una petición de solo lectura sin credenciales que muestra la forma de los datos (Fase 2.1). Es evidencia de comportamiento, **no de permiso**.
3. Estados permitidos: VERIFIED, PARTIALLY VERIFIED, NOT VERIFIED, CONTRADICTED, UNKNOWN. Una página que no pudo leerse es **NOT VERIFIED / UNKNOWN, nunca NO**.
4. Las inferencias se marcan como tales y no cambian el estado.

## 3. Official sources

Todas consultadas el 2026-09-30.

| Proveedor | URL oficial | Resultado |
|---|---|---|
| Audius | https://audius.co/documents/TermsOfUse.pdf | **Leída íntegra** (32 p., actualizada 2025-10-05) |
| Audius | https://openaudiofoundation.org/open-music-license.pdf (redirección de audius.org/open-music-license.pdf) | **Leída íntegra** (3 p., «Last Updated: 2 July, 2025») |
| Audius | https://blog.audius.co/posts/audius-terms-of-service-update | Resumen |
| Audius | https://audius.co/legal/api-terms, https://audius.co/documents/APITerms.pdf | **No legible** (500 / 404) |
| Audius | https://docs.audius.co/llms.txt, /llms-full.txt, /docs/sdk/tracks.md, README del SDK (jsdelivr `@audius/sdk@15.3.1`) | Parcial |
| Audius | https://docs.audius.co/developers/api , /rest-api , /api/stream-track , /api/get-track-access-info | Solo navegación; **sin detalle** |
| Audius | https://api.audius.co/v1/tracks/mWB22 | Observación de la API |
| Apple | https://developer.apple.com/musickit/ , /musickit/android/ (Javadoc: overview-summary, package-summary de `authentication` y `playback.controller`) | Leídas |
| Apple | https://developer.apple.com/documentation/AppleMusicAPI/generating-developer-tokens.md , /user-authentication-for-musickit.md , /documentation/musickit.md , /applemusicapi.md | **Texto íntegro** |
| Apple | https://developer.apple.com/programs/whats-included/ , /help/account/services/musickit/ | Resumen |
| Apple | Términos de MusicKit/Apple Music API | **No localizados** |
| Deezer | https://developers.deezer.com/guidelines , /termsofuse | Resumen |
| Deezer | https://developers.deezer.com/sdk | **404** |
| Deezer | https://developers.deezer.com/api , /api/oauth , /myapps | Solo cabecera/login |
| Jamendo | https://devportal.jamendo.com/api_terms_of_use | Resumen (por cláusulas) |
| Jamendo | https://developer.jamendo.com/v3.0 , /v3.0/tracks , /v3.0/authentication , /v3.0/docs | Resumen |
| Internet Archive | https://help.archive.org/help/rights/ , https://blog.archive.org/2014/12/30/update-to-terms-of-use/ | Resumen |
| Internet Archive | https://archive.org/developers/md-read.html , /md-record.html , /index-apis.html | Resumen |
| Internet Archive | https://archive.org/about/terms(.php) , https://help.archive.org/help/internet-archive-access-policy/ | **Sin el contenido pedido** |
| Spotify | https://developer.spotify.com/policy , /terms , /documentation/web-api , /web-playback-sdk , /android , /documentation/web-api/reference/start-a-users-playback , /concepts/quota-modes , /references/changes/february-2026 , /blog/2024-11-27-changes-to-the-web-api | Resumen |
| YouTube | https://developers.google.com/youtube/terms/developer-policies , /terms/required-minimum-functionality , /youtube/v3/getting-started , /youtube/v3/determine_quota_cost , /youtube/iframe_api_reference | Resumen |
| Openverse | https://docs.openverse.org/api/reference/made_with_ov.html , /api/guides/quickstart.html | Resumen |
| Openverse | `…/rate-limits.html`, `…/meta/faq.html` | **404** |

---

## 4. Audius verification

**Pregunta crítica:** *¿La API oficial permite a una aplicación de terceros obtener/reproducir audio completo mediante un mecanismo permitido oficialmente?*

**Respuesta basada en fuentes oficiales: permitida en principio, con condiciones aún no verificables en su totalidad.**

Evidencia (texto íntegro de los PDF oficiales):
- **Open Music License, preámbulo:** «developers creating or operating software applications designed to play back audio files on the Audius Protocol (“Music Players”) need legal rights to conduct activities like publishing, sharing, and streaming Licensed Material».
- **OML §1.2:** el Licenciante concede a los Music Players «a worldwide, non-exclusive, royalty-free, perpetual, irrevocable right and license, with the right to sublicense, to reproduce, publicly perform, distribute, electronically or digitally transmit, stream, and otherwise use in whole or part, the Licensed Material, in connection with a Music Player's services».
- **OML §1.3 (licencia alternativa):** un creador puede publicar bajo otra licencia indicando una URI en un campo legible del JSON vinculado al contenido → la licencia **puede variar por pista**.
- **OML §1.5:** si un licenciatario usa el material con fines comerciales debe conservar identificación del licenciante, aviso de copyright, referencia a la OML y enlace al contenido (→ la OML contempla uso comercial).
- **Terms of Use (2025-10-05):** «By default, Content you upload … is made available to third-party services via the Audius API and is subject to the Open Music License. You may opt out … by disabling the API access» (toggle del creador). Además: el uso por servicios de terceros «will not be governed by the Terms of Use, but rather the API Terms and the Open Music License». Los creadores pueden elegir entre varias licencias CC (incluidas variantes **NC** y **ND**).
- **Blog oficial:** «Tracks are API-accessible unless you opt out in your settings» (resumen).

Puntos pedidos:

| Punto | Estado | Evidencia |
|---|---|---|
| A. API oficial | VERIFIED | API pública REST + SDK (README oficial) |
| B. Búsqueda/catálogo | PARTIALLY VERIFIED | SDK `tracks`: `getTrack`, `getBulkTracks`, `getTrendingTracks`, `searchTracks`… (docs oficiales); la referencia REST no fue legible |
| C. Metadata | PARTIALLY VERIFIED | Observación de la API (campos de pista); docs REST no legibles |
| D. Artwork | PARTIALLY VERIFIED | **Observación**: `150x150`, `480x480`, `1000x1000` y espejos; no documentado en lo leído |
| E. Endpoint de stream | NOT VERIFIED | La doc SDK `tracks.md` no lista un método de stream; la referencia REST no fue legible. Lo observado: la respuesta de pista incluye `stream.url` |
| F. Formato del recurso | PARTIALLY VERIFIED | Observación: URL a un nodo de contenido (`/tracks/cidstream/<cid>?signature=…`) |
| G. Autenticación | VERIFIED | README oficial: «API Key … safe to include in client-side code»; «Bearer Token … Never include … in frontend code» |
| H. Rate limits | VERIFIED | README oficial: plan Free 10 req/s y 500 000/mes, «always free»; Unlimited por contacto |
| I. Caducidad de URLs | PARTIALLY VERIFIED / TTL UNKNOWN | La URL observada incluye `signature` y `timestamp`. Docs oficiales (llms-full) mencionan una «short-lived signature» en el flujo de acceso restringido del creador; **no documentan la duración** del stream normal |
| J. Condiciones de uso | PARTIALLY VERIFIED | OML y Terms of Use leídos; **API Terms no legibles** |
| K. Apps de terceros | VERIFIED (principio) / UNVERIFIED (API Terms) | OML §1.2 y Terms of Use |
| L. Comercial/no comercial | PARTIALLY VERIFIED | OML §1.5 contempla licencias comerciales con atribución; los API Terms y las licencias alternativas por pista pueden restringirlo |

Separación pedida: **metadata** (API), **stream** (concedido a Music Players por la OML), **URL temporal** (firmada; TTL UNKNOWN), **descarga** (`is_downloadable`/`access.download` observados por pista; condiciones UNVERIFIED), **reproducción** (concedida por OML §1.2 «in connection with a Music Player's services»). La existencia de un campo `stream.url` **no** se toma como permiso; el permiso proviene de la OML, y cada pista puede optar por salir de la API o por otra licencia.

Observación de identidad (Fase 2.0): la pista observada tiene id corto `mWB22` y la URL de stream contiene un `trackId` **numérico** distinto (`823520`). La identidad externa debe fijarse en **un** id canónico por fuente (cadena opaca).

## 5. Apple Music/MusicKit verification

**Pregunta crítica:** *¿Una aplicación Flutter Android puede utilizar oficialmente Apple Music para reproducción de catálogo?*

**Respuesta:** una **app Android** puede usar oficialmente MusicKit for Android (autenticación y reproducción) con las condiciones de abajo. Que una app **Flutter** pueda hacerlo **no está documentado por Apple** (ni a favor ni en contra): **UNKNOWN**. Integrarlo exigiría capa nativa (inferencia).

| Punto | Estado | Evidencia oficial |
|---|---|---|
| A. Apple Music API | VERIFIED | `applemusicapi.md`: acceso al catálogo y a la biblioteca iCloud del usuario; búsqueda, charts, recomendaciones; objetos `Artwork` y `Preview` |
| B. MusicKit | VERIFIED | Página MusicKit: plataformas Apple, **Android y Web** |
| C. MusicKit for Android | VERIFIED | «Libraries are available to let users sign in to their Apple Music account and play music directly from your app»: **Authentication** y **Media Playback** («without leaving your app»; controles en bloqueo/segundo plano) |
| D. Music User Token | VERIFIED | `user-authentication-for-musickit.md`: «Automatic Music User Token management is not available for Android»; se obtiene con la biblioteca de Android y se envía en la cabecera `Music-User-Token` |
| E. Developer token | VERIFIED | `generating-developer-tokens.md`: JWT **ES256**, `kid` de 10 caracteres, `iss` = Team ID, `exp` ≤ 15 777 000 s (6 meses); firmado con la clave privada de MusicKit; hay límite de peticiones (429) |
| F. Reproducción de catálogo | PARTIALLY VERIFIED | Javadoc oficial: paquetes `playback.controller` (`MediaPlayerController`, «controlling Apple Music media playback», `MediaPlayerControllerFactory`), `playback.queue`, `playback.model`; detalle de requisitos no leído |
| G. Apple Developer Program | VERIFIED | «you need to authorize yourself as a trusted developer and member of the Apple Developer Program»; **99 USD/año** (página oficial); MusicKit se activa en el App ID (Certificates, Identifiers & Profiles) |
| H. Suscripción del usuario | NOT VERIFIED (explícito) | El framework ofrece suscripciones a usuarios sin membresía; no se leyó una cláusula que fije el requisito para Android |
| I. Capacidades en Android | PARTIALLY VERIFIED | Autenticación + reproducción + llamadas a MusicKit Web APIs con tokens |
| J. Flutter | UNKNOWN | Ninguna mención oficial |
| K. SDK necesario para playback | VERIFIED | «Media Playback library» del SDK de Android |
| L. Restricciones de uso / términos | NOT VERIFIED | La página de acuerdos es solo un índice; términos de MusicKit/Apple Music API no localizados |

Detalles adicionales (fuentes oficiales, resumen): la biblioteca de autenticación pide al usuario iniciar sesión y, si **Apple Music no está instalada**, ayuda a descargarla; el SDK se descarga desde el portal de desarrolladores. **No se verificó** la versión mínima de Android ni la licencia del SDK.

Inferencia (no verificada): firmar el developer token exige la clave privada; conservarla en la app tiene riesgos de seguridad y Apple no indica en lo leído dónde generar el token para Android. **Cómo se emitiría sin backend: UNKNOWN.**

Separación pedida: **CATALOG API** (developer token; datos de catálogo) ≠ **PLAYBACK API/SDK** (MusicKit for Android + Music User Token). La existencia de la Apple Music API **no** implica reproducción.

## 6. Deezer verification

**Pregunta crítica:** *¿Existe actualmente un mecanismo oficial para que una app nueva de terceros reproduzca el catálogo completo de Deezer?* → **UNKNOWN.**

| Punto | Estado | Evidencia |
|---|---|---|
| A. API actual | VERIFIED (observación) | `api.deezer.com/track/…` responde sin credenciales (Fase 2.1) |
| B. Estado para apps nuevas | UNKNOWN | `/myapps`, `/api`, `/api/oauth` solo muestran cabecera y «You have to login to accept the terms»; nada sobre apertura o cierre del registro |
| C. Búsqueda | PARTIALLY VERIFIED | Guidelines exigen «Search» como función; endpoint no leído en documentación |
| D. Metadata | VERIFIED (observación) | Campos de pista/álbum/artista |
| E. Artwork | VERIFIED (observación) | `cover_small/medium/big/xl` (56/250/500/1000 px) |
| F. Preview | VERIFIED | Guidelines: «30s extract» para todos los usuarios vía API; observación: URL mp3 con expiración (`hdnea=exp=`) |
| G. Full playback | UNKNOWN | Guidelines: Premium/HiFi/Family obtienen «Full Track / Unlimited» y las apps nativas usan SDK iOS/Android; **pero** la misma página dice que la API implica «Full data access, but no audio streaming available except 30s extracts» |
| H. SDK | UNKNOWN | Guidelines citan SDK nativos; `developers.deezer.com/sdk` devuelve **404** |
| I. Autenticación | UNKNOWN | `/api/oauth` sin detalle |
| J. Términos actuales | PARTIALLY VERIFIED | Ver abajo (texto aparentemente antiguo: alude a «Premium+») |
| K. Restricciones | VERIFIED | Ver abajo |

Cláusulas (resumen de la página oficial): uso del servicio **«strictly limited for a non-commercial purpose»** y sin ingresos directos ni indirectos (IV); completo solo para «Premium+»; el resto hasta **30 s**; **DRM**: no eludir las medidas (V); los términos describen el uso para «personalizar su sitio personal y/o desarrollar páginas web personales». Guidelines: «Full-length tracks URLs must never be accessible to the end-user from your application»; «Local Storage/Offline Storage of audio data is strictly forbidden».

**Corrección respecto a 2.1:** la Fase 2.1 concluía que los SDK habían desaparecido apoyándose en resultados **secundarios**. La documentación **oficial** todavía cita SDK nativos; lo que se comprobó es solo que la página del SDK devuelve 404. La disponibilidad real de un mecanismo de audio completo para una app nueva queda **UNKNOWN** (no NO).

## 7. Jamendo verification

| Punto | Estado | Evidencia oficial (API Terms cláusulas y documentación) |
|---|---|---|
| A. API | VERIFIED | `api.jamendo.com`; formato `http[s]://api.jamendo.com/<versión>/<entidad>/…`; salida JSON/XML |
| B. API key | VERIFIED | `client_id` **obligatorio en cada llamada**; se obtiene registrando una cuenta de desarrollador; plan por defecto de solo lectura; «Read & Write» requiere aprobación. OAuth2 (code 30 s, `access_token` 2 h) solo para escritura y métodos protegidos. Credenciales «strictly personal» (cl. 2) |
| C. Catálogo | VERIFIED | «hundreds of thousands of tracks» |
| D. Metadata | VERIFIED | Campos de `/tracks` |
| E. Artwork | VERIFIED | `image`, `album_image`, `imagesize` 25…600 |
| F. Stream | VERIFIED | `audio` = URL de stream (mp31 por defecto, 96 kbps; `audioformat` mp31/mp32/ogg/flac) |
| G. Descarga | VERIFIED | `audiodownload` y `audiodownload_allowed`; vacío si no se permite |
| H. Caché | VERIFIED | Cl. 3.3: «must not be specifically designed to cache the content»; solo caché razonablemente necesaria |
| I. Offline | VERIFIED | Cl. 3.3: sin diseñar «offering an offline access» |
| J. Atribución | VERIFIED | Cl. 4.1: créditos a los miembros como creadores, a Jamendo como proveedor y **enlace directo** al contenido |
| K. Uso comercial | VERIFIED | Cl. 3.3: «may be used freely for non-commercial uses»; comercial = cualquier uso dirigido a ventaja comercial o compensación, incluidas afiliación o publicidad → contactar con ventas |
| L. Licencia por pista | VERIFIED | Cl. 3.1: cada contenido se publica bajo una licencia Creative Commons y el desarrollador debe **respetar la licencia específica** de cada obra; campo `license_ccurl`; en Fase 2.1 se vio `by-nc-nd` vía Openverse |
| M. Redistribución | PARTIALLY VERIFIED | Cl. 3.1: cumplir la licencia del contenido y no reclamar su propiedad; no se leyó una cláusula específica de redistribución |

Extras verificados: cuotas de 35 000 peticiones/mes para apps no comerciales (página oficial de desarrolladores); cada aplicación necesita un `client_id` propio; cl. 7: al terminar, cesar el uso de la API y **retirar cualquier contenido y referencia a Jamendo**; las aplicaciones no deben replicar la experiencia de Jamendo ni parecerse de forma confusa a su diseño.

**API permission ≠ content license:** el permiso de la API (términos de desarrollador) y la licencia del contenido (CC por pista) son independientes; se deben cumplir **ambos**. **UNKNOWN:** caducidad de las URL de stream; existencia de una cláusula de redistribución más específica.

## 8. Internet Archive verification

**Pregunta crítica:** *¿Puede Taki asumir que un archivo de Internet Archive puede utilizarse libremente?* → **NO. La documentación oficial lo descarta.**

| Dimensión | Estado | Evidencia |
|---|---|---|
| Disponibilidad técnica | PARTIALLY VERIFIED | Metadata Read API: `https://archive.org/metadata/{identifier}` devuelve `files[]` con `name`, `format`, `size`, `md5`… (oficial). **Formato oficial de URL de descarga: NOT VERIFIED** (las páginas `quickstart` y `downloading` no pudieron leerse) |
| Identificación de ítems | VERIFIED | `identifier` único en la URL de metadata |
| Identificación de archivos | VERIFIED | Por `name` dentro del ítem |
| Licencia/metadatos de licencia | VERIFIED (ausencia) | Sin `licenseurl` ni `rights` documentados como obligatorios; el subidor informa derechos «en el campo de descripción» o con una licencia CC. En el ítem de muestra (Fase 2.1) faltaban |
| Copyright | VERIFIED | «The Internet Archive does not make guarantees as to the copyright status of items on archive.org and cannot guarantee information posted on item details or collection pages» |
| Responsabilidad del usuario | VERIFIED | «users make use of the Internet Archive's Collections at their own risk and ensure that such use is non-infringing» |
| Reutilización por terceros | PARTIALLY VERIFIED | Blog oficial (actualización de 2014): el usuario certifica un uso «limited to noninfringing or fair use»; si hay licencia CC u otra declarada, puede usarse según ella «to the extent you trust the declaration and declarer» (Archive es «rarely» el declarante). El resumen también cita la prohibición de «copy offsite any part of the Collections without written permission» (**texto de los Terms actuales no leído**, por lo que no se da por verificado) |

Distinción pedida: **disponibilidad técnica** (archivo descargable) ≠ **licencia del elemento** (declarada por el subidor, a menudo ausente) ≠ **copyright** (no garantizado por Archive) ≠ **permiso de reutilización** (depende de la licencia declarada y de que sea fiable). Streaming dentro de una app de terceros y política de acceso automatizado/límites: **UNKNOWN** (las páginas de términos y de política de acceso no contienen lo pedido).

## 9. Spotify verification

**Pregunta crítica:** *¿Existe una API oficial que entregue audio completo utilizable directamente como `AudioSource` para `just_audio`?* → **En la documentación oficial consultada no existe: todos los mecanismos documentados de reproducción controlan o ejecutan la reproducción en clientes Spotify.** (Una ausencia en las páginas consultadas no prueba un negativo universal.)

| Punto | Estado | Evidencia oficial |
|---|---|---|
| A. Búsqueda/catálogo | VERIFIED | Web API: metadata y búsqueda. Changelog 2026-02: `limit` de `/search` máximo 10; retirados endpoints de navegación y de obtención múltiple |
| B. Metadata | VERIFIED | Campos retirados en 2026-02 (`popularity`, `available_markets`…) |
| C. Artwork | PARTIALLY VERIFIED | Policy II.4.3/II.5: metadata y portadas «may only be used in connection with the underlying content» y no como servicio independiente |
| D. Audio completo | VERIFIED (no documentado) | Sin endpoint de audio |
| E. URL de audio | VERIFIED | Blog 2024-11-27: las URL de preview de 30 s dejan de entregarse en multi-get a apps nuevas o en development mode |
| F. Web Playback SDK | VERIFIED | Biblioteca JavaScript «client-side only» que crea un dispositivo Connect **en el navegador**; requiere Premium; «must not be used in commercial projects without Spotify's prior written approval» |
| G. Spotify Connect | PARTIALLY VERIFIED | `PUT /me/player/play` controla «Spotify clients and Spotify Connect devices»; requiere Premium y el scope `user-modify-playback-state` |
| H. Premium | VERIFIED | Policy IV.1: el streaming «shall only be made available to subscribers to the Premium Spotify Service»; Web API: «You need a Spotify Premium account to use the Web API» |
| I. Reproducción directa con `just_audio` | VERIFIED (no disponible por los mecanismos documentados) | SDK Android: «interact with the Spotify app running in the background as a service»; «Processing of playback and caching as well as network traffic is accounted for by the Spotify app» |
| J. Términos relevantes | VERIFIED | Policy IV.2: prohibidos venta de una app de streaming, e-commerce desde ella y publicidad/patrocinios en ella; III.7: no mezclar ni solapar contenido de Spotify con otro audio; III.14: no usar el contenido para entrenar ML/IA. Terms IV.2.c: no facilitar «stream ripping»; IV.3.1: «you may not store, aggregate or create compilations or databases of Spotify Content, other than as strictly necessary to operate your SDA»; IV.3.2: caché limitada a metadata y portadas o a «Conditional Downloads» (solo Premium) |

Cuotas (oficial): *development mode*: hasta **5 usuarios** permitidos y el propietario de la app debe tener Premium; *extended quota*: organizaciones, con requisitos como ≥250 000 MAU. **No verificado:** que la app de Spotify deba estar instalada para el SDK de Android (la documentación oficial lo sugiere; la afirmación explícita solo aparece en paquetes de la comunidad).

**Control de reproducción ≠ entrega de audio.**

## 10. YouTube verification

Solo mecanismos oficiales (no se investigó extracción alguna).

| Punto | Estado | Evidencia oficial |
|---|---|---|
| A. YouTube Data API | VERIFIED | Metadata y búsqueda; cuota (abajo) |
| B. Búsqueda/metadata | VERIFIED | Data API |
| C. Reproducción incrustada oficial | VERIFIED | IFrame Player API («embed a YouTube video player on your website»); mención a integración de WebView en Android; viewport ≥ 200×200 px; autoplay solo con el reproductor visible (más de la mitad) |
| D. Extracción de audio | VERIFIED | Developer Policies III.I: prohibido «separate, isolate, or modify the audio or video components of any YouTube audiovisual content» y promoverlos por separado |
| E. Reproducción en segundo plano | VERIFIED | III.I: prohibido «features that play content … from a background player, meaning a player that is not displayed in the page, tab, or screen that the user is viewing» |
| F. Almacenamiento | VERIFIED | III.E: prohibido «download, import, backup, cache, or store copies of YouTube audiovisual content» sin aprobación escrita y la reproducción sin conexión; los datos no autorizados solo hasta **30 días** naturales |
| G. Separación audio/vídeo | VERIFIED | Igual que D |
| H. Mecanismos oficiales para terceros | VERIFIED | Reproductor incrustado sin modificar («must not modify, build upon, or block any portion or functionality of a YouTube player») |

Cuota: dos páginas oficiales (`getting-started` y `determine_quota_cost`) devuelven el mismo texto: asignación por defecto de **100 llamadas `search.list`**, 100 `videos.insert` y **10 000 unidades/día** para el resto, y una consulta de búsqueda cuesta 1 unidad; ampliación mediante un formulario de extensión. **PARTIALLY VERIFIED** (resumen; se difiere de la cifra genérica que figuraba en 2.1 como «reverificar»).

## 11. YouTube Music verification

**UNKNOWN — REQUIRES FUTURE VERIFICATION.** En las páginas oficiales de Google/YouTube consultadas no apareció ninguna API pública para terceros específica de YouTube Music. La búsqueda oficial solo devolvió la YouTube Data API y el **Data Portability API** (esquemas para exportar datos de usuario de YouTube y YouTube Music), que **no** es una API de catálogo ni de reproducción. No se infiere nada de la YouTube Data API (instrucción del encargo). Una ausencia en la documentación consultada no equivale a «no existe».

## 12. Openverse verification

| Punto | Estado | Evidencia |
|---|---|---|
| Naturaleza | VERIFIED | «All Openverse content is under a Creative Commons license or in the public domain»; más de 800 millones de obras (página oficial) |
| Licencia | VERIFIED | «Openverse cannot make any claims about the accuracy of license information. You should always verify the license of a particular work before using it.» |
| Búsqueda/metadata/artwork/URL | VERIFIED (observación) | `GET /v1/audio/` devolvió `url`, `license`, `license_url`, `creator`, `provider`, `foreign_landing_url`, `thumbnail`, `duration` (Fase 2.1) |
| Fuentes de audio | PARTIALLY VERIFIED | La guía de inicio muestra como fuentes `freesound`, `jamendo`, `wikimedia_audio` (ejemplo de entorno local; no es lista autoritativa de producción) |
| Atribución | NOT VERIFIED | No detallada en lo leído |
| Límites, registro | NOT VERIFIED | Páginas devuelven 404 o no los detallan |
| Reutilización | PARTIALLY VERIFIED | Depende de la licencia por obra y de los términos del proveedor de origen (p. ej. Jamendo); Openverse no los sustituye |

Conclusión: Openverse es **índice** de obras abiertas, no proveedor de reproducción.

---

## 13. Verification matrix

Confianza: **Alta** = texto íntegro oficial o documento leído de forma completa; **Media** = resumen automático de página oficial o evidencia observada en la API; **Baja** = inferencia o fuente indirecta.

| Provider | Claim | Previous status | Official evidence | Verified status | Confidence |
|---|---|---|---|---|---|
| Audius | Apps de terceros pueden reproducir (stream) el contenido de la API | Técnicamente sí; términos UNKNOWN | OML §1.2; ToU (acceso API por defecto, opt-out) | VERIFIED (principio) | Alta |
| Audius | Licencia del contenido uniforme | UNKNOWN (`license` null) | OML §1.3 licencia alternativa; ToU: varias CC, incluidas NC/ND | **CONTRADICTED** la uniformidad: puede variar por pista | Alta |
| Audius | API Terms / uso comercial a nivel API | UNKNOWN | URL oficial no legible (500/404) | UNKNOWN | — |
| Audius | URL de stream firmada y temporal | B probable | Observación: `signature` + `timestamp`; doc oficial menciona «short-lived signature» en otro flujo | PARTIALLY VERIFIED (TTL UNKNOWN) | Media |
| Audius | Plan Free 10 req/s, 500 000/mes; API key pública, bearer solo backend | Verificado parcial | README oficial del SDK | VERIFIED | Alta |
| Audius | Artwork 150/480/1000 | Observado | Sin doc oficial leída | PARTIALLY VERIFIED | Media |
| Audius | Endpoint de stream documentado | — | Sin doc legible | NOT VERIFIED | — |
| Apple | MusicKit for Android con autenticación y reproducción | Verificado parcial | musickit page, Javadoc oficial | VERIFIED | Alta |
| Apple | Music User Token manual en Android | — | `user-authentication-for-musickit.md` | VERIFIED | Alta |
| Apple | Developer token JWT ES256, ≤ 6 meses; requiere Developer Program | Parcial | `generating-developer-tokens.md` | VERIFIED | Alta |
| Apple | 99 USD/año | Verificado | Página oficial | VERIFIED | Media |
| Apple | Suscripción del usuario necesaria en Android | Implícito | No leída cláusula explícita | NOT VERIFIED | — |
| Apple | Términos de MusicKit/API | UNKNOWN | No localizados | UNKNOWN | — |
| Apple | Uso desde Flutter | UNKNOWN | Sin mención oficial | UNKNOWN | — |
| Apple | Emitir developer token sin backend | UNKNOWN | No indicado | UNKNOWN | — |
| Deezer | API pública solo da previews de 30 s | Verificado (observación) | Guidelines: «no audio streaming available except 30s extracts» | VERIFIED | Media |
| Deezer | Reproducción completa para apps nuevas | UNKNOWN | Guidelines citan SDK nativos; `/sdk` 404 | UNKNOWN | — |
| Deezer | SDK descontinuados | Indicio secundario | Doc oficial aún los cita | **CONTRADICTED** (la afirmación de 2.1 no está respaldada por fuente oficial) → UNKNOWN | Media |
| Deezer | Uso no comercial y sin almacenamiento local de audio | Verificado | Terms IV y Guidelines | VERIFIED | Media |
| Deezer | Estado del registro de apps nuevas | UNKNOWN | Páginas solo con login | UNKNOWN | — |
| Jamendo | `client_id` en cada llamada; credenciales personales | Parcial | Autenticación y cl. 2 | VERIFIED | Media |
| Jamendo | Uso no comercial libre; comercial por acuerdo | Verificado | Cl. 3.3 | VERIFIED | Media |
| Jamendo | Sin diseño para caché/offline | Verificado | Cl. 3.3 | VERIFIED | Media |
| Jamendo | Licencia CC por contenido | Verificado | Cl. 3.1 + `license_ccurl` | VERIFIED | Media |
| Jamendo | Stream completo por URL (`audio`) | Verificado | Doc de `/tracks` | VERIFIED | Media |
| Jamendo | Cláusula de redistribución específica | UNKNOWN | Solo «cumplir la licencia» (3.1) | PARTIALLY VERIFIED | Media |
| Jamendo | Caducidad de las URL de stream | UNKNOWN | No documentada | UNKNOWN | — |
| Internet Archive | No garantiza copyright; responsabilidad del usuario | Verificado | `help.archive.org/help/rights/` | VERIFIED | Media |
| Internet Archive | `licenseurl`/`rights` disponibles | Ausentes en muestra | Sin campos obligatorios en la doc | VERIFIED (no garantizados) | Media |
| Internet Archive | URL oficial de descarga | UNKNOWN | Páginas de descarga no legibles | NOT VERIFIED | — |
| Internet Archive | Terms of Use vigentes (copia fuera del sitio) | UNKNOWN | Página no legible; blog 2014 | PARTIALLY VERIFIED | Baja |
| Spotify | Audio completo solo por SDK/control de la app oficial, Premium | Verificado parcial | Policy IV.1; Web Playback SDK; SDK Android | VERIFIED | Media |
| Spotify | No existe API de audio usable por `just_audio` | Verificado parcial | Ningún mecanismo documentado | VERIFIED (en lo documentado) | Media |
| Spotify | Preview en multi-get retirado para apps nuevas | Verificado | Blog 2024-11-27 | VERIFIED | Media |
| Spotify | Caché limitada a metadata/portadas o «Conditional Downloads» | «Reverificar» | Terms IV.3.1 y IV.3.2 | VERIFIED | Media |
| Spotify | App de Spotify necesaria para el SDK de Android | Fuente secundaria | Doc oficial lo sugiere, no lo afirma | PARTIALLY VERIFIED | Baja |
| YouTube | Solo reproductor oficial; sin audio aislado, segundo plano ni caché | Verificado | Developer Policies III.E, III.I | VERIFIED | Media |
| YouTube | Cuota 10 000 u/día y 100 `search.list`/día | «Reverificar» | Dos páginas oficiales coinciden | PARTIALLY VERIFIED | Media |
| YouTube Music | API pública oficial para terceros | UNKNOWN | No hallada | UNKNOWN | — |
| Openverse | Índice CC/PD sin garantía de licencia | Observado | Página oficial | VERIFIED | Media |
| Openverse | Límites/registro/atribución | UNKNOWN | 404 o sin detalle | NOT VERIFIED | — |

## 14. Corrections to Phase 2.1

La Fase 2.1 no se modifica; estas son las correcciones y aclaraciones.

- **Audius:** *confirmado* el plan Free y el modelo de claves; *corregido* que los términos eran totalmente desconocidos: ya hay base oficial (OML + ToU) que permite el stream a «Music Players»; *incompleto* el estado de los API Terms; *corregida* la idea de licencia uniforme (puede haber licencia alternativa por pista); sigue UNKNOWN la duración de la URL firmada y la documentación oficial del endpoint de stream.
- **Apple Music:** *confirmados* MusicKit for Android, token de usuario manual en Android, developer token y 99 USD/año; *incompleto* el detalle de MusicKit (versión mínima, términos, suscripción explícita); sigue UNKNOWN Flutter y la emisión de token sin backend.
- **Deezer:** *confirmados* preview de 30 s, no comercial, sin almacenamiento local, URL completa nunca expuesta; *corregida* la inferencia secundaria de «SDK desaparecidos» (la documentación oficial aún los cita); sigue UNKNOWN la reproducción completa y el registro para apps nuevas.
- **Jamendo:** *confirmado* todo lo esencial; *ampliado*: `client_id` en cada llamada, un `client_id` por aplicación, cl. 7 de retirada de contenido al terminar el acuerdo; siguen UNKNOWN la caducidad de las URL y una cláusula de redistribución específica.
- **Internet Archive:** *confirmados* la falta de garantía de copyright y la responsabilidad del usuario; *incompleto* el acceso a los Terms of Use vigentes y a la URL oficial de descarga; sigue UNKNOWN el streaming en apps de terceros y los límites de acceso.
- **Spotify:** *confirmado* que no hay entrega de audio; *completadas* las cláusulas de almacenamiento (IV.3.1/IV.3.2) y las prohibiciones de la Developer Policy; «Spotify instalado» pasa a *parcialmente verificado*.
- **YouTube:** *confirmadas* las políticas; *resuelto* el «reverificar» de la cuota (dos páginas coinciden); *añadido*: límite de 30 días para datos no autorizados (III.E).
- **YouTube Music:** sin cambios: UNKNOWN.
- **Openverse:** *confirmado* su carácter de índice y la advertencia sobre licencias; límites/registro siguen sin verificar.

## 15. Remaining unknowns

UNKNOWN — REQUIRES FUTURE VERIFICATION:

1. **Audius:** texto de los API Terms; condiciones comerciales a nivel de API; documentación oficial del endpoint de stream; duración de la firma de la URL; si leer sin API key está permitido (las peticiones de sonda funcionaron sin clave, sin documentación que lo respalde).
2. **Apple Music:** términos de MusicKit/Apple Music API; requisito explícito de suscripción y versión mínima en Android; licencia del SDK; uso desde Flutter; emisión del developer token sin exponer la clave.
3. **Deezer:** mecanismo oficial vigente de audio completo para apps nuevas; estado del registro; autenticación y límites; vigencia del texto de los términos.
4. **Jamendo:** caducidad de las URL de stream; cláusula específica de redistribución.
5. **Internet Archive:** Terms of Use vigentes (texto íntegro), URL oficial de descarga, política de acceso automatizado y límites, permiso de reproducción en una app de terceros.
6. **Spotify:** requisito explícito de la app de Spotify instalada para el SDK de Android.
7. **YouTube Music:** existencia de una API oficial pública para terceros.
8. **Openverse:** límites, registro y atribución requerida.
9. **Transversales:** reglas de caché/hotlinking de artwork en todos los proveedores; comportamiento real de `just_audio` con URLs http(s) en este proyecto.

**Bloqueos para la decisión de proveedor** (la decisión **no** debe tomarse mientras esto siga abierto):
- **Audius:** bloqueado por los API Terms (punto 1).
- **Apple Music:** bloqueado por términos, suscripción en Android y emisión de tokens (punto 2).
- **Deezer (audio completo):** bloqueado por el punto 3; su uso para metadata/previews depende además de que el producto sea no comercial.
- **Internet Archive:** bloqueado por los Terms de uso vigentes y el mecanismo de descarga (punto 5).
- **Jamendo:** sin bloqueo documental crítico; **condicionado** por la decisión de producto (no comercial, sin caché/offline, atribución).
- **Spotify, YouTube:** no bloquean por desconocimiento; quedan descartados **como fuente de audio propio** por los mecanismos verificados (solo control/SDK o reproductor oficial).

## 16. Architectural impact

**ARCHITECTURE UNCHANGED.** Ninguna verificación contradice Phase 2.0.

| Decisión de 2.0/2.1 | Efecto de la verificación |
|---|---|
| **Identidad** `(fuente, id externo)` | Sin cambio. Audius presenta dos ids para una pista (hash corto y `trackId` numérico en la URL): refuerza que la fuente debe fijar **un id canónico** |
| **`externalId` como cadena opaca** | Sin cambio; Internet Archive (ítem + archivo) y Audius/Jamendo/Deezer caben |
| **Recurso reproducible** | Sin cambio: sigue necesitando un resultado más rico que una URL (URL firmada y renovable en Audius; motor SDK en Apple; control remoto en Spotify) |
| **Motor de reproducción del proveedor** | Confirmado como concepto necesario solo para Apple Music (MusicKit `MediaPlayerController`) y, como control remoto, Spotify |
| **Referencia de artwork** | Sin cambio: URL + variantes; reglas de caché siguen UNKNOWN |
| **Persistencia de metadata** | **Refuerza** la decisión «respaldo opcional y dependiente de la fuente»: Spotify limita almacenar contenido («strictly necessary»), YouTube limita datos a 30 días, Jamendo exige retirar contenido y referencias al terminar el acuerdo |

No se implementa ningún cambio.

## 17. Final status

**PHASE 2.1B PARTIALLY VERIFIED**

- **Verificado con fuentes oficiales:** base contractual de Audius para el stream por apps de terceros (OML y Terms of Use), mecanismos y restricciones de Spotify y YouTube, términos esenciales de Jamendo, postura de Internet Archive sobre copyright, naturaleza de Openverse, tokens y estructura del SDK de Apple Music.
- **Sin poder verificarse:** UNKNOWN — REQUIRES FUTURE VERIFICATION (ver §15), con los bloqueos de decisión indicados en §15.
- **No se elige proveedor ni se recomienda ninguno.**
- La arquitectura de Fase 2.0 permanece válida. Las fases 2.2–2.4 (identidad, resolvedor, persistencia), que son independientes del proveedor, **no quedan bloqueadas** por esta verificación.

### Validación

- Único archivo nuevo de esta fase: `docs/PHASE_2_1B_PROVIDER_DOCUMENTATION_VERIFICATION.md`. Sin cambios en `lib/`, `test/`, `pubspec.*`, `android/`, `ios/` ni `assets/`. Sin build, commit ni push.
- Nota de entorno: para leer los PDF oficiales de Audius se usó la biblioteca PyMuPDF **ya instalada** en la máquina, sin instalar nada ni tocar el proyecto; los PDF y su texto extraído quedaron en carpetas temporales de la sesión, fuera del repositorio.
