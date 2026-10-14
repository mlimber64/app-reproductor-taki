# Fase 1.9A — Auditoría técnica de AppColors

Solo auditoría: no se modificó código de producción, tests, colores ni UI. Para una comprobación se usó un test temporal (`test/zz_sheet_bg_probe_test.dart`), ya **eliminado** (ver §6). Sin commit ni push.

## 1. Estado actual

- `AppColors` (`lib/core/theme/app_colors.dart`) es un **alias temporal** de `TakiColors`: casi todos sus valores son `= TakiColors.x`. Solo `accentCoral`, `accentBlue`, `accentMint` y `artworkShadow` son literales propios.
- **Producción:** solo **3 usos**, todos `AppColors.surfaceElevated` como `backgroundColor:` de un `showModalBottomSheet`. No hay otro uso de `AppColors` en `lib/` fuera de su propia definición.
- **Tests:** `test/app/app_theme_test.dart` (un test de alias) y `test/features/player/presentation/now_playing_page_test.dart` (4 usos de `AppColors.textSecondary`).
- El tema global ya define `bottomSheetTheme.backgroundColor = TakiColors.surfaceElevated` (`app_theme.dart:170-172`), así que los 3 usos de producción **repiten el valor que el tema ya aplica**.
- `TakiColors` comenta «Convive con `AppColors` hasta que la migración (§22) lo sustituya».

### Referencias (sin informes `PHASE_1_8*`)

| Tipo | Archivo:línea | Detalle |
|---|---|---|
| Producción (definición) | `core/theme/app_colors.dart` | La clase; comentarios internos |
| Producción (uso) | `app/widgets/song_actions_sheet.dart:7, 29` | import + `backgroundColor: AppColors.surfaceElevated` |
| Producción (uso) | `features/playlists/presentation/pages/playlists_page.dart:4, 49` | ídem |
| Producción (uso) | `features/playlists/presentation/widgets/add_to_playlist_sheet.dart:5, 23` | ídem |
| Comentario | `core/theme/taki_colors.dart:9` | «Convive con `AppColors`…» |
| Test | `test/app/app_theme_test.dart:6, 16-27` | alias (11 `expect`) |
| Test | `test/features/player/presentation/now_playing_page_test.dart:9, 138, 233, 258, 280` | `AppColors.textSecondary` |
| Documentación actual | `ARCHITECTURE.md:33, 265`; `DESIGN_SYSTEM.md:60, 82, 108, 110, 965, 969, 973, 1074, 1091, 1211` | Ver §3 (algunas desactualizadas) |
| Histórico | `DESIGN_SYSTEM.md` §1.8 (tokens que se retiran) y registro de fases | Conservar |

## 2. Inventario de AppColors

Usos medidos por nombre (`lib` / `test`):

| AppColors | Valor actual | Consumidor en `lib` | Uso en tests | Equivalente `TakiColors` | Equivalencia |
|---|---|---|---|---|---|
| `background` | `= TakiColors.background` (`#0E1016`) | ninguno | alias (1) | `background` | exacto (es el mismo valor por referencia); sin uso |
| `surface` | `= TakiColors.surface` (`#161920`) | ninguno | alias (1) | `surface` | exacto; sin uso |
| `surfaceElevated` | `= TakiColors.surfaceElevated` (`#1E222B`) | **3** (fondo de modal sheets) | alias (1) | `surfaceElevated` | exacto (y además ya es `bottomSheetTheme.backgroundColor`) |
| `border` | `= TakiColors.outline` (`#2E3340`) | ninguno | alias (1) | `outline` | exacto por valor; el **nombre** cambia (`border` → `outline`); sin uso |
| `textPrimary` | `= TakiColors.textPrimary` (`#F2F0EB`) | ninguno | alias (1) | `textPrimary` | exacto; sin uso |
| `textSecondary` | `= TakiColors.textSecondary` (`#A3A6B0`) | ninguno | alias (1) + now_playing (4) | `textSecondary` (también `iconSecondary` = mismo valor) | exacto; sin uso en producción |
| `accent` | `= TakiColors.primary` (`#FF8A3D`) | ninguno | alias (1) | `primary` (`active` = `primary`) | exacto por valor; nombre distinto |
| `accentCoral` | `Color(0xFFFF7A59)` | ninguno | ninguno | ninguno | histórico/no usado; no corresponde (el propio comentario dice «se retiran con AppColors») |
| `accentBlue` | `Color(0xFF7C9CFF)` | ninguno | ninguno | ninguno | histórico/no usado; no corresponde |
| `accentMint` | `Color(0xFF3DD6B0)` | ninguno | ninguno | ninguno (el valor coincide con `success`, pero el significado no) | histórico/no usado; no corresponde |
| `onAccent` | `= TakiColors.onPrimary` | ninguno | alias (1) | `onPrimary` | exacto; nombre distinto; sin uso |
| `onTextPrimary` | `= TakiColors.onTextPrimary` | ninguno | alias (1) | `onTextPrimary` | exacto; sin uso |
| `miniProgressTrack` | `= TakiColors.divider` (`#23272F`) | ninguno | alias (1) | `divider` (el doc §10 ya lo define como `divider`) | exacto; sin uso |
| `seekTrack` | `= TakiColors.divider` | ninguno | alias (1) | `divider` (§11) | exacto; sin uso |
| `artworkShadow` | `Color(0x66000000)` | ninguno | ninguno | `TakiElevation.artworkShadow` (un `BoxShadow` con `color: Color(0x66000000)`); no es un `Color` de `TakiColors` | equivalente semántico (mismo color, distinto tipo y lugar); sin uso |

