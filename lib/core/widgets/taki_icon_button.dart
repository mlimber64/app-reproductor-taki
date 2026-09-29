import 'package:flutter/material.dart';

import '../theme/taki_colors.dart';
import '../theme/taki_icon_size.dart';
import '../theme/taki_motion.dart';
import 'taki_interaction.dart';

/// Aspecto de un [TakiIconButton] (docs/DESIGN_SYSTEM.md §9).
enum TakiIconButtonVariant {
  /// Sin contenedor, icono `iconPrimary`: acciones principales.
  standard,

  /// Sin contenedor, icono `iconSecondary`: acciones secundarias de fila (⋯).
  subtle,

  /// Círculo `surfaceElevated`, icono `iconPrimary` (cerrar, más).
  tonal,

  /// Círculo `textPrimary`, icono `onTextPrimary` (play del mini player).
  inverse,
}

/// Botón de icono de Taki (docs/DESIGN_SYSTEM.md §6, §9, §17).
///
/// - Área táctil de 48; las variantes con contenedor dibujan un círculo de
///   [containerSize] dentro de ella.
/// - [semanticLabel] es obligatorio (un icono no se describe solo) y es
///   también el tooltip, salvo que se indique otro en [tooltip].
/// - Toggle: con [selected] no nulo se anuncia como interruptor. Activo, el
///   icono pasa a `primary` **y** a [selectedIcon] (no solo color).
/// - Sin [onPressed] queda deshabilitado: icono al 38 %, contenedor al 12 %.
class TakiIconButton extends StatelessWidget {
  const TakiIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.variant = TakiIconButtonVariant.standard,
    this.iconSize = TakiIconSize.md,
    this.selected,
    this.selectedIcon,
    this.tooltip,
  })  : assert(
          selected == null || variant != TakiIconButtonVariant.inverse,
          'El naranja activo no contrasta sobre el círculo textPrimary',
        ),
        assert(
          (variant != TakiIconButtonVariant.tonal &&
                  variant != TakiIconButtonVariant.inverse) ||
              iconSize == TakiIconSize.sm ||
              iconSize == TakiIconSize.md,
          'En un círculo de 40 solo caben iconos sm o md',
        );

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final TakiIconButtonVariant variant;
  final TakiIconSize iconSize;

  /// `null`: no es un toggle. `true`/`false`: toggle encendido/apagado.
  final bool? selected;

  /// Icono cuando [selected] es `true` (variante `_on` o rellena).
  final IconData? selectedIcon;

  /// Texto del tooltip; por defecto, [semanticLabel].
  final String? tooltip;

  /// Diámetro del círculo visible dentro del área táctil de 48 (§9).
  static const double containerSize = 40;

  @override
  Widget build(BuildContext context) {
    final isOn = selected ?? false;
    final enabled = onPressed != null;

    // Nodo propio: un botón no se funde con el texto que tenga al lado.
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      toggled: selected,
      label: semanticLabel,
      child: Tooltip(
        message: tooltip ?? semanticLabel,
        excludeFromSemantics: true,
        child: TakiPressable(
          onPressed: onPressed,
          builder: (context, states) {
            final disabled = states.contains(WidgetState.disabled);
            final pressed = states.contains(WidgetState.pressed);

            final container = switch (variant) {
              TakiIconButtonVariant.tonal => TakiColors.surfaceElevated,
              TakiIconButtonVariant.inverse => TakiColors.textPrimary,
              _ => null,
            };
            final foreground = isOn
                ? TakiColors.active
                : switch (variant) {
                    TakiIconButtonVariant.subtle => TakiColors.iconSecondary,
                    TakiIconButtonVariant.inverse => TakiColors.onTextPrimary,
                    _ => TakiColors.iconPrimary,
                  };

            return SizedBox.square(
              dimension: TakiInteraction.minTouchTarget,
              child: Center(
                child: TakiFocusRing(
                  visible: states.contains(WidgetState.focused),
                  shape: const CircleBorder(),
                  child: Container(
                    width: containerSize,
                    height: containerSize,
                    decoration: ShapeDecoration(
                      shape: const CircleBorder(),
                      color: container == null
                          ? null
                          : disabled
                              ? TakiColors.disabledContainer
                              : container,
                    ),
                    foregroundDecoration: ShapeDecoration(
                      shape: const CircleBorder(),
                      color: pressed ? TakiColors.pressedOverlay : null,
                    ),
                    child: ExcludeSemantics(
                      child: AnimatedSwitcher(
                        duration: TakiMotion.short,
                        switchInCurve: TakiMotion.change,
                        switchOutCurve: TakiMotion.change,
                        child: Icon(
                          isOn ? (selectedIcon ?? icon) : icon,
                          key: ValueKey(isOn),
                          size: iconSize.value,
                          color: disabled
                              ? foreground.withValues(
                                  alpha: TakiColors.disabledContentOpacity,
                                )
                              : foreground,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
