import 'package:flutter/material.dart';

import '../theme/taki_colors.dart';
import '../theme/taki_elevation.dart';
import '../theme/taki_icon_size.dart';
import '../theme/taki_motion.dart';
import '../theme/taki_radius.dart';
import '../theme/taki_spacing.dart';
import '../theme/taki_typography.dart';
import 'taki_interaction.dart';

/// Tipos de botón de texto (docs/DESIGN_SYSTEM.md §9).
enum TakiButtonVariant {
  /// La acción principal: fondo `primary`. Una por pantalla o sección.
  primary,

  /// Alternativa junto a una primaria: `surfaceElevated` con borde.
  secondary,

  /// Bajo peso (Cancelar, Deshacer, Ver todo): texto `primary`.
  tertiary,

  /// Confirmar algo irreversible: fondo `error`.
  destructive,

  /// Acción destructiva en diálogos: texto `error` sin fondo.
  destructiveTertiary,
}

/// Botón de texto de Taki (docs/DESIGN_SYSTEM.md §9, §17).
///
/// Alto 48, píldora, texto en `label`. Con [icon] (20 px, a 8 del texto) el
/// relleno es 16 a la izquierda y 24 a la derecha; sin icono, 24 a ambos lados.
///
/// Sin [onPressed] queda deshabilitado. Con [loading] no se puede pulsar
/// (evita la doble ejecución), mantiene su tamaño y muestra un spinner en
/// lugar del icono, o del texto si no hay icono; se anuncia como "Cargando".
class TakiButton extends StatelessWidget {
  const TakiButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = TakiButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final TakiButtonVariant variant;
  final IconData? icon;
  final bool loading;

  /// Etiqueta para lectores de pantalla si [label] no basta.
  final String? semanticLabel;

  /// Alto de todos los botones de texto (§9).
  static const double height = 48;

  /// Valor semántico mientras [loading].
  static const String loadingSemanticValue = 'Cargando';

  bool get _filled =>
      variant == TakiButtonVariant.primary ||
      variant == TakiButtonVariant.destructive;

  @override
  Widget build(BuildContext context) {
    // Nodo propio: un botón no se funde con el texto que tenga al lado.
    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null && !loading,
      label: semanticLabel ?? label,
      value: loading ? loadingSemanticValue : null,
      child: TakiPressable(
        onPressed: loading ? null : onPressed,
        builder: (context, states) {
          // Cargando no es deshabilitado: conserva su aspecto normal.
          final disabled = onPressed == null;
          final pressed = states.contains(WidgetState.pressed);
          final colors = _colors(disabled: disabled, pressed: pressed);

          final text = Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TakiTypography.label.copyWith(color: colors.foreground),
          );
          final spinner = SizedBox.square(
            dimension: TakiIconSize.sm.value,
            child: CircularProgressIndicator(color: colors.foreground),
          );
          final icon = this.icon;

          final content = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                loading
                    ? spinner
                    : Icon(
                        icon,
                        size: TakiIconSize.sm.value,
                        color: colors.foreground,
                      ),
                const SizedBox(width: TakiSpacing.sm),
              ],
              if (icon == null && loading)
                // Sin icono, el spinner ocupa el sitio del texto sin cambiar
                // el ancho.
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Visibility.maintain(visible: false, child: text),
                    spinner,
                  ],
                )
              else
                text,
            ],
          );

          return TakiFocusRing(
            visible: states.contains(WidgetState.focused),
            shape: TakiRadius.pill,
            color: _filled
                ? TakiColors.focusRingOnPrimary
                : TakiColors.focusRing,
            child: AnimatedScale(
              scale: pressed && _filled ? TakiMotion.pressedScale : 1,
              duration: TakiMotion.instant,
              curve: TakiMotion.change,
              child: Container(
                height: height,
                padding: EdgeInsets.only(
                  left: icon == null ? TakiSpacing.xl : TakiSpacing.lg,
                  right: TakiSpacing.xl,
                ),
                decoration: ShapeDecoration(
                  shape: TakiRadius.pill.copyWith(
                    side: colors.border == null
                        ? BorderSide.none
                        : BorderSide(
                            color: colors.border!,
                            width: TakiElevation.borderWidth,
                          ),
                  ),
                  color: colors.background,
                ),
                foregroundDecoration: ShapeDecoration(
                  shape: TakiRadius.pill,
                  color: colors.overlay,
                ),
                child: ExcludeSemantics(child: Center(widthFactor: 1, child: content)),
              ),
            ),
          );
        },
      ),
    );
  }

  _ButtonColors _colors({required bool disabled, required bool pressed}) {
    if (disabled) {
      return switch (variant) {
        TakiButtonVariant.primary || TakiButtonVariant.destructive =>
          _ButtonColors(
            background: TakiColors.disabledContainer,
            foreground: TakiColors.disabledContent,
          ),
        TakiButtonVariant.secondary => _ButtonColors(
            background: TakiColors.surfaceElevated,
            foreground: TakiColors.disabledContent,
            border: TakiColors.disabledContainer,
          ),
        _ => _ButtonColors(foreground: TakiColors.disabledContent),
      };
    }

    final overlay = pressed ? TakiColors.pressedOverlay : null;
    return switch (variant) {
      TakiButtonVariant.primary => _ButtonColors(
          background: pressed ? TakiColors.primaryPressed : TakiColors.primary,
          foreground: TakiColors.onPrimary,
        ),
      TakiButtonVariant.secondary => _ButtonColors(
          background: TakiColors.surfaceElevated,
          foreground: TakiColors.textPrimary,
          border: TakiColors.outline,
          overlay: overlay,
        ),
      TakiButtonVariant.tertiary => _ButtonColors(
          foreground: TakiColors.primary,
          overlay: overlay,
        ),
      TakiButtonVariant.destructive => _ButtonColors(
          background: TakiColors.error,
          foreground: TakiColors.onPrimary,
          overlay: overlay,
        ),
      TakiButtonVariant.destructiveTertiary => _ButtonColors(
          foreground: TakiColors.error,
          overlay: overlay,
        ),
    };
  }
}

class _ButtonColors {
  const _ButtonColors({
    required this.foreground,
    this.background,
    this.border,
    this.overlay,
  });

  final Color foreground;
  final Color? background;
  final Color? border;
  final Color? overlay;
}