Resumen: de 15 miembros, **solo 1 (`surfaceElevated`) se usa en producción**; 14 no tienen consumidor en `lib/`.

## 3. Consumidores de producción

Los tres son el mismo patrón: `showModalBottomSheet(..., backgroundColor: AppColors.surfaceElevated, showDragHandle: true, …)`.

| Consumidor | Qué se abre | Color y papel |
|---|---|---|
| `song_actions_sheet.dart:29` | Menú de acciones de una canción (cola, favoritos, playlist, acciones extra) | `surfaceElevated`: **fondo (surface)** de una hoja modal, nivel 2 |
| `playlists_page.dart:49` | Menú «Renombrar / Eliminar» de una playlist (`_showActions`) | ídem |
| `add_to_playlist_sheet.dart:23` | Selector «Añadir a una playlist» (contiene la portada y filas `ListTile`) | ídem |

No actúan como texto, icono, divisor, estado ni overlay. El scrim de los modales, la forma (radio superior `xl`) y el tinte (`surfaceTintColor` transparente) ya los da el tema; los tres sitios solo sobrescriben el fondo con el mismo valor.

**Documentación actual desactualizada (hallazgo, no corregido en esta fase de auditoría):**
- `DESIGN_SYSTEM.md:60` describe `AppColors` con la paleta anterior (fondo `#111318`, surface `#1B1E26`, acento ámbar `#F5A524`…); hoy sus valores son los de `TakiColors` (p. ej. fondo `#0E1016`, acento `#FF8A3D`). Es la tabla del inventario «anterior a la migración», pero no lo marca para esta fila.
- `ARCHITECTURE.md:265` presenta `AppColors` como «la paleta "Medianoche + ámbar" … acentos alternativos y colores del reproductor»; hoy es un alias de `TakiColors`.
- `DESIGN_SYSTEM.md:108` (I10) y `:110` (I12) citan `app_colors.dart` como evidencia; I12 (tokens sin uso) sigue siendo cierta.

## 4. Comparación con TakiColors

`TakiColors` ya cubre todas las funciones que pide la auditoría:

| Función | Tokens existentes |
|---|---|
| background | `background` |
| surface | `surface`, `surfaceElevated` (sheets, menús, diálogos), `surfaceHighest` |
| texto | `textPrimary`, `textSecondary`, `textMuted`, `iconPrimary`, `iconSecondary` |
| muted | `textMuted` |
| selected | `selected` (= `primaryContainer`), `active` (= `primary`) |
| primary | `primary`, `onPrimary`, `primaryPressed`, `primaryContainer`, `onPrimaryContainer` |
| disabled | `disabledContent`, `disabledContainer` |
| overlay | `scrim` (modales), `pressedOverlay`, `artworkScrim` |
| líneas / estados | `divider`, `outline`; `error`, `errorContainer`, `success`, `warning` |

