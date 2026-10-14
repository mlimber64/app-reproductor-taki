# Fase 1.8O — Auditoría y cierre del artwork

Auditoría final del sistema de artwork. Sin funcionalidad nueva ni refactorizaciones. Sin commit ni push.

## 1. Flujo confirmado

```text
ArtworkRepository (port, core/domain/ports)
   ↓ bytes
ArtworkCache (core/artwork)            LRU 200 por (albumId, px); deduplica; recuerda ausentes
   ↓
AlbumArtworkBuilder / AlbumArtworkMosaicBuilder (core/artwork)
   ↓
ResizeImage(MemoryImage(bytes), width: px físicos, allowUpscaling: false)
   ↓
TakiArtwork (core/widgets)             Image(BoxFit.cover), placeholder, fundido
```

Comprobado en código:
- `artworkCacheProvider` se lee en **un solo sitio de UI**: `album_artwork_builder.dart:149`. Otras dos apariciones no son resolución de imagen: su definición (`artwork_providers.dart`) y `SongsNotifier.rescan`, que llama a `clear()` (`songs_notifier.dart:98`).
- `MemoryImage` y `ResizeImage` se **construyen** únicamente en `album_artwork_builder.dart:173-174`. Las demás menciones en `lib/` son comentarios.
- `TakiArtwork` recibe un `ImageProvider?`; no lee providers ni cachés.
- Todas las superficies de UI con carátula usan el builder: Biblioteca, Favoritos, Reproduciendo, Cola (cabecera y filas), mini player, lista de playlists, detalle (cabecera y filas) y sheet "Añadir a una playlist" (estos tres últimos de portada vía `PlaylistCoverImages`, que delega en los builders).

## 2. Referencias legacy

Búsqueda sensible a mayúsculas en `lib/`, `test/` y `docs/` (los informes `PHASE_1_8*` se excluyen de los conteos).

| Elemento | Producción | Tests | Docs | Estado |
|---|---|---|---|---|
| `AlbumArtworkImage` | 0 | 0 | 2 (nota «reemplazadas» y lista «Retirado») | Sin uso activo; solo referencias históricas |
| `ArtworkImage` | 0 | 0 | 7 (inventario de partida, notas de sustitución) | Sin uso activo; marcadas «eliminado en 1.8» |
| `PlaylistCover` | 1 comentario (`album_artwork_builder.dart:66`, «como el `PlaylistCover` anterior») | 2 comentarios («el antiguo `PlaylistCover` (ya eliminado)») | 10 (registro de fases y notas) | Sin uso activo. El comentario del builder **no se modificó** (está en la lista de archivos intocables); es una referencia al comportamiento anterior, sin ambigüedad de uso |
| `import …artwork_image.dart` de test | — | 10 imports | — | **No es la clase eliminada**: es `test/helpers/artwork_image.dart` (ver §6) |

Ningún `import` de `album_artwork_image.dart`, `artwork_image.dart` de `core/widgets` ni `playlist_cover.dart` en `lib/` ni `test/`.

Conteo de los otros elementos buscados (sin informes de fase), `lib / test / docs`:

| Elemento | lib | test | docs |
|---|---|---|---|
| `MemoryImage` | 4 (1 construcción + comentarios) | 20 | 15 |
| `ResizeImage` | 5 (1 construcción + comentarios) | 9 | 10 |
| `artworkCacheProvider` | 3 | 4 | 1 |
| `ArtworkRepository` | 9 | 81 | 7 |
| `ArtworkFileCache` | 4 | 3 | 2 |
| `AlbumArtworkBuilder` | 13 | 50 | 16 |
| `AlbumArtworkMosaicBuilder` | 5 | 25 | 2 |

## 3. Resolución de artwork

Puntos de producción donde se obtiene o se crea un `ImageProvider` de carátula:

| Punto | Qué hace |
|---|---|
| `AlbumArtworkBuilder._AlbumImagesState.build` (`album_artwork_builder.dart:173`) | **Único** sitio que construye `ResizeImage(MemoryImage(bytes))` |
| `PlaylistCoverImages` | No crea proveedores: elige entre `AlbumArtworkMosaicBuilder` (4 álbumes) y `AlbumArtworkBuilder` (menos) |
| `TakiArtwork` (`Image(image: …)`) | Solo dibuja el proveedor recibido; sin `cacheWidth` ni lectura de cachés |

Otros accesos al repositorio o a la caché (no son resolución de UI):
- `ArtworkCache.load/peek`: solo desde el builder.
- `ArtworkRepository.getAlbumArtwork`: desde `ArtworkCache` y desde `ArtworkFileCache`.
- No hay `Image.memory`, `Image.file`, `FileImage`, `NetworkImage` ni `AssetImage` para carátulas en `lib/`.

Conclusión: **`AlbumArtworkBuilder` es el único resolver de artwork de UI**; `ArtworkFileCache` es la excepción deliberada.

## 4. Adaptadores privados

Búsqueda de `class _…(Artwork|Cover|Art)…` en `lib/`: **una** coincidencia.

| Clase | Ubicación | Responsabilidad | Veredicto |
|---|---|---|---|
| `_Artwork` | `now_playing_page.dart:346` | Envoltorio visual: redondea el lado (`floorToDouble`) y pasa `AlbumArtworkBuilder` → `TakiArtwork(hero: true)` | **Legítimo.** No resuelve artwork (no lee cachés ni construye proveedores); solo decide el tamaño y presenta |

