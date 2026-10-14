# Fase 2.5 — Remote Artwork

> **`RemoteArtworkReference` no significa que Taki ya descargue artwork remoto.**
> Esta fase solo define el modelo y el contrato. No hay HTTP, ni proveedores, ni
> adaptador que produzca o cargue una referencia remota. La integración
> HTTP/proveedor pertenece a una fase posterior.

## 1. Estado anterior

Todo el artwork pasaba por `albumId` (MediaStore):

| Pieza | Qué hace | Dependencia de `albumId` |
|---|---|---|
| `ArtworkRepository` (puerto) | `getAlbumArtwork(int albumId, {size})` → bytes | En la firma |
| `MediaStoreArtworkRepository` | Adaptador MediaStore (canal nativo `getArtwork`) | Total (local) |
| `ArtworkCache` | LRU en memoria (200), dedupe de peticiones, recuerda ausentes (`null`) | Clave `({int albumId, int size})` |
| `AlbumArtworkBuilder` / `AlbumArtworkMosaicBuilder` | `albumId` + tamaño lógico → `ArtworkCache` → `ResizeImage(MemoryImage)` | Entrada `int?` |
| `TakiArtwork` | Solo presentación: recibe `ImageProvider?` | **Ninguna** (ya agnóstico) |
| `ArtworkFileCache` (player) | Bytes → archivo `album_<id>_<size>.jpg` en el directorio temporal, para notificación/lockscreen (necesitan `file://`) | Total: usa `song.albumId`, nombre de archivo y set de «sin carátula» |

Consumidores (todos vía `AlbumArtworkBuilder`/`MosaicBuilder`): Library,
Favorites, Queue, MiniPlayer, Now Playing, Playlists (lista y detalle,
`playlist_cover_images.dart`) y AddToPlaylistSheet. MediaSession/lockscreen usa
`ArtworkFileCache` desde `TakiAudioHandler`.

## 2. Problema arquitectónico

`albumId` es un dato de la fuente local. La clave del cache (`albumId`+`size`)
y el builder no pueden representar una carátula que viene de una URL, ni
distinguir «álbum 7 local» de «URL ...7». Sin un modelo de referencia, cualquier
proveedor futuro tendría que colarse como un entero.

## 3. Diseño elegido

Punto de introducción: **entre el dato de la fuente y la clave del cache**.

```
(futuro) MusicIdentity → ArtworkResolver ┐
local: Song.albumId → localArtworkReference() ┴→ ArtworkReference
        → ArtworkCache (clave: referencia + tamaño) → bytes
        → ResizeImage(MemoryImage) → TakiArtwork
```

Cambios mínimos:

- **Nuevo** `ArtworkReference` (sellada) en `core/domain/entities`.
- **Nuevo** puerto `RemoteArtworkLoader` en `core/domain/ports` (solo contrato,
  sin adaptador).
- `ArtworkKey` pasa de `({int albumId, int size})` a
  `({ArtworkReference reference, int size})`.
- `ArtworkCache` despacha por tipo de referencia; acepta un `RemoteArtworkLoader?`
  opcional.
- `AlbumArtworkBuilder` gana un constructor con nombre `.reference(...)`: el
  **mismo widget**, no uno nuevo. La API por `albumId` no cambia, así que
  ningún consumidor se toca.
- `remoteArtworkLoaderProvider` (valor `null` hoy) para que una fase posterior
  solo tenga que sobrescribirlo.

### Decisión: ¿`ArtworkRepository` sigue siendo el puerto?

Sí, **sin modificarlo**. Sigue siendo el puerto de la fuente local (por álbum).
Añadir `getArtwork(ArtworkReference)` obligaría a todos los implementadores y
fakes a cambiar, y mezclaría en un puerto una carga local y una remota que
tendrán dependencias y fallos distintos. Un puerto aparte (`RemoteArtworkLoader`)
es más pequeño y se inyecta solo cuando exista.

### Decisión: ¿`ArtworkResolver` ahora?

**No.** Resolver `MusicIdentity → ArtworkReference` necesita una fuente de datos
remota (consulta a un catálogo) que hoy no existe; un puerto con un único
adaptador trivial sería una abstracción especulativa. Lo único real hoy es
`albumId → referencia`, que es la función pura `localArtworkReference(albumId)`
(análoga a `localMusicIdentity`). El `ArtworkResolver` se definirá en la fase del
primer proveedor, con su contrato asíncrono real.

## 4. Modelo `ArtworkReference`

Jerarquía sellada, Dart puro (sin Flutter, sqflite, MediaStore ni HTTP),
inmutable, con igualdad por valor.

- `LocalArtworkReference(albumId)` — carátula de la fuente local.
- `RemoteArtworkReference(url, {width, height})`
  - `url`: texto **opaco** (no se recorta, normaliza ni parsea); solo se exige
    no vacío/no en blanco (`ArgumentError`).
  - `width`/`height`: tamaño conocido en px, `null` = desconocido; si se dan,
    deben ser > 0. **Forman parte de la igualdad**: misma URL con otro tamaño
    declarado es otra referencia (decisión conservadora: evita servir una
    imagen de un tamaño por otro en el cache; coste: una entrada duplicada).
  - Sin campos de proveedor, cabeceras, tokens ni caducidad (no hay necesidad
    real todavía).
- `UnavailableArtworkReference()` — se sabe que no hay carátula (resultado
  definitivo, no error).