**No falta ningún token** para los 3 usos de producción ni para los miembros de `AppColors` con alias. Para los que no tienen equivalente (`accentCoral/Blue/Mint`) no hay consumidores, así que no hay necesidad de token nuevo. Sin tokens nuevos que documentar como necesarios.

## 5. Tests

| Test | Contrato que protege | Comentario |
|---|---|---|
| `app_theme_test.dart:16` «AppColors es un alias de la paleta Taki» | Que cada miembro de `AppColors` sea igual a su token Taki | Prueba de **implementación del alias**; existe solo mientras exista `AppColors`. Desaparece con él (no hay comportamiento que conservar) |
| `now_playing_page_test.dart:138, 233, 258, 280` | Que el icono de favorito/aleatorio/repetir **inactivo** se dibuje con el color secundario | Protege un **comportamiento visible**; usa `AppColors.textSecondary` solo como valor esperado (= `TakiColors.textSecondary`). Debe permanecer y pasar a `TakiColors.textSecondary` (o `iconSecondary`) sin cambiar su aserción |
| `app_theme_test.dart:42` (`bottomSheetTheme.backgroundColor == surfaceElevated`) y `:43` (scrim) | El tema fija el fondo de los sheets | Independiente de `AppColors`; es lo que respalda que quitar el `backgroundColor` explícito no cambia nada |

**Ningún test** comprueba el color de fondo de los tres sheets abiertos (`song_actions_sheet`, `_showActions` de playlists, `addSongsToPlaylistFlow`). Los tests que los abren (p. ej. `playlists_page_test.dart:339`, `add_to_playlist_sheet_test.dart`) verifican solo que existen y su contenido; los de `playlists_page_test` usan `TakiApp` (con `AppTheme.dark()`) y los de la hoja de añadir usan `MaterialApp(theme: AppTheme.dark())`. No se modificó ningún test.

## 6. Riesgos visuales

Comprobación empírica (test temporal, ya eliminado): bajo `MaterialApp(theme: AppTheme.dark())` se abrió un `showModalBottomSheet` **con** `backgroundColor: AppColors.surfaceElevated` y **sin** él (`null`), ambos con `showDragHandle: true`. Se compararon color del `Material`, forma, tinte, elevación, color del asa y tamaño:

| Propiedad | Con `AppColors.surfaceElevated` | Sin parámetro |
|---|---|---|
| Color del fondo | `#1E222B` (0.1176, 0.1333, 0.1686) | idéntico |
| Forma | radio superior 24 | idéntica |
| Tinte de superficie | transparente | idéntico |
| Elevación | 1.0 | idéntica |
| Color del asa | (0.6392, 0.6510, 0.6902) | idéntico |
| Tamaño | 800×148 | idéntico |

| Consumidor | Color | Contraste | Estado seleccionado | Fondo | Overlay | Accesibilidad |
|---|---|---|---|---|---|---|
| `song_actions_sheet` | Sin cambio (medido) | Sin cambio | No aplica | Sin cambio | Scrim del tema, sin cambio | Sin cambio |
| `playlists_page` (`_showActions`) | Sin cambio (medido) | Sin cambio | No aplica | Sin cambio | Sin cambio | Sin cambio |
| `add_to_playlist_sheet` | Sin cambio (medido) | Sin cambio | No aplica | Sin cambio | Sin cambio | Sin cambio |

Condiciones y límites:
- La equivalencia depende de que el sheet se abra bajo `AppTheme.dark()`; la app (`app.dart:27-29`, tema oscuro forzado) y los tests de esos flujos lo hacen. Un `showModalBottomSheet` bajo otro tema (p. ej. un `MaterialApp` de test sin tema) **sí** cambiaría de color; no hay ninguno en producción.
- Cambios de ese tipo en los tests de otros flujos podrían aparecer solo si un test abre un sheet sin `AppTheme`; hoy no se observó ninguno.
- No se hicieron capturas (la fase no las pedía). La medición es de propiedades, no visual.
- Los 14 miembros sin consumidor no pueden cambiar la UI al eliminarse.

## 7. Opciones de migración

