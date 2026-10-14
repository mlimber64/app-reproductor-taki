# Fase 1.9D — Auditoría final de legacy/UI

Auditoría de solo lectura: **no se modificó ningún archivo salvo este informe**. Sin commit ni push.

## 1. Resumen ejecutivo

**Conclusión: PHASE 1 READY TO CLOSE.**

- No queda código de UI legacy activo: no existen `AppColors`, `ArtworkImage`, `AlbumArtworkImage`, `PlaylistCover`, `SongTile`, `PlayShuffleButtons`, `MessageView` ni `PlayingBars` (ni archivos ni símbolos) en `lib/` ni `test/`.
- Todos los widgets de `core/widgets`, `app/widgets` y `features/*/presentation/widgets` tienen consumidores reales de producción. Ningún huérfano.
- El único resolver de artwork de UI es `AlbumArtworkBuilder`; `ArtworkFileCache` sigue independiente.
- Arquitectura: test 6/6; las 6 excepciones entre features siguen siendo las documentadas; sin excepciones nuevas.
- Validaciones: 729 tests, `flutter analyze` limpio, `flutter build apk --debug` correcto.
- Quedan **solo deudas no bloqueantes** (§10): frases de estado obsoletas en `DESIGN_SYSTEM.md`, matices del tema, una dependencia sin uso y una API de componente sin uso en producción.

## 2. Estado de widgets legacy

Búsqueda por archivos, clases y consumidores en `lib/` y `test/` (los nombres están en §1 del resumen). Los archivos eliminados no existen: `song_tile.dart`, `play_shuffle_buttons.dart`, `message_view.dart`, `playing_bars.dart`, `artwork_image.dart` (core/widgets), `album_artwork_image.dart`, `playlist_cover.dart`, `app_colors.dart`.

Estado de los widgets existentes (consumidores = archivos de `lib/` distintos del propio):

| Archivo | Consumidores reales | Estado | Acción |
|---|---|---|---|
| `core/widgets/taki_artwork.dart` | 8 (pantallas, `TakiSongTile`, `TakiPlaylistCard`, `TakiMiniPlayer`…) | ACTIVO | Correcto |
| `taki_song_tile.dart` | `library_page`, `favorites_page`, `queue_page`, `playlist_detail_page` | ACTIVO | Correcto |
| `taki_mini_player.dart` | `MiniPlayer` (adaptador de `features/player`) → router | ACTIVO | Correcto |
| `taki_button.dart` / `taki_icon_button.dart` | Siete y seis archivos | ACTIVO | Correcto |
| `taki_section_header.dart` | `queue_page`, `playlists_page` | ACTIVO | Correcto (ver API sin uso en §10) |
| `taki_playlist_card.dart` | `playlists_page` | ACTIVO | Correcto |
| `taki_empty_state.dart` / `taki_error_state.dart` / `taki_state_view.dart` | Favoritos, Biblioteca, Playlists, detalle | ACTIVO | Correcto |
| `taki_playback_controls.dart` (`TakiRepeatMode`) | `now_playing_page` | ACTIVO | Correcto |
| `taki_progress_bar.dart` | `now_playing_page` | ACTIVO | Correcto |
| `taki_playing_indicator.dart` | vía `TakiSongTile` y `TakiPlaylistCard` | ACTIVO | Correcto |
| `taki_interaction.dart` (`TakiPressable`, `TakiFocusRing`) | Componentes Taki (primitivas internas) | ACTIVO | Correcto |
| `placeholder_page.dart` | `settings_page` (Ajustes provisional, según README) | ACTIVO | Mantener; no es legacy: es un placeholder declarado |
| `song_actions.dart` (`ExtraSongAction`, `ShowSongActions`) | `router`, páginas, `playlist_detail_page` | ACTIVO | Correcto |
| `app/widgets/song_actions_sheet.dart` | router / `showSongActions` | ACTIVO | Correcto (sheet Material deliberado, documentado) |
| `features/player/.../mini_player.dart` | `router` (App Shell) | ACTIVO | Correcto (adaptador sobre `TakiMiniPlayer`) |
| `features/playlists/.../add_to_playlist_sheet.dart`, `delete_playlist_dialog.dart`, `playlist_name_dialog.dart` | Páginas de playlists y `song_actions_sheet` | ACTIVO | Correcto (Material deliberado, documentado) |

Componentes Material crudos que siguen en `features/` y `app/`, todos deliberados y documentados en `DESIGN_SYSTEM.md` como «siguen en Material»: `AppBar`, `SnackBar`, `AlertDialog`/`TextButton` (diálogos), `ListTile` (sheets), `CircularProgressIndicator` (carga), `NavigationBar`. No hay `IconButton`, `ElevatedButton`, `Card` ni `Slider` sueltos en pantallas.

