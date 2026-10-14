# Fase 2.6 — Artwork Resolution & Remote Loading Foundation

> Esta fase es **agnóstica de proveedor**. No hay proveedor, API key, endpoint,
> autenticación ni cabeceras propias. El cargador HTTP existe y está probado,
> pero **no está conectado a la app**: ninguna fuente produce todavía una
> `RemoteArtworkReference`.

## 1. Auditoría inicial

Qué información hay hoy:

| Tipo | Contiene | ¿Sirve para la carátula local? |
|---|---|---|
| `MusicIdentity` | `source` + `externalId` (opacos) | **No**: es el `_ID` de la canción, no el `albumId` |
| `SongReference` | identidad + respaldo (`title`, `artist`, `durationMs`, `path`) | **No**: sin `albumId` |
| `Song` | identidad derivada del `id` local + `albumId` + metadata | **Sí** (`albumId`) |
| `Song.musicIdentity` | siempre local hoy (derivada de `id`) | — |

Consumidores del builder (Library, Favorites, Queue, MiniPlayer, Now Playing,
Playlists, AddToPlaylistSheet) ya tienen la `Song` (o su `albumId`) en la mano.
`ArtworkFileCache` (notificación) lee `song.albumId`. Ningún consumidor usa
`SongReference` para artwork: las referencias guardadas se resuelven a `Song`
antes de pintarse.

## 2. Problema de resolver desde MusicIdentity

`MusicIdentity('local', '42')` dice qué canción es, pero **no** en qué álbum está.
Un `ArtworkResolver(MusicIdentity)` local tendría que volver a consultar
MediaStore por el id para descubrir el `albumId` (rediscovery de algo que la
`Song` ya trae) o, peor, el dominio tendría que conocer MediaStore. Meter el
`albumId` en `MusicIdentity` está prohibido (viola su contrato).

## 3. Alternativas consideradas

| | Alternativa | Veredicto |
|---|---|---|
| A | `resolve(MusicIdentity)` | Descartada: no puede resolver local sin consultar MediaStore ni sin añadir `albumId` a la identidad. |
| B | `resolve(Song)` | **Elegida.** |
| C | `resolve(SongReference)` | Descartada: es un respaldo persistido, sin `albumId`; obligaría a reencontrar la `Song` primero. |
| D | Separar identidad y artwork (con un paso previo «identidad → Song») | Ya está separado por tipos: la identidad no sabe de artwork y la referencia no sabe de identidad. Un paso extra de «rediscovery» solo añadiría E/S. |

## 4. Decisión final

`ArtworkResolver.resolve(Song) → Future<ArtworkReference>`, igual que
`PlaybackResolver.resolve(Song)`.

- **Sin rediscovery:** la fuente local lee `song.albumId`, que ya está cargado.
- **MusicIdentity no depende de MediaStore ni de artwork.**
- **El dominio no depende de una feature:** `Song` y el resolvedor viven en
  `core`.
- **No duplica `Song`:** se reutiliza.
- **Local y remoto desacoplados:** cada fuente tiene su resolvedor; un
  `SourceArtworkResolver` enruta por `song.musicIdentity.source`.
- **Impacto en proveedores:** un proveedor decide con `song.musicIdentity`
  (y metadata de `Song` si la necesita) y devuelve `RemoteArtworkReference`; se
  registra en el mapa del router sin tocar UI ni cache.

## 5. Flujo de resolución

```
Song ──► ArtworkResolver ──► ArtworkReference           (¿qué recurso visual?)
                                  │
                                  ▼
                 ArtworkCache  (clave: referencia + size)
                  ├─ Local       → ArtworkRepository (MediaStore)
                  ├─ Remote      → RemoteArtworkLoader ─► ArtworkHttpClient
                  └─ Unavailable → null, sin consultar a nadie
                                  │ bytes
                                  ▼
          AlbumArtworkBuilder ─► ResizeImage(MemoryImage) ─► TakiArtwork
```

Cuatro responsabilidades separadas: identidad (`MusicIdentity`), artwork
(`ArtworkReference`), carga (loader/repository) y presentación (`TakiArtwork`).

## 6. Artwork local

`LocalArtworkResolver`: `Song` local → `localArtworkReference(albumId)`
(`null` → `Unavailable`). Dart puro, sin E/S. Identidad de otra fuente →
`ArtworkResolutionException` (error de enrutamiento, no «sin carátula»).
Comportamiento visible sin cambios: **la UI sigue pasando `albumId` a
`AlbumArtworkBuilder`** y no consume aún el resolvedor (no se tocó UI);
`artworkResolverProvider` queda disponible.

## 7. Artwork remoto

`SourceArtworkResolver` devuelve `Unavailable` para una fuente sin resolvedor
registrado: «no hay información suficiente» es explícito y **nunca se inventa una
URL**. Un resolvedor de proveedor (fase futura) producirá la
`RemoteArtworkReference`.

Limitación detectada: hoy `Song.musicIdentity` se deriva siempre del `id` local,
así que una `Song` no puede expresar una canción remota. Los tests usan una
subclase. Habrá que decidir cómo representa el catálogo remoto sus canciones
(ver §14).

## 8. RemoteArtworkLoader