### Opción A — migración directa (hay equivalente exacto)
- **Qué:** cambiar `AppColors.surfaceElevated` por `TakiColors.surfaceElevated` en los 3 sitios (mismo valor, mismo tipo), o, equivalentemente, **quitar el parámetro** porque el tema ya lo aplica.
- **Ventajas:** cambio mínimo; sin tokens nuevos; valor idéntico por referencia. Quitar el parámetro además elimina duplicación con `bottomSheetTheme`.
- **Desventajas:** quitar el parámetro hace que el fondo dependa del tema (los tests o usos bajo otro tema cambiarían); mantener `TakiColors.surfaceElevated` explícito conserva el comportamiento actual bajo cualquier tema.
- **Cambios necesarios:** 3 archivos de producción (import + línea); ajustar `now_playing_page_test` a `TakiColors.textSecondary`; eliminar el test de alias.

### Opción B — ampliar TakiColors
- **Qué:** añadir tokens (p. ej. equivalentes de `accentCoral/Blue/Mint`, `artworkShadow` como `Color`).
- **Ventajas:** ninguna en el estado actual.
- **Desventajas:** añadiría tokens sin consumidores y contradice §1.8 del Design System, que los retira.
- **Cambios necesarios:** ninguno justificado. **No hace falta** por lo auditado.

### Opción C — conservar AppColors parcialmente
- **Qué:** dejar `AppColors` con un subconjunto.
- **Ventajas:** ninguna técnica; ningún uso actual «no pertenece al Design System».
- **Desventajas:** mantiene dos fuentes de verdad y la deuda del alias.
- **Cambios necesarios:** decidir qué subconjunto; no hay candidato objetivo.

## 8. Recomendación técnica

Según el código actual, la **Opción A** es la que cubre todo lo encontrado: el único uso de producción tiene un equivalente exacto y no falta ningún token. La variante de menor riesgo es reemplazar por `TakiColors.surfaceElevated` (comportamiento idéntico bajo cualquier tema); quitar el parámetro también es equivalente bajo `AppTheme.dark()` (medido), pero añade dependencia del tema, así que conviene decidirlo explícitamente.

Puntos a decidir/vigilar al eliminar:
1. Los 14 miembros sin uso se eliminan sin efecto en UI; `accentCoral/Blue/Mint` ya estaban marcados «se retiran con AppColors» (§1.8, I12).
2. `artworkShadow` de `AppColors` es redundante con `TakiElevation.artworkShadow`.
3. El test de alias (`app_theme_test.dart:16-27`) se elimina con la clase; los 4 usos de `AppColors.textSecondary` en `now_playing_page_test` se migran a `TakiColors.textSecondary`.
4. Actualizar `ARCHITECTURE.md:33, 265`, `DESIGN_SYSTEM.md:60, 82, 91, 108-110, 965, 969, 973, 1074, 1211` y el comentario de `taki_colors.dart:9`.
5. El parámetro `accent` de `AppTheme.dark()` (I12) es una deuda aparte; no pertenece a `AppColors`.

## 9. Próxima fase propuesta

**Fase 1.9B — Eliminación de AppColors** (una sola fase, alcance pequeño):
1. Migrar los 3 usos de `backgroundColor` (decidir: `TakiColors.surfaceElevated` explícito o quitar el parámetro).
2. Migrar `now_playing_page_test` a `TakiColors.textSecondary`.
3. Eliminar `app_colors.dart` y su test de alias.
4. Actualizar el comentario de `taki_colors.dart` y los documentos listados en §8.
5. Comprobación visual de los 3 sheets (propiedades, o capturas si se quiere) y gates: `flutter test`, `flutter analyze`, `flutter build apk --debug`, arquitectura 6/6.

No incluir en esa fase el parámetro `accent` de `AppTheme.dark()` ni ningún otro cambio del Design System.

## Validaciones

- `flutter test`: **730 pasan**.
- `flutter analyze`: sin problemas.
- Build: no ejecutado (no se modificó código de producción).
- Test temporal `zz_sheet_bg_probe_test.dart`: eliminado.
- Git: el único archivo nuevo de esta fase es `docs/PHASE_1_9A_APPCOLORS_AUDIT.md`; no hay cambios de 1.9A en `lib/` ni en `test/` (las modificaciones que aparecen en `git status` son trabajo acumulado de 1.8). Sin commit ni push.
