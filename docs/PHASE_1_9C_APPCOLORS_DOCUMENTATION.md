# Fase 1.9C — Documentación después de eliminar AppColors

Solo documentación y un comentario de código. Sin cambios de comportamiento, de valores ni de API. Sin commit ni push.

## 1. Documentación actualizada

- `docs/ARCHITECTURE.md`: árbol de carpetas y párrafo de `core/theme`.
- `docs/DESIGN_SYSTEM.md`: inventario de partida, estructura de tokens, inconsistencias I10 e I12, §1.8, tabla de foundations, nota de 1.3, tabla de pasos de migración (§22) y el estado de 1.6A/1.6E.
- `lib/core/theme/taki_colors.dart`: solo el comentario de cabecera.

## 2. ARCHITECTURE.md

- Árbol: `theme/ AppColors (tokens visuales)` → `Tokens Taki: TakiColors, TakiTypography, TakiSpacing, TakiRadius, TakiElevation, TakiMotion, TakiIconSize` (los archivos existen en `lib/core/theme/`).
- Párrafo de `core/theme`: sustituye la descripción de `AppColors` («paleta "Medianoche + ámbar" … acentos alternativos y colores del reproductor») por `core/theme/taki_colors.dart`: `TakiColors` es la paleta semántica "Midnight + Taki Orange" y la **fuente vigente de los tokens de color**, con sus valores en `DESIGN_SYSTEM.md` §1; se nombran los demás archivos de tokens; se indica que `AppColors` (alias temporal) se eliminó en 1.9B.
- Sin capa ni responsabilidad nueva; el resto del documento no cambió.

## 3. DESIGN_SYSTEM.md

Antes de editar se contrastaron con `TakiColors` todos los valores hexadecimales de la tabla de §1 (background `#0E1016`, surface `#161920`, surfaceElevated `#1E222B`, surfaceHighest `#272B36`, textos, `primary #FF8A3D`, contenedores, divider `#23272F`, outline `#2E3340`, estados, degradado de marca): **coinciden**, así que §1 no se tocó. Cambios:

| Lugar | Cambio |
|---|---|
| Inventario de partida (fila `AppColors`) | Marcada «eliminado en 1.9B» y aclarado que sus valores (`#111318`, `#F5A524`…) son los de entonces, sustituidos por `TakiColors` (§1) |
| «Qué se reutiliza» / estructura de tokens | Habla de los tokens de `core/theme` (hoy `TakiColors` y demás) y cita `AppColors` como antecedente eliminado |
| I10 (evidencia `app_colors.dart`) | Añadido «(eliminado en 1.9B)» |
| I12 | «Parcialmente resuelta en 1.9B»: `accentCoral/Blue/Mint` se eliminaron con `AppColors`; el parámetro `accent` de `AppTheme.dark()` **sigue pendiente** (no se tocó) |
| §1.8 «Tokens actuales que se retiran» | Título marcado como histórico y párrafo **Estado** (retirados en 1.9B; `miniProgressTrack`/`seekTrack` eran alias de `divider`; `artworkShadow` es `TakiElevation.artworkShadow`) |
| Tabla de foundations (filas `TakiColors` y `TakiElevation`) | «Parte de»: `AppColors` / `AppColors.artworkShadow` marcados «(eliminado en 1.9B)» |
| Nota «Implementado en Fase 1.3» | «entonces la UI aún usaba `AppColors`, eliminado en 1.9B» |
| §22, paso 1 Foundations | «`AppColors` quedó como alias temporal y se eliminó en la Fase 1.9B» |
| Estado de 1.6A | `AppColors` «fue un alias temporal»; `TakiColors` es la fuente vigente |
| Estado de 1.6E | `AppColors.miniProgressTrack` «quedaba sin uso» (eliminado en 1.9B) |

Se mantienen como referencia vigente: dark-first, fondos Midnight, Taki Orange como foco/acción y superficies por niveles de luminosidad. No se inventó ningún color ni se reinterpretó ningún token. La observación I9 («ámbar» en Reproduciendo) es de la lista de inconsistencias previa a la migración y no se modificó.

## 4. Comentarios de código

- `lib/core/theme/taki_colors.dart:9`: «Convive con `AppColors` hasta que la migración (§22) lo sustituya.» → «Es la fuente vigente de los tokens de color del Design System; `AppTheme` los compone en el `ThemeData`.» Verificado con `git diff`: es la única línea de código fuente que cambia (valores, constantes, nombres, orden y API intactos).

## 5. Referencias restantes

Búsqueda sensible a mayúsculas de `AppColors` / `app_colors` en `lib/`, `test/` y `docs/`:

| Referencia | Ubicación | Tipo | Acción |
|---|---|---|---|
| `AppColors` | `lib/` | — | **Cero** referencias |
| `AppColors` | `test/` | — | **Cero** referencias |
| «AppColors, el alias temporal anterior, se eliminó en la Fase 1.9B» | `ARCHITECTURE.md:273` | Documentación vigente (nota de estado explícita) | Conservada: indica la eliminación |
| Fila del inventario de partida | `DESIGN_SYSTEM.md:60` | Histórico, marcado «eliminado en 1.9B» | Conservada |
| Nota de estructura de tokens | `DESIGN_SYSTEM.md:83` | Vigente (antecedente) | Conservada |
| I10, I12 (evidencias) | `DESIGN_SYSTEM.md:109, 111` | Histórico, marcado | Conservadas |
| §1.8 y su **Estado** | `DESIGN_SYSTEM.md:265` | Histórico, marcado | Conservada |
| Tabla de foundations, nota de 1.3 | `DESIGN_SYSTEM.md:971, 975, 979` | Histórico, marcado | Conservadas |
| §22 paso 1 | `DESIGN_SYSTEM.md:1080` | Histórico (plan), marcado «se eliminó en 1.9B» | Conservada |
| Estados de 1.6A y 1.6E | `DESIGN_SYSTEM.md:1097, 1218-1219` | Histórico, marcado | Conservadas |
| Informes de fase | `PHASE_1_8M/N/O`, `PHASE_1_9A`, `PHASE_1_9B` | Histórico | Intactos |

Las 13 referencias de `DESIGN_SYSTEM.md` y 1 de `ARCHITECTURE.md` son históricas o notas de estado explícitas; ninguna presenta a `AppColors` como vigente.

## 6. Estado final de TakiColors

Sin cambios de valores, constantes, nombres, API, orden ni estructura. Es la única fuente de tokens de color; su documentación de cabecera lo dice y `DESIGN_SYSTEM.md` §1 coincide con sus valores. `AppTheme.dark()` (con su parámetro `accent`) no se modificó.

## 7. Histórico conservado

`docs/PHASE_1_8*`, `PHASE_1_9A_*` y `PHASE_1_9B_*` no se tocaron. En `DESIGN_SYSTEM.md` se conservan las referencias históricas (registro de fases, plan de migración, inconsistencias) y se marcan expresamente como eliminadas o históricas.

## 8. Validaciones

- `flutter test`: **729 pasan**.
- `flutter analyze`: sin problemas.
- Build: no ejecutado (el único cambio en `lib/` es un comentario).
- `git diff` de `lib/`: solo el comentario de `taki_colors.dart` (más el trabajo acumulado anterior).
- Git: cambios propios de 1.9C (sin commit): `M docs/ARCHITECTURE.md`, `M docs/DESIGN_SYSTEM.md`, `M lib/core/theme/taki_colors.dart` (solo comentario), `?? docs/PHASE_1_9C_APPCOLORS_DOCUMENTATION.md`. Sin commit ni push.