Widgets privados de pantalla (25): ninguno resuelve artwork ni duplica un `Taki*`; los que presentan filas/botones envuelven componentes Taki (`_PlaylistRow` → `TakiPlaylistCard`, `_NewPlaylistButton` → `TakiButton`, `_NowPlayingCard` → `TakiSongTile`, `_QueueRow` → `TakiIconButton`…). `_EmptyMessage` (Cola) es un aviso en línea cuyo hueco respecto a `TakiEmptyState` está documentado.

## 3. Estado de tokens/colores

| Elemento | Resultado | Clasificación |
|---|---|---|
| `AppColors` | 0 en `lib/` y `test/` | Resuelto (1.9B) |
| `Color(0x…)` / hex fuera de `TakiColors` | Solo `TakiElevation.artworkShadow` (`Color(0x66000000)`, sombra del artwork grande) | Token válido y justificado (componente de elevación) |
| `Colors.transparent` | `app_theme.dart` (tintes de superficie, overlays) y `taki_playback_controls.dart:258` | Color contextual legítimo |
| `ColorScheme.fromSeed` | `app_theme.dart:21`, con el `colorScheme` sobrescrito por tokens | Deuda aceptable (los roles no definidos vienen de Material; ya documentado) |
| Parámetro `accent` de `AppTheme.dark()` | Se usa dentro del tema con valor por defecto `TakiColors.primary`; ningún llamador pasa otro valor | Deuda aceptable (I12 lo llama «sin uso»; es impreciso, no afecta a la UI) |
| `withOpacity`, `google_fonts` | 0 | Limpio (las fuentes son assets) |
| Clases de tema anteriores | No hay | Limpio |

## 4. Estado de componentes Taki*

Todos los solicitados están en uso real de producción: `TakiArtwork`, `TakiSongTile`, `TakiMiniPlayer`, `TakiButton`, `TakiIconButton`, `TakiSectionHeader`, `TakiPlaylistCard`, `TakiEmptyState`, `TakiErrorState`, `TakiPlaybackControls`, `TakiProgressBar` y `TakiRepeatMode` (este último vía `now_playing_page`). Sin duplicados de funcionalidad: no hay otro componente que haga lo mismo que un `Taki*`; los widgets privados de pantalla son composición específica.

API presente pero no usada en producción (solo la ejercitan tests): `TakiSectionHeaderAction` (parámetro `action` de `TakiSectionHeader`). Ver §10.

## 5. Estado del sistema de artwork

Flujo confirmado: `ArtworkRepository → ArtworkCache → AlbumArtworkBuilder → ResizeImage(MemoryImage) → TakiArtwork`.
- `MemoryImage`/`ResizeImage` se construyen solo en `album_artwork_builder.dart`; `artworkCacheProvider` se lee en UI solo ahí (la otra lectura es `SongsNotifier.rescan` → `clear()`).
- 0 consumidores de `AlbumArtworkImage`, `ArtworkImage`, `PlaylistCover`; adaptador privado de carátulas: ninguno (`_Artwork` de Reproduciendo solo envuelve el builder).
- `ArtworkFileCache` (`features/player/infrastructure`): llama directamente a `ArtworkRepository`, guarda archivos de 512 px para notificación/lockscreen, lo usan `player_bootstrap` y `TakiAudioHandler`. No hay migración accidental pendiente.
- Limitación conocida sin resolver: imágenes no cuadradas con `ResizeImage(width)` (documentada en `DESIGN_SYSTEM.md` y en los informes 1.8K/1.8O).

## 6. Estado arquitectónico

- `test/architecture/dependency_rules_test.dart`: **6/6**.
- Verificación independiente por imports: `core` no importa `features` ni `app`; `features` no importan `app`; `domain`/`infrastructure` no importan `presentation`; `core/domain` sin Flutter.
- Imports feature → feature: **6**, exactamente la lista permitida (Biblioteca y Favoritos → `player_providers`; Reproduciendo → `favorites_providers`; `playlists_providers` y detalle → `songs_notifier`; detalle → `player_providers`). Todos hacia `presentation/providers`, API pública de la otra feature. **Ninguna excepción nueva.**
- `app/` (→ features) sigue siendo la capa de composición (router, tema, `song_actions_sheet`).
- Observaciones sin impacto: `playlist_cover_albums.dart` y `playlist_cover_images.dart` viven en la raíz de `features/playlists/presentation/` (no en `widgets/`); las carpetas `features/search` y `features/settings` (salvo `settings_page.dart`) contienen solo `.gitkeep` (andamiaje).

## 7. Estado de documentación