## 5. Relación con MusicIdentity

Ninguna dependencia. `MusicIdentity` no cambia ni conoce artwork. Una
referencia **no identifica una canción** (varias canciones comparten carátula;
una URL puede cambiar). La identidad sigue siendo `source + externalId`.

## 6. Relación con albumId

`albumId` sigue siendo una propiedad de la fuente local: vive en `Song`,
`LocalArtworkReference` y `MediaStoreArtworkRepository`. No se añade a
`MusicIdentity` ni se convierte en `externalId`. `localArtworkReference(int?)`
es el único punto de conversión (`null` → `Unavailable`).

## 7. Flujo local (sin cambios de comportamiento)

`albumId` → `LocalArtworkReference` → clave `(referencia, dpr·size)` →
`ArtworkCache` → `ArtworkRepository.getAlbumArtwork(albumId)` → bytes →
`ResizeImage(MemoryImage)` → `TakiArtwork`. Un `albumId` nulo no consulta nada
y entrega `null` (placeholder), igual que antes. Los 831 tests previos siguen en
verde; solo se adaptó la forma de la clave en los tests del cache/builder.

## 8. Flujo remoto futuro

Un proveedor (fase posterior) aportará: (a) algo que produzca
`RemoteArtworkReference` a partir de una `MusicIdentity` (`ArtworkResolver`) y
(b) un adaptador `RemoteArtworkLoader` (HTTP, con sus cabeceras/errores) que se
inyecta con `remoteArtworkLoaderProvider`. Tras eso, la UI usa
`AlbumArtworkBuilder.reference(...)` y `TakiArtwork` sin más cambios. Hoy está
probado solo con un cargador falso en tests.

Sin cargador, una referencia remota se trata como carátula ausente (`null`,
placeholder) y **no** toca el repositorio local.

## 9. Cache

- `ArtworkCache`: LRU en memoria de **bytes** por `(referencia, size)`; dedupe
  de peticiones en vuelo; recuerda ausencias; errores → ausente. No es
  persistente y no usa `albumId` implícitamente salvo a través de la clave local.
- La clave anterior (`albumId`+`size`) **no servía** para remoto; ahora incluye
  la referencia con igualdad por valor: local ≠ remota (tipos distintos, p. ej.
  álbum 7 vs URL «7»), URLs distintas ≠, mismo URL con distinto tamaño
  declarado/pedido ≠.
- `ArtworkFileCache` (player): **no modificado.** Sigue siendo exclusivamente
  local: la clave de archivo es `album_<albumId>_<size>.jpg` y se alimenta de
  `Song.albumId`. No hay cache persistente remoto, ni disco, ni expiración en
  esta fase.

## 10. MediaSession / lockscreen

Sin cambios. La notificación/lockscreen necesita un `file://` con bytes en
disco que `ArtworkFileCache` genera desde `ArtworkRepository` (local). El
artwork remoto **no** está conectado: requeriría descargar la imagen y
escribirla en disco (o entregar una URL http al `MediaItem`), lo que es HTTP y
queda para la fase del proveedor.

## 11. Fuera de alcance (deliberado)

HTTP/Dio, descarga de imágenes, proveedores y sus adapters, autenticación,
tokens/API keys, refresh de URLs, cabeceras/firmas, cache persistente remoto,
cambios de Player/`PlaybackResource`, SQLite/migraciones, `ArtworkResolver`,
conexión a MediaSession, cambios visuales, nuevos widgets de artwork.

## 12. Decisiones descartadas

- Ampliar `ArtworkRepository` con `getArtwork(ArtworkReference)`: rompe todos
  los implementadores y mezcla local/remoto en un puerto.
- Añadir `albumId` (o URL) a `MusicIdentity`: viola su contrato.
- `ArtworkResolver` ahora: sin fuente real, abstracción especulativa.
- Un `RemoteAlbumArtworkBuilder` / otro widget: duplicaría el builder; se usó
  un constructor con nombre.
- Validar la URL con `Uri.parse`/esquema: la URL es opaca por contrato y el
  esquema/seguridad corresponde al adaptador.
- Excluir `width`/`height` de la igualdad: podría colisionar en el cache.

## 13. Riesgos / deuda

- El nombre `AlbumArtworkBuilder` ya no describe del todo el widget (acepta
  referencias). Renombrarlo toca ~10 archivos; se deja para una fase de limpieza.
- Mosaicos (`AlbumArtworkMosaicBuilder`) siguen aceptando solo `albumId`s; un
  mosaico con carátulas remotas necesitará su propio constructor por referencias.
- El cache no distingue fallo transitorio de ausencia definitiva (heredado):
  con red, un error puntual se recordaría como «sin carátula» hasta
  `clear()`/expulsión. Habrá que revisarlo al meter HTTP.
- El tamaño pedido a un cargador remoto es una pista; el proveedor puede
  devolver otro (el `ResizeImage` limita la decodificación, como en local).
- La URL puede caducar/requerir cabeceras; fuera de este contrato.

## 14. Próxima fase sugerida

Fase 2.6: primer proveedor de artwork remoto de **solo lectura y sin
autenticación**: definir `ArtworkResolver` (`MusicIdentity → ArtworkReference`),
implementar un `RemoteArtworkLoader` con HTTP (decidir cliente y política de
errores/transitorios), sobrescribir `remoteArtworkLoaderProvider` y decidir si
el lockscreen usa descarga a `ArtworkFileCache` o URL directa.
