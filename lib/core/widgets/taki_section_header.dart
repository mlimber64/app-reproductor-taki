import 'package:flutter/material.dart';

import '../theme/taki_colors.dart';
import '../theme/taki_spacing.dart';
import '../theme/taki_typography.dart';
import 'taki_button.dart';
import 'taki_icon_button.dart';

/// Variantes de [TakiSectionHeader] (docs/DESIGN_SYSTEM.md §13).
enum TakiSectionHeaderVariant {
  /// Agrupa dentro de una lista ("TUS PLAYLISTS"): `eyebrow` en MAYÚSCULAS,
  /// `textMuted`.
  group,

  /// Sección de contenido de una página: `titleLarge`, `textPrimary`.
  section,
}

/// Acción opcional de un [TakiSectionHeader]: un botón terciario de texto
/// ("Ver todo") o un botón de icono.
class TakiSectionHeaderAction {
  /// Botón terciario. [semanticLabel] solo si [label] no basta.
  const TakiSectionHeaderAction.text({
    required String this.label,
    required this.onPressed,
    this.semanticLabel,
  }) : icon = null;

  /// Botón de icono; [semanticLabel] es obligatorio.
  const TakiSectionHeaderAction.icon({
    required IconData this.icon,
    required String this.semanticLabel,
    required this.onPressed,
  }) : label = null;

  final String? label;
  final IconData? icon;
  final String? semanticLabel;
  final VoidCallback? onPressed;
}

/// Encabezado de un grupo o sección de contenido (docs/DESIGN_SYSTEM.md §13).
///
/// Espaciado: 16 a los lados; 24 encima (8 si es el primero de la pantalla,
/// [isFirst]); 8 debajo (grupo) o 12 (sección). La acción se alinea con la
/// línea base del título. Se anuncia como encabezado.
class TakiSectionHeader extends StatelessWidget {
  const TakiSectionHeader({
    super.key,
    required this.title,
    this.variant = TakiSectionHeaderVariant.section,
    this.subtitle,
    this.action,
    this.isFirst = false,
  }) : assert(
          subtitle == null || variant == TakiSectionHeaderVariant.section,
          'El subtítulo solo existe en la variante sección',
        );

  final String title;
  final TakiSectionHeaderVariant variant;
  final String? subtitle;
  final TakiSectionHeaderAction? action;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final isGroup = variant == TakiSectionHeaderVariant.group;
    final subtitle = this.subtitle;

    final heading = Semantics(
      container: true,
      header: true,
      label: title,
      child: ExcludeSemantics(
        child: Text(
          // Un TextStyle no cambia el texto: las MAYÚSCULAS se aplican aquí.
          isGroup ? title.toUpperCase() : title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: isGroup
              ? TakiTypography.eyebrow.copyWith(color: TakiColors.textMuted)
              : TakiTypography.titleLarge
                  .copyWith(color: TakiColors.textPrimary),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        TakiSpacing.pageGutter,
        isFirst ? TakiSpacing.sm : TakiSpacing.sectionGap,
        TakiSpacing.pageGutter,
        isGroup ? TakiSpacing.sm : TakiSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                heading,
                if (subtitle != null) ...[
                  const SizedBox(height: TakiSpacing.xxs),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TakiTypography.trackSubtitle
                        .copyWith(color: TakiColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          if (action case final action?) _action(action),
        ],
      ),
    );
  }

  Widget _action(TakiSectionHeaderAction action) {
    final icon = action.icon;
    if (icon != null) {
      return TakiIconButton(
        icon: icon,
        semanticLabel: action.semanticLabel!,
        onPressed: action.onPressed,
        variant: TakiIconButtonVariant.subtle,
      );
    }
    return TakiButton(
      label: action.label!,
      semanticLabel: action.semanticLabel,
      onPressed: action.onPressed,
      variant: TakiButtonVariant.tertiary,
    );
  }
}
