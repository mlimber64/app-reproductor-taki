# Fase 1.8N — Documentación y comentarios del artwork

Fase solo documental: sin cambios de comportamiento de producción. Sin commit ni push.

## 1. Documentos actualizados

### `docs/ARCHITECTURE.md`
- Árbol de carpetas: `core/artwork/` ahora lista `ArtworkCache`, `AlbumArtworkBuilder` y los providers; `core/widgets/` ya no menciona `ArtworkImage`.
- Sección `core/artwork`: añadidos `AlbumArtworkBuilder` / `AlbumArtworkMosaicBuilder`, el papel de `ResizeImage` (limita la decodificación, no amplía, conserva el aspecto), la clave de la `ImageCache` de Flutter y el flujo:
  `ArtworkRepository → ArtworkCache → AlbumArtworkBuilder → MemoryImage + ResizeImage → TakiArtwork`.
- Aclarado que `ArtworkCache` guarda bytes, el builder resuelve el `ImageProvider`, `TakiArtwork` es solo presentación y **`ArtworkFileCache` es independiente** (no pasa por `ArtworkCache` ni por los builders).
- Tabla de `core/widgets`: eliminada la fila de `ArtworkImage` y la nota «solo lo usa `PlaylistCover`».
- Añadido el bloque «Carátulas reemplazadas (1.8A–1.8M)».

### `docs/DESIGN_SYSTEM.md`
- Inventario de partida: `ArtworkImage` y `PlaylistCover` marcados como eliminados en 1.8; nota de sustitución por `TakiArtwork` + `AlbumArtworkBuilder`; lista «Qué se reutiliza» actualizada; evidencias de I4 e I8 marcadas.
- §7.1 (origen transparente) y §7.3 (mosaico de playlist: selección con `playlistCoverAlbumIds`, resolución con `PlaylistCoverImages`, 2×2 solo con 4 imágenes).
- Componentes: fila de `TakiArtwork` (ya no «mosaico, pendiente») y su API (`ImageProvider?` desde `AlbumArtworkBuilder`); nota de 1.4A («ninguna pantalla los usa todavía») marcada como histórica.
- Registro de fases 1.6A–1.7C-2: cada mención a «bytes → `MemoryImage`», a los adaptadores repetidos («segunda/tercera/cuarta copia») y a `PlaylistCover` pendiente quedó marcada como **histórica** y, donde era un hueco, como **resuelta** en su fase (1.8B–1.8H).
- Nuevo bloque **«Estado del artwork — Fases 1.8A–1.8M (vigente)»**: flujo, resolución, decodificación, consumidores, mosaico, sheet (1.8H), elementos retirados, `ArtworkFileCache` independiente y el límite conocido de las imágenes rectangulares (sin resolver).

## 2. Referencias eliminadas (texto vigente corregido)

| Dónde | Antes | Ahora |
|---|---|---|
| `DESIGN_SYSTEM.md` API de `TakiArtwork` | «llega como `AlbumArtworkImage`» | «`ImageProvider?` desde `AlbumArtworkBuilder` (`ArtworkCache` → `MemoryImage` + `ResizeImage`)» |
| `DESIGN_SYSTEM.md` Reproduciendo (1.6A) | «no de `AlbumArtworkImage`» | «hoy la resuelve `AlbumArtworkBuilder`» |
| `DESIGN_SYSTEM.md` componentes | `ArtworkImage` + `PlaylistCover` (mosaico, pendiente) | ambos eliminados en 1.8; mosaico = `TakiArtwork.mosaic` |
| `ARCHITECTURE.md` árbol y tabla | `ArtworkImage` como widget de `core` | eliminado |
| `ARCHITECTURE.md` | «`ArtworkImage` … se retirará con esa migración» | retirado; sustituido por el bloque de carátulas reemplazadas |

## 3. Referencias históricas conservadas (marcadas como tales)

- `DESIGN_SYSTEM.md`: menciones a `ArtworkImage`/`PlaylistCover` en el inventario de partida (marcadas «eliminado en 1.8») y en los registros de 1.7C-1 (`_PlaylistRow` + `PlaylistCover`), 1.7C-2 y en la lista «Retirado» del bloque nuevo.
- `ARCHITECTURE.md`: la nota de carátulas reemplazadas.
- Informes `docs/PHASE_1_8J_*`, `PHASE_1_8K_*` y `PHASE_1_8M_*`: no se reescriben.

## 4. Comentarios de código actualizados

Solo comentarios; sin cambios de lógica ni de API.

- `lib/core/widgets/taki_artwork.dart`: «una carátula local (`AlbumArtworkImage`)…» → «(la que resuelve `AlbumArtworkBuilder`)…».
- `lib/core/widgets/taki_song_tile.dart`: «p. ej. `AlbumArtworkImage`» → «p. ej. la de `AlbumArtworkBuilder`».
- `test/features/playlists/presentation/add_to_playlist_sheet_test.dart` y `playlist_cover_albums_test.dart`: dos comentarios que citaban `PlaylistCover` ahora dicen «el antiguo `PlaylistCover` (ya eliminado)».

## 5. Búsqueda final (`lib/`, `test/`, `docs/`)

Patrón: `AlbumArtworkImage`, `album_artwork_image`, `ArtworkImage`, `PlaylistCover` (distinguiendo mayúsculas).

| Tipo | Resultado |
|---|---|
| Código activo | **Ninguna referencia** a las clases eliminadas |
| Falsos positivos | `test/helpers/artwork_image.dart` (helper de tests de 1.8L) y sus `import`; no es la clase eliminada |
| Comentario de código | `lib/core/artwork/album_artwork_builder.dart:66` — «como el `PlaylistCover` anterior». **No se modificó** (el builder está fuera del alcance de la fase). Pendiente para una limpieza posterior |
| Comentarios de test | Los dos corregidos arriba; ninguno queda sin marcar |
| Documentación actual | Solo menciones marcadas como eliminadas/históricas (ver §3) |
| Documentación histórica | `PHASE_1_8J/K/M` (se conservan) |

## 6. Tests

`flutter test`: **730 pasan** (sin cambios respecto a 1.8M).

## 7. Analyze

`flutter analyze`: sin problemas.

## 8. Build

`flutter build apk --debug`: correcto.

## 9. Architecture

`test/architecture`: **6/6**.

## 10. Git status

Cambios propios de 1.8N (sin commit):

- `M docs/ARCHITECTURE.md`
- `M docs/DESIGN_SYSTEM.md`
- `M lib/core/widgets/taki_artwork.dart` (solo comentario)
- `M lib/core/widgets/taki_song_tile.dart` (solo comentario)
- `add_to_playlist_sheet_test.dart` y `playlist_cover_albums_test.dart` (en `test/features/playlists/presentation/`): solo comentario; siguen como archivos nuevos sin seguimiento (`??`) desde 1.8E/1.8H
- `?? docs/PHASE_1_8N_ARTWORK_DOCUMENTATION.md`

El resto es trabajo acumulado sin commit desde 1.8A. No se tocaron `AlbumArtworkBuilder`, `ArtworkCache`, `ArtworkRepository`, `MediaStoreArtworkRepository`, `ArtworkFileCache`, la lógica de `TakiArtwork` ni `AppColors`.