`HttpRemoteArtworkLoader(ArtworkHttpClient, {timeout = 10 s, maxBytes = 5 MiB})`.
Genérico: sin proveedores, claves, cabeceras ni endpoints. La URL es texto opaco;
solo se comprueba que sirve para una petición (`http`/`https` con host).
Devuelve bytes o lanza una `ArtworkLoadException`; **nunca devuelve `null`**
(un 404 es un fallo, no una ausencia definitiva). Valida la firma de
JPEG/PNG/GIF/WebP (no decodifica; una imagen corrupta con firma buena acaba en
el placeholder por el `errorBuilder` de `TakiArtwork`). `size` se ignora (pista).
No se normaliza la URL ni se usa como identidad ni se persiste.

## 9. Abstracción HTTP

- Puerto `ArtworkHttpClient` (solo `GET`, devuelve estado + bytes, lanza
  `ArtworkNetworkException` en fallos de transporte/timeout). Permite probar sin
  Internet.
- Adaptador `IoArtworkHttpClient` sobre `dart:io` `HttpClient`.
- **Sin dependencias nuevas:** el proyecto no tenía `http`/`dio`; `dart:io` basta
  para un `GET` de bytes sin cabeceras ni autenticación. Si una fase futura
  necesita interceptores, cookies, reintentos o HTTP/2, se reevalúa.
- Ni `ArtworkCache`, ni `AlbumArtworkBuilder`, ni `TakiArtwork` ni la UI hacen
  HTTP: solo ven `RemoteArtworkLoader`.

## 10. Cache

Identidad de cache: `(ArtworkReference, size)`, sin cambios.

| Situación | Resultado | ¿Se memoiza? |
|---|---|---|
| Hit | bytes/`null` guardado | — |
| Local OK / ausente | bytes / `null` | sí |
| Local falla | `null` | sí (comportamiento previo) |
| Remota sin loader | `null`; **no** toca el repositorio local | sí |
| Remota, loader devuelve `null` | `null` | sí |
| Remota, loader lanza (red, HTTP, bytes inválidos) | `null` | **no** (se reintenta) |
| Unavailable | `null`, sin consultar | sí |

Cambio respecto a 2.5: los fallos **remotos** ya no se memoizan (suelen ser
transitorios: red, 5xx), cerrando la deuda anotada en 2.5. Un loader que lanza de
forma síncrona se trata igual que uno asíncrono. Peticiones simultáneas siguen
compartiendo una lectura. No hay cache en disco, expiración, SWR, precarga ni
descargas en segundo plano.

## 11. Errores

Jerarquía sellada `ArtworkException`:

- *Sin carátula*: no es excepción (`Unavailable` / `null`).
- `ArtworkResolutionException` — fallo al resolver.
- `ArtworkLoadException`: `ArtworkUnsupportedUrlException`,
  `ArtworkNetworkException`, `ArtworkHttpException(statusCode)`,
  `ArtworkInvalidDataException(reason)`.

El loader y el cliente los lanzan. **`ArtworkCache` aún los convierte en `null`
para la UI** (placeholder, sin mensajes de red visibles), pero ya no se confunden
con «no hay carátula» en las capas de abajo: una fase futura puede registrarlos o
reintentar según el tipo sin cambiar el loader.

## 12. MediaSession / lockscreen

Sin cambios. La notificación/lockscreen requiere un `file://` generado por
`ArtworkFileCache` desde bytes locales. El artwork remoto **no** está conectado:
`remote → descarga → ArtworkFileCache → MediaSession` queda para una fase
posterior.

## 13. Qué queda fuera

Proveedores, catálogo/búsqueda remotos, autenticación/API keys/tokens/cabeceras,
SQLite, Player, `PlaybackResource`, `MusicIdentity`, cambios de UI o de widgets,
lockscreen remoto, cache persistente, expiración, precarga y descargas en
segundo plano, y **conectar el loader HTTP a `main`**.

## 14. Riesgos

- `Song` no puede representar una canción remota (identidad derivada de `id`).
- La UI no usa aún el resolvedor: sigue habiendo dos caminos (`albumId` directo y
  `AlbumArtworkBuilder.reference`) hasta que una fase conecte uno con otro.
- `AndroidManifest.xml` principal **no declara `INTERNET`** (solo el de debug):
  una build release no podría usar el loader. No se cambió (fuera de alcance y
  el loader no está conectado); hay que añadirlo al conectar un proveedor.
- Android bloquea HTTP en claro por defecto: URLs `http://` fallarán sin
  configuración de seguridad de red (decisión a tomar con el proveedor).
- Redirecciones: `HttpClient` las sigue sin límite de hosts; sin lista de
  dominios permitidos.
- Un 404 se reintenta en cada petición (no se memoiza): puede generar tráfico
  repetido al hacer scroll; habrá que decidir caché negativa con expiración.
- La validación por firma no detecta imágenes corruptas ni formatos como
  SVG/AVIF/HEIC (se rechazan como no reconocidos).

## 15. Preparación para un proveedor futuro

Para conectar un proveedor bastará con:

1. Un `ArtworkResolver` del proveedor (decide con `song.musicIdentity`).
2. Registrarlo en `SourceArtworkResolver` con su etiqueta de fuente.
3. Sobrescribir `remoteArtworkLoaderProvider` con
   `HttpRemoteArtworkLoader(const IoArtworkHttpClient())` (o un cliente propio
   con autenticación implementando `ArtworkHttpClient`).
4. Añadir `INTERNET` al manifest principal.
5. Hacer que la UI obtenga la referencia del resolvedor
   (`AlbumArtworkBuilder.reference`) en lugar de `albumId`.

No requiere modificar `ArtworkCache`, `TakiArtwork` ni el modelo.
