import 'package:flutter/material.dart';

import '../theme/taki_colors.dart';
import '../theme/taki_icon_size.dart';
import '../theme/taki_spacing.dart';
import '../theme/taki_typography.dart';
import 'taki_button.dart';

// Estructura común de TakiEmptyState y TakiErrorState
// (docs/DESIGN_SYSTEM.md §14, §15). No se usa directamente en pantallas.

/// Acción de un estado vacío o de error.
class TakiStateAction {
  const TakiStateAction({
    required this.label,
    required this.onPressed,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? semanticLabel;
}

/// Medidas documentadas de los estados vacío y de error.
abstract final class TakiStateMetrics {
  /// Círculo detrás del icono (§14).
  static const double iconCircle = 80;

  /// Ancho máximo de la descripción (§14).
  static const double maxTextWidth = 320;
}

/// Visual, título, texto y acciones, con el espaciado de §14: relleno 32;
/// visual → 16 → título → 8 → texto → 24 → acción → 12 → acción secundaria.
///
/// [centered]: centrado en el espacio disponible (primer uso, errores); si
/// no, arriba a 48 (sin resultados).
class TakiStateView extends StatelessWidget {
  const TakiStateView({
    super.key,
    required this.visual,
    required this.title,
    required this.centered,
    this.message,
    this.action,
    this.actionVariant = TakiButtonVariant.primary,
    this.secondaryAction,
  });

  final Widget visual;
  final String title;
  final String? message;
  final bool centered;
  final TakiStateAction? action;
  final TakiButtonVariant actionVariant;

  /// Siempre terciaria, debajo de la principal.
  final TakiStateAction? secondaryAction;

  @override
  Widget build(BuildContext context) {
    final message = this.message;

    final column = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: TakiStateMetrics.maxTextWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          visual,
          const SizedBox(height: TakiSpacing.lg),
          Semantics(
            container: true,
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TakiTypography.titleLarge
                  .copyWith(color: TakiColors.textPrimary),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: TakiSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TakiTypography.body.copyWith(color: TakiColors.textSecondary),
            ),
          ],
          if (action case final action?) ...[
            const SizedBox(height: TakiSpacing.xl),
            _button(action, actionVariant),
          ],
          if (secondaryAction case final secondary?) ...[
            const SizedBox(height: TakiSpacing.md),
            _button(secondary, TakiButtonVariant.tertiary),
          ],
        ],
      ),
    );

    final padding = EdgeInsets.fromLTRB(
      TakiSpacing.xxl,
      centered ? TakiSpacing.xxl : TakiSpacing.xxxl,
      TakiSpacing.xxl,
      TakiSpacing.xxl,
    );

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
            minWidth: constraints.hasBoundedWidth ? constraints.maxWidth : 0,
          ),
          child: Align(
            alignment: centered ? Alignment.center : Alignment.topCenter,
            child: Padding(padding: padding, child: column),
          ),
        ),
      ),
    );
  }

  static Widget _button(TakiStateAction action, TakiButtonVariant variant) {
    return TakiButton(
      label: action.label,
      semanticLabel: action.semanticLabel,
      onPressed: action.onPressed,
      variant: variant,
    );
  }
}

/// Icono de estado dentro de un círculo de [TakiStateMetrics.iconCircle], o
/// solo el icono si [circle] es `null` (sin resultados).
class TakiStateIcon extends StatelessWidget {
  const TakiStateIcon({
    super.key,
    required this.icon,
    required this.color,
    this.circle,
  });

  final IconData icon;
  final Color color;
  final Color? circle;

  @override
  Widget build(BuildContext context) {
    final glyph = Icon(icon, size: TakiIconSize.xl.value, color: color);
    final circle = this.circle;
    if (circle == null) return ExcludeSemantics(child: glyph);

    return ExcludeSemantics(
      child: Container(
        width: TakiStateMetrics.iconCircle,
        height: TakiStateMetrics.iconCircle,
        decoration: ShapeDecoration(shape: const CircleBorder(), color: circle),
        alignment: Alignment.center,
        child: glyph,
      ),
    );
  }
}