`ARCHITECTURE.md`, `DESIGN_SYSTEM.md` (§1 y componentes) y `README.md` coinciden con el código: flujo de artwork, `TakiColors` como fuente de tokens, 6 excepciones, `AppColors` marcado como eliminado. Los valores hexadecimales de §1 coinciden con `TakiColors` (comprobado en 1.9C).

Las menciones a componentes retirados (`SongTile`, `PlayShuffleButtons`, `MessageView`, `PlayingBars`, `ArtworkImage`, `PlaylistCover`, `AppColors`, `_PlaylistRow`, `_CircleButton`, `_ControlButton`, `_SectionLabel`) aparecen solo como notas de sustitución, filas «eliminado», columnas «Parte de», el inventario de partida o el registro de fases; ninguna las presenta como vigentes.

**Inconsistencias encontradas (no corregidas en esta fase; ver §10):**
1. `DESIGN_SYSTEM.md:3-5`: «Estado: especificación (Fase 1). Nada de este documento está implementado todavía salvo donde se indica "actual"». Ya no es cierto: el Design System está implementado y migrado.
2. `DESIGN_SYSTEM.md:~1023`: «Tampoco los usa ninguna pantalla todavía» (API 1.4B) — falso hoy.
3. `DESIGN_SYSTEM.md:~1105`: «Pendiente: el mini player sigue siendo el widget legacy…» — resuelto en 1.6E.
4. `DESIGN_SYSTEM.md:~1136`: «Componentes de reproducción (1.6B) … todavía sin usar en ninguna pantalla» — resuelto en 1.6C–1.6E.
5. `DESIGN_SYSTEM.md:~1222`: «`LibraryPage` migrada; Favoritos todavía no» — resuelto en 1.7B.
6. `DESIGN_SYSTEM.md` I12: dice que `accent` de `AppTheme.dark()` está «sin uso»; en realidad se usa dentro del tema con su valor por defecto y nadie pasa otro.
7. La fila `MiniPlayer` del inventario de partida (`DESIGN_SYSTEM.md:66`) describe el widget anterior a la migración sin marcarlo (el resto de esa tabla sí marca lo eliminado).
Los puntos 2-5 están dentro de entradas de fases que son registro histórico, pero no están etiquetadas como tales.

## 8. Estado de tests

- **Tests de componentes eliminados o APIs inexistentes:** ninguno (las menciones a `PlaylistCover` en tests son 2 comentarios que ya dicen «antiguo… ya eliminado»).
- **Tests huérfanos:** ninguno; los 7 archivos de test sin un `lib` homónimo prueban sujetos existentes (`widget_test` → `app.dart`, `favorites_resolution_test` → `app.dart`, `taki_icon_motion_test` → tokens, `taki_layout_tokens_test`, `taki_empty_error_state_test` → dos componentes, `filtered_references_test` → casos de uso).
- **Helpers de test:** todos usados (`artwork_image.dart`: 9 archivos; `library_fakes.dart`: 24; `player_fakes.dart`: 10; `favorites_fakes.dart`/`playlists_fakes.dart`: 7; `fake_just_audio_player.dart`: 1). Nombre de `artwork_image.dart`: mejorable (coincide con el archivo eliminado), sin riesgo funcional; ver 1.8O.
- Tests de `AppTheme`: conservados (superficies, sheets, contraste).

## 9. Archivos potencialmente huérfanos

Comprobación de cada archivo de `lib/` (87): **todos tienen al menos un importador** en `lib/` (salvo `main.dart`, que es el punto de entrada). Símbolos públicos sin uso fuera de su archivo: los que aparecen (`TakiStateMetrics`, `SongAction`, `SongActionsSheet`, `TakiSectionHeaderAction`, `TakiPlayPauseButton`, `AppRoutes`, `AppShell`, `PlayerBootstrap`, `LibraryState`, `SongsNotifier`, y varios providers) se usan **dentro de su propio archivo** (mecánica interna de otro símbolo, p. ej. `favoriteIdsProvider` dentro de `favorites_providers.dart`) o son tipos de API pública de un componente; ninguno es un residuo.

Candidatos dudosos (no se eliminan):

| Candidato | Evidencia | Decisión |
|---|---|---|
| Dependencia `cupertino_icons` (`pubspec.yaml`) | Ningún `CupertinoIcons` en `lib/`, `test/` ni Kotlin | Reportar; eliminar en una limpieza de dependencias |
| `TakiSectionHeaderAction` / parámetro `action` | Sin uso en producción; 1 test | Mantener (API documentada del componente) |
| Carpetas `.gitkeep` de `search`/`settings` | Andamiaje vacío de la arquitectura | Mantener (probable uso en Phase 2+) |

## 10. Hallazgos clasificados

### BLOQUEANTE
Ninguno.

