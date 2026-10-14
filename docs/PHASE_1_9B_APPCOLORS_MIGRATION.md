# Fase 1.9B — Migración y eliminación de AppColors

Migración directa a `TakiColors` (decisión de 1.9A). Sin cambios visuales ni funcionales. Sin commit ni push.

## 1. Cambios realizados

- Los tres `showModalBottomSheet` pasan de `AppColors.surfaceElevated` a `TakiColors.surfaceElevated`. El parámetro `backgroundColor` **se mantiene explícito** (no se depende de `bottomSheetTheme`).
- Las 4 expectativas de `AppColors.textSecondary` en `now_playing_page_test.dart` pasan a `TakiColors.textSecondary`, sin cambiar aserciones.
- `lib/core/theme/app_colors.dart` eliminado; el test de alias de `app_theme_test.dart` eliminado junto con su `import`.
- Sin cambios en `TakiColors`, `AppTheme.dark()` (ni su parámetro `accent`), artwork, diseño de los sheets ni `ARCHITECTURE.md` / `DESIGN_SYSTEM.md` (se actualizan en 1.9C).

## 2. Consumidores migrados

| Archivo | Cambio |
|---|---|
| `lib/app/widgets/song_actions_sheet.dart` | import `app_colors.dart` → `taki_colors.dart`; `backgroundColor: TakiColors.surfaceElevated` |
| `lib/features/playlists/presentation/pages/playlists_page.dart` | ídem (`_showActions`) |
| `lib/features/playlists/presentation/widgets/add_to_playlist_sheet.dart` | ídem |

## 3. Tests migrados / eliminados

- **Migrado:** `test/features/player/presentation/now_playing_page_test.dart`: 4 usos `AppColors.textSecondary` → `TakiColors.textSecondary` (favorito inactivo, aleatorio y repetir inactivos) y se quitó el `import` de `app_colors.dart` (ya existía el de `taki_colors.dart`). Mismas aserciones y valores esperados (los dos tokens valen lo mismo).
- **Eliminado:** en `test/app/app_theme_test.dart`, el test «AppColors es un alias de la paleta Taki (§22 paso 1)» (11 `expect`), que protegía la implementación del alias. El resto de tests de `AppTheme` (superficies, `bottomSheetTheme`, scrim, contraste, etc.) se conserva.

Nota: el archivo está en `test/app/`, no en `test/core/theme/`.

## 4. AppColors eliminado

`lib/core/theme/app_colors.dart` (15 miembros). Los 14 sin consumidor desaparecen sin efecto: 10 alias de `TakiColors` con equivalente exacto, `artworkShadow` (mismo color que `TakiElevation.artworkShadow`) y `accentCoral/Blue/Mint`, que eran históricos sin uso. No se añadió ningún token.

## 5. Referencias restantes

Búsqueda sensible a mayúsculas de `AppColors` / `app_colors.dart`:

| Tipo | Resultado |
|---|---|
| Producción, imports, tests | **Cero** |
| Comentario en código | `lib/core/theme/taki_colors.dart:9`: «Convive con `AppColors` hasta que la migración (§22) lo sustituya.» No se modificó (`TakiColors` está fuera de alcance). Pendiente para 1.9C |
| Documentación actual | `ARCHITECTURE.md` (2) y `DESIGN_SYSTEM.md` (10): sin corregir en esta fase, como se pidió |
| Histórico | `PHASE_1_8*`, `PHASE_1_9A_*`: no se tocan |

## 6. Validación visual/funcional

- En 1.9A un test temporal comprobó que, bajo `AppTheme.dark()`, un modal sheet con `backgroundColor: AppColors.surfaceElevated` y uno sin él producen el mismo color, forma, tinte, elevación, asa y tamaño. Aquí el color es el mismo token (`TakiColors.surfaceElevated`, valor `#1E222B`) y se sigue pasando de forma explícita, por lo que la equivalencia no depende del tema.
- Tests ejecutados específicamente: `app_theme_test`, `now_playing_page_test`, `playlists_page_test` y `add_to_playlist_sheet_test`: **127 pasan**.
- El menú de acciones de canción (`song_actions_sheet`) no tiene test propio; lo ejercitan `library_page_test`, `favorites_page_test` y `playlist_detail_page_test`, que pasan en la suite completa.
- No se hicieron capturas (la fase no las pedía).

## 7. Gates

- `flutter test`: **729 pasan** (730 − 1: el test de alias eliminado).
- `flutter analyze`: sin problemas.
- `flutter build apk --debug`: correcto.
- `test/architecture`: **6/6**.

## 8. Git status

Cambios propios de 1.9B (sin commit):

- `D lib/core/theme/app_colors.dart`
- `M lib/app/widgets/song_actions_sheet.dart`
- `M lib/features/playlists/presentation/pages/playlists_page.dart`
- `M lib/features/playlists/presentation/widgets/add_to_playlist_sheet.dart`
- `M test/app/app_theme_test.dart`
- `M test/features/player/presentation/now_playing_page_test.dart`
- `?? docs/PHASE_1_9B_APPCOLORS_MIGRATION.md`

`playlists_page.dart`, `add_to_playlist_sheet.dart` y `now_playing_page_test.dart` ya tenían cambios sin commit de 1.8; el resto del árbol es trabajo acumulado desde 1.8A. Sin commit ni push.