No quedan adaptadores bytes → `MemoryImage` en ninguna pantalla. Nada ambiguo que reportar.

## 5. ArtworkFileCache

Permanece separado porque su salida y su ciclo de vida son otros:
- Guarda la carátula a **512 px como archivo** (`album_<id>_512.jpg` en el directorio temporal) para devolver una **URI** a la notificación y a la pantalla de bloqueo; la UI trabaja con bytes en memoria y `ImageProvider`.
- Llama directamente a `ArtworkRepository.getAlbumArtwork`; **no usa `ArtworkCache`** ni los builders, y su tamaño no depende del dpr.
- Lo crea `initPlayer` y lo usa `TakiAudioHandler`; no tiene relación con ningún widget.
No se modificó.

## 6. `test/helpers/artwork_image.dart`

- **Qué hace:** helper de tests de 1.8L. `memoryImageOf(ImageProvider)` comprueba que el proveedor es `ResizeImage(MemoryImage)` y devuelve el `MemoryImage` interior; `firstByteOf(ImageProvider?)` devuelve el primer byte (los tests usan `[albumId]`) o `null`. Falla si cambia la forma del proveedor.
- **Quién lo usa:** 9 archivos de test (`album_artwork_builder_test`, `favorites_page_test`, `library_page_test`, `mini_player_test`, `now_playing_page_test`, `queue_page_test`, `add_to_playlist_sheet_test`, `playlists_page_test`, `playlist_detail_page_test`); ~26 usos.
- **Nombre:** el contrato es útil y se conserva. El **nombre es mejorable**: coincide con el archivo eliminado `lib/core/widgets/artwork_image.dart` y aparece en búsquedas de `artwork_image.dart`, aunque no es un widget ni un `ImageProvider`, y las funciones que exporta lo aclaran. El riesgo de confusión es bajo pero real (para quien busque el legado).
- **Decisión:** no se renombra en esta fase (toca 10 imports en 9 tests). Trabajo futuro, opcional: `test/helpers/artwork_provider_matchers.dart` (o similar).

## 7. ImageCache

Estrategia confirmada, sin cambios:
- **`ArtworkCache`** → solo bytes (LRU de 200, clave `(albumId, px)`).
- **`ImageCache` de Flutter** → las imágenes decodificadas del `ImageProvider` que genera el builder. La clave de `MemoryImage` es la identidad de los bytes y la de `ResizeImage` añade ancho, política y `allowUpscaling`.
- `ResizeImage` forma parte del proveedor; **no hay segunda caché propia** (no hay mapas de imágenes ni `ImageCache` adicional). El único estado del builder son los bytes de sus claves actuales (`_bytes`) y las cargas en curso, que viven mientras el widget.
- Tras `ArtworkCache.clear()` (rescan), unos bytes nuevos dan una clave nueva; cubierto por un test (1.8L).

## 8. Limitación de imágenes rectangulares (conocida, sin resolver)

Verificado contra el código actual:
- `ResizeImage` se construye solo con `width` (`album_artwork_builder.dart:173-177`), política `exact` y `allowUpscaling: false`.
- Una imagen no cuadrada conserva su relación de aspecto (1000×600 a 512 → 512×307, test de 1.8L).
- `TakiArtwork` dibuja con `BoxFit.cover` (`taki_artwork.dart:166`) y sin `cacheWidth`, así que el lado corto se amplía para llenar el cuadrado.
- Por tanto puede verse menos nítida que con una política basada en el lado corto. No se ha medido con carátulas reales ni en pantalla.
La nota de `DESIGN_SYSTEM.md` (bloque «Estado del artwork») decía esto solo a medias; ver §9.

## 9. Discrepancias documentales

`ARCHITECTURE.md` y `DESIGN_SYSTEM.md` se contrastaron con el código (flujo, consumidores, mosaico 2×2 con 4 imágenes, `ArtworkFileCache` independiente, `rescan` limpia `ArtworkCache`): coinciden. Discrepancias objetivas corregidas:

1. `DESIGN_SYSTEM.md`, nota de límite conocido: no mencionaba que `TakiArtwork` usa `BoxFit.cover` ni la diferencia de nitidez; se reformuló y se añadió que no se ha medido con carátulas reales.
2. Comentario de `now_playing_page.dart:345` («caché de carátulas → `MemoryImage`») quedaba incompleto tras 1.8L; ahora dice `ResizeImage(MemoryImage)`. Es solo un comentario.

## 10. Gates

- `flutter test`: **730 pasan**.
- `flutter analyze`: sin problemas.
- `flutter build apk --debug`: correcto.
- `test/architecture`: **6/6**.

## 11. Git status

Cambios propios de 1.8O (sin commit):
- `M docs/DESIGN_SYSTEM.md` (nota del límite de rectangulares)
- `M lib/features/player/presentation/pages/now_playing_page.dart` (solo un comentario)
- `?? docs/PHASE_1_8O_ARTWORK_CLOSURE.md`

Sin cambios en `ArtworkRepository`, `ArtworkCache`, `MediaStoreArtworkRepository`, `ArtworkFileCache`, `AlbumArtworkBuilder`, `TakiArtwork`, `AppColors`, la lógica de playlists ni el diseño visual. El resto del working tree es trabajo acumulado desde 1.8A.
