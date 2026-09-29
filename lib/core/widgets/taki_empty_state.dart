import 'package:flutter/material.dart';

import '../theme/taki_colors.dart';
import 'taki_button.dart';
import 'taki_state_view.dart';

export 'taki_state_view.dart' show TakiStateAction;

/// Tipos de estado vacío (docs/DESIGN_SYSTEM.md §14).
enum TakiEmptyStateKind {
  /// Nunca hubo contenido: centrado, icono en círculo, acción que enseña qué
  /// hacer (botón primario).
  firstUse,

  /// Un filtro o búsqueda no encuentra nada: arriba, solo el icono, acción
  /// opcional ligera (botón terciario, p. ej. "Limpiar búsqueda").
  noResults,
}

/// Estado vacío de Taki: no hay contenido y no es un error
/// (docs/DESIGN_SYSTEM.md §14).
///
/// Misma estructura para todos los casos (biblioteca, favoritos, playlists,
/// búsqueda, contenido online) con contenido propio: [icon], [title],
/// [description] y acciones. En primer uso, [illustration] puede sustituir al
/// icono (p. ej. una ilustración con el degradado de marca).
class TakiEmptyState extends StatelessWidget {
  const TakiEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.action,
    this.secondaryAction,
    this.kind = TakiEmptyStateKind.firstUse,
    this.illustration,
  }) : assert(
          illustration == null || kind == TakiEmptyStateKind.firstUse,
          'La ilustración es solo para estados de primer uso',
        );

  final IconData icon;
  final String title;
  final String? description;
  final TakiStateAction? action;
  final TakiStateAction? secondaryAction;
  final TakiEmptyStateKind kind;
  final Widget? illustration;

  @override
  Widget build(BuildContext context) {
    final firstUse = kind == TakiEmptyStateKind.firstUse;

    return TakiStateView(
      visual: illustration ??
          TakiStateIcon(
            icon: icon,
            color: TakiColors.iconSecondary,
            circle: firstUse ? TakiColors.surface : null,
          ),
      title: title,
      message: description,
      centered: firstUse,
      action: action,
      actionVariant:
          firstUse ? TakiButtonVariant.primary : TakiButtonVariant.tertiary,
      secondaryAction: secondaryAction,
    );
  }
}
