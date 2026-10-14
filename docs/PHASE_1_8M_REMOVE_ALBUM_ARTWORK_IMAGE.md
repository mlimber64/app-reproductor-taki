# Fase 1.8M — Eliminación de AlbumArtworkImage

Limpieza controlada: se elimina `AlbumArtworkImage` porque no tiene consumidores de producción y su única capacidad relevante (decodificación acotada) ya vive en `AlbumArtworkBuilder` desde la Fase 1.8L. Sin commit ni push.

## 1. Auditoría previa

Búsqueda de `AlbumArtworkImage` y `album_artwork_image` en `lib/`, `test/` y `docs/` (repetida, sin asumir el inventario anterior).

| Referencia | Tipo | Acción |
|---|---|---|
| `lib/core/artwork/album_artwork_image.dart` (definición, 72 líneas) | Producción (definición; sin consumidores) | **Eliminado** |
| `lib/core/widgets/taki_artwork.dart:24` | Comentario | Conservado (no se toca `TakiArtwork`); registrado |
| `lib/core/widgets/taki_song_tile.dart:51` | Comentario | Conservado; registrado |
| `test/core/widgets/taki_artwork_test.dart:6` | Import | Sustituido por los imports del builder |
| `test/core/widgets/taki_artwork_test.dart:147` (grupo) | Test | Grupo renombrado; 2 tests **adaptados** |
| `test/core/widgets/taki_artwork_test.dart:156, 174` | Test (uso) | Sustituido por `AlbumArtworkBuilder` |
| `docs/DESIGN_SYSTEM.md:1001` | Documentación vigente (desactualizada) | Sin tocar; registrado |
| `docs/DESIGN_SYSTEM.md:1103` | Documentación histórica | Sin tocar; registrado |
| `docs/PHASE_1_8J_*.md`, `docs/PHASE_1_8K_*.md` | Histórico (informes de fase) | Sin tocar |

Consumidores de producción (cualquier `lib/` que importe el archivo o use la clase, fuera de su definición): **ninguno**. No se detuvo la eliminación.

## 2. Elementos eliminados

- `lib/core/artwork/album_artwork_image.dart`.

## 3. Tests eliminados

**Ninguno.** Los dos únicos tests que usaban la clase protegían contratos de integración de `TakiArtwork` con la cadena de artwork (petición al tamaño físico, álbum sin carátula → placeholder), no su implementación. Se adaptaron para no reducir cobertura.

## 4. Tests adaptados

`test/core/widgets/taki_artwork_test.dart`, grupo «AlbumArtworkBuilder (caché de carátulas existente)» (antes «AlbumArtworkImage …»). El `ImageProvider` se obtiene ahora con `AlbumArtworkBuilder` + `ArtworkCache` de prueba (`ProviderScope` con `artworkCacheProvider`); las aserciones no cambian.

| Test | Contrato que sigue protegiendo |
|---|---|
| pide la carátula al tamaño en píxeles reales | Una petición `(albumId 7, (48 × dpr).round())` y la imagen se muestra en `TakiArtwork` |
| un álbum sin carátula muestra el placeholder | Sin bytes → placeholder del tipo `playlist`, sin excepción |

Helper de test añadido en el propio archivo: `_withArtwork(cache, child)`.

## 5. Tests conservados

Sin cambios: los demás tests de `taki_artwork_test.dart` (placeholder, con imagen, fallo de imagen, semántica, mosaico, etc.), todos los de `album_artwork_builder_test.dart` y los de las pantallas.

## 6. Cobertura que queda

| Contrato | Quién lo protege ahora |
|---|---|
| Resolución de artwork (`albumId` + tamaño → bytes → `ImageProvider`) | `album_artwork_builder_test.dart` (individual y mosaico) |
| Decodificación acotada | `album_artwork_builder_test.dart`, grupo «decodificación acotada (Fase 1.8L)»: 1000² → 512, mosaico a 56 px |
| No upscaling | Mismo grupo: 512² → 512, 300² → 300, 64² → 64, 400×240 sin ampliar; `allowUpscaling` es `false` |
| Relación de aspecto | Mismo grupo: 1000×600 → 512×307 |
| Ausencia de artwork | Builder (`null`, bytes vacíos, `albumId` null) y `TakiArtwork` (placeholder), incl. el test adaptado |
| Errores de lectura | Builder (`null` sin excepción) y `TakiArtwork` (imagen que falla → placeholder) |
| Caché de carátulas | `ArtworkCache` (sus tests) y builder (no repite lecturas, comparte entre widgets, cache hit) |
| ImageCache de Flutter / `clear()` | Builder: «clear() de ArtworkCache y bytes nuevos: no se reutiliza la imagen decodificada anterior» y las pruebas de claves |
| Tamaño físico pedido | Builder (`(size × dpr).round()`, teselas `floor(size/2)`) y test adaptado de `TakiArtwork` |

Lo que dejan de cubrir los 2 tests de 1.8J sobre `AlbumArtworkImage` no era un contrato vigente: la propia 1.8J mostró que no comprobaban decodificación acotada.

## 7. Referencias restantes

- **Código (activo):** ninguna. Sin imports ni usos de `AlbumArtworkImage` / `album_artwork_image.dart`.
- **Tests:** ninguna.
- **Comentarios (para la siguiente fase):**
  - `lib/core/widgets/taki_artwork.dart:24` — «local (`AlbumArtworkImage`) o, en el futuro, una remota se ven igual».
  - `lib/core/widgets/taki_song_tile.dart:51` — «Carátula (p. ej. `AlbumArtworkImage`)».
- **Documentación (para la siguiente fase):**
  - `docs/DESIGN_SYSTEM.md:1001` — afirma que la carátula local llega como `AlbumArtworkImage`; ya no es cierto (llega de `AlbumArtworkBuilder`).
  - `docs/DESIGN_SYSTEM.md:1103` — mención histórica.
  - Informes históricos `PHASE_1_8J_*` y `PHASE_1_8K_*` (describen el estado de esas fases; no se reescriben).

## 8. Validaciones

- `flutter test`: **730 pasan** (igual que en 1.8L; no se eliminó ningún test).
- `flutter analyze`: sin problemas.
- `flutter build apk --debug`: correcto.
- Architecture test: **6/6**.
- `git diff` de `lib/core/artwork` (salvo la eliminación), `TakiArtwork`, `PlaylistCoverImages`, `AppColors`: sin cambios.

## 9. Git status

Cambios sin commit (acumulados desde 1.8A). Propios de 1.8M:

- `D lib/core/artwork/album_artwork_image.dart`
- `M test/core/widgets/taki_artwork_test.dart`
- `?? docs/PHASE_1_8M_REMOVE_ALBUM_ARTWORK_IMAGE.md`

Sin commit ni push.