### DEUDA TÉCNICA (no bloqueante)
| # | Hallazgo | Sugerencia |
|---|---|---|
| D1 | Frases de estado obsoletas en `DESIGN_SYSTEM.md` (§7 puntos 1-7), sobre todo el encabezado «especificación… nada implementado» | Pequeña fase documental antes de Phase 2.0 (retocar el encabezado y etiquetar como histórico los registros de fase) |
| D2 | Parámetro `accent` de `AppTheme.dark()` sin llamadores con otro valor, y `ColorScheme.fromSeed` como base | Decidir en una fase de tema si se simplifica; hoy no afecta a la UI |
| D3 | `TakiSectionHeaderAction`/`action` sin uso en producción | Mantener hasta que haya una pantalla que lo necesite |
| D4 | Dependencia `cupertino_icons` sin uso | Limpieza de dependencias |
| D5 | Helper `test/helpers/artwork_image.dart` con nombre ambiguo | Renombrar opcionalmente (9 imports) |
| D6 | Comentario de `album_artwork_builder.dart:66` («como el `PlaylistCover` anterior») | Retocar en una limpieza de comentarios; no se tocó por estar el builder protegido |
| D7 | Carátulas no cuadradas: `ResizeImage(width)` + `BoxFit.cover` puede verse menos nítido; sin medir con carátulas reales | Decidir con evidencia real en una fase de artwork posterior |
| D8 | Árbol de trabajo: todo el trabajo de 1.8A–1.9C está **sin commit** (decisión del usuario) | Hacer commits antes de empezar Phase 2.0 |

### HISTÓRICO
Menciones a componentes retirados en los registros de fase de `DESIGN_SYSTEM.md`, en `ARCHITECTURE.md` (notas de reemplazo) y en los informes `PHASE_1_8*`, `PHASE_1_9A`, `PHASE_1_9B`, `PHASE_1_9C`: conservadas.

### FUERA DE ALCANCE (Phase 2.0+ o mejoras visuales futuras)
- Migración visual de `AppBar`, sheets, diálogos, `SnackBar`, spinner y `NavigationBar` (hoy Material deliberado).
- Componente para avisos en línea (`_EmptyMessage` de la Cola) y otros huecos listados en `DESIGN_SYSTEM.md` («Pendiente: gaps documentados»).
- Ajustes provisional (`PlaceholderPage`), búsqueda, catálogo online, API, streaming, autenticación, sincronización y nuevos providers.

## 11. Cambios realizados

**Ninguno** en `lib/`, `test/` ni documentación vigente. Único archivo creado: este informe.

## 12. Validaciones ejecutadas

| Validación | Resultado |
|---|---|
| `flutter test` | **729 pasan** |
| `flutter analyze` | Sin problemas |
| `test/architecture` | **6/6** |
| `flutter build apk --debug` | Correcto (ejecutado por ser el cierre de la Fase 1, aunque no se cambió código) |

Git (`git status --short`):
- **Acumulado de fases anteriores (1.8A–1.9C), sin commit:** modificados `lib/` (12 archivos de UI/tema/artwork) y `test/` (9), eliminados `lib/core/artwork/album_artwork_image.dart`, `lib/core/theme/app_colors.dart`, `lib/core/widgets/artwork_image.dart`, `lib/features/playlists/presentation/widgets/playlist_cover.dart`; nuevos `lib/core/artwork/album_artwork_builder.dart`, `playlist_cover_albums.dart`, `playlist_cover_images.dart`, `test/core/artwork/album_artwork_builder_test.dart`, `add_to_playlist_sheet_test.dart`, `playlist_cover_albums_test.dart`, `test/helpers/artwork_image.dart` y los informes `PHASE_1_8J` … `PHASE_1_9C`; `ARCHITECTURE.md` y `DESIGN_SYSTEM.md` modificados.
- **Propio de 1.9D:** `?? docs/PHASE_1_9D_FINAL_UI_LEGACY_AUDIT.md` (único).

## 13. Recomendación final

**PHASE 1 READY TO CLOSE.**

Motivos: (1) no hay código de UI legacy activo ni referencias activas a los componentes retirados; (2) el flujo de artwork es único y coherente, con `ArtworkFileCache` separado por diseño; (3) la arquitectura se mantiene con las 6 excepciones documentadas y sin nuevas; (4) 729 tests, análisis limpio y build correcto; (5) la documentación vigente describe el estado real, salvo frases de estado obsoletas (D1) que no afectan al código ni al comportamiento.

Antes de empezar Phase 2.0 se recomienda, sin que bloquee el cierre: commitear el trabajo acumulado (D8) y hacer una pequeña fase documental (D1), con la limpieza opcional de D4–D6.
