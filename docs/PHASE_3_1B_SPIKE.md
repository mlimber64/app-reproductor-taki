# Fase 3.1B-0 — Jamendo real API spike

**Estado: COMPLETADO (2026-10-01, 3ª sesión).** Llamadas reales con un `client_id`
válido (8 hex; no se imprime ni se guarda) y reproducción en `emulator-5554`.
No se tocó `lib/`, `Song`, `MusicIdentity`, `SourceSongLookup`, Player, SQLite,
UI, `pubspec` ni Android. Únicos cambios: este documento y
`test/fixtures/jamendo/` (fixtures saneados: sin `client_id`, sin token de audio,
sin waveform).

Historial: 1ª sesión bloqueada (sin credencial); 2ª sesión la credencial era de
otro tipo (32 hex) y la API devolvía `code 5`.

## 1. Respuestas a las 17 preguntas (todas VERIFICADAS salvo indicación)

| # | Pregunta | Resultado |
|---|---|---|
| 1 | ¿La búsqueda funciona hoy? | Sí. **Corrección (3.1B):** la API devuelve a veces 0 resultados de forma intermitente con cualquier parámetro (incluido `search=`); la conclusión inicial de que `search=` no funciona era esa intermitencia. Ver `PHASE_3_1B_JAMENDO_PROVIDER.md` §16. |
| 2 | Parámetros | `client_id` (obligatorio), `format=json`, `limit` (1–200), `namesearch`, `imagesize`, `audioformat`, `include=musicinfo`, `offset`, `order` (relevance, popularity_*, listens_*, name, artist_name, releasedate, duration, id…). |
| 3 | Estructura | `{headers:{status,code,error_message,warnings,results_count,next?}, results:[…]}`. |
| 4 | Id estable | `id` (string numérico, p. ej. `"2291526"`) → `MusicIdentity('jamendo', id)`. Estable entre llamadas. |
| 5 | Campos para `Song` | `id`, `name`, `duration` (int, segundos), `artist_id`, `artist_name`, `album_id`, `album_name`, `position`, `releasedate`, `license_ccurl`, `album_image`/`image`, `audio`, `shareurl`, `shorturl`, `audiodownload_allowed`, `musicinfo.tags` (con `include=musicinfo`). |
| 6 | URL de audio | `audio` (con `audioformat=mp32`, por defecto mp3 VBR). |
| 7 | ¿Reproducible directo? | Sí: `GET` con `Range` → `206`, `audio/mpeg`, `Content-Range` presente, sin redirecciones. |
| 8 | ¿Requiere `client_id` en el audio? | No: igual con y sin él. |
| 9 | Cabeceras especiales | No. Sin cabeceras extra funciona (y con `just_audio`). |
| 10 | ¿Expira? | El token `from=` **cambia en cada llamada** a la API, pero un token de hace ~20 min siguió dando `206`. Caducidad real NO determinada (≥20 min). Recomendación: no persistir la URL de audio; guardar solo el `id` y re-resolver. |
| 11 | Status HTTP | `200` incluso en errores de API; `404` (cuerpo vacío) en `storage` con `trackid` inexistente; `206` con Range. |
| 12 | `just_audio` | **OK** en Android x86_64 emulador: `idle→loading→ready`, `duration=2:24` (coincide con `duration:144`), `play`, posición 5.6 s, `seek(60 s)` → 1:02, buffering breve y vuelve a `ready`. App de prueba fuera del repo, ya eliminada. |
| 13 | Artwork | `album_image` y `image`: `https://usercontent.jamendo.com?type=album&id=…&width=300&trackid=…` → `image/jpeg`, `Cache-Control: public, max-age=12960000`. 0/50 pistas recientes sin imagen. |
| 14 | Tamaños | `width` 25, 50, 100, 200, 300, 400, 600 devuelven exactamente ese cuadrado; `1000` falla; sin `width` falló (`error code: 1101` de Cloudflare). Siempre pasar `width`. |
| 15 | Atribución | `shareurl` (`https://www.jamendo.com/track/<id>`), `shorturl`, `artist_idstr`, `license_ccurl` (CC; p. ej. BY-NC-ND/BY-NC-SA → **uso no comercial**). |
| 16 | Errores | Siempre `HTTP 200` + `headers.status="failed"` y `code`: `5` credencial ausente/inválida; `3` parámetro inválido (`limit` fuera de 1–200, `order` inválido); `7` método inexistente. `id` inexistente → `success`, `results_count=0` (no es error). Un cliente debe mirar `headers.status`, no el HTTP. |
| 17 | Cuota | No hay cabeceras de rate-limit. 40 peticiones seguidas → 40 `success`. Cuota NO documentada por la API (Cloudflare delante; posible `429`/1101 no observado salvo el 1101 de arriba). |

## 2. Hallazgos adicionales

- `audio` por defecto mp32; `audioformat=ogg` devuelve URL ogg; `mp31`/`flac` no
  devolvieron URL en la prueba (no usar).
- `audiodownload` devuelve HTML (descarga restringida), **no** usarlo para
  reproducir.
- `prourl` vacío en algunas pistas (licencia comercial no disponible).
- `waveform` es un string JSON enorme; omitir en el mapeo.
- Búsqueda con acentos (`canción`) funciona con percent-encoding UTF-8.
- `next` en `headers` incluye el `client_id` en claro: **no loguear ni persistir**.

## 3. Fixtures (`test/fixtures/jamendo/`)

`tracks_search.json` (2 pistas reales, saneadas), `empty_results.json`,
`error_invalid_client.json`, `error_bad_param.json`. Verificado: ninguna contiene
el `client_id`. No se añadieron tests de mapeo todavía (sin proveedor).

## 4. Impacto en 3.1B — desbloqueado

Mapeo propuesto: `id→MusicIdentity('jamendo',id)`, `name→title`,
`artist_name→artist`, `album_name→album`, `duration*1000→duration`,
`album_image` (width fijo)→artwork, `audio`→URI de reproducción resuelta en
caliente. Pendientes del propietario (de 3.1A): uso no comercial/licencias,
ubicación del `client_id` (no en el repo), política de caché/offline, aislamiento
de fallos por fuente.

Riesgos abiertos: caducidad exacta del token de audio; cuota no documentada;
Respuestas vacías intermitentes de la API (ver 3.1B).
