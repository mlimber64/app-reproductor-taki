import 'package:flutter/material.dart';

import '../theme/taki_colors.dart';
import 'taki_state_view.dart';

export 'taki_state_view.dart' show TakiStateAction;

/// Tipos de [TakiErrorState] (docs/DESIGN_SYSTEM.md §15).
enum TakiErrorStateKind {
  /// Algo falló: icono en `error` sobre `errorContainer`.
  error(Icons.error_outline_rounded),

  /// Falta un permiso: no es un fallo sino un paso pendiente; icono neutro
  /// sobre `surface`.
  permission(Icons.lock_outline_rounded);

  const TakiErrorStateKind(this.defaultIcon);

  final IconData defaultIcon;
}

/// Estado de error o de permiso pendiente, a pantalla completa
/// (docs/DESIGN_SYSTEM.md §15).
///
/// Misma estructura que `TakiEmptyState` con otro tono: un error se reconoce
/// por su icono (no solo por el color) y nunca parece un vacío. Solo presenta
/// y avisa por callbacks; la recuperación la decide quien lo usa.
class TakiErrorState extends StatelessWidget {
  const TakiErrorState({
    super.key,
    required this.title,
    required this.message,
    this.kind = TakiErrorStateKind.error,
    this.icon,
    this.action,
    this.secondaryAction,
  });

  final String title;
  final String message;
  final TakiErrorStateKind kind;

  /// Por defecto, el del [kind].
  final IconData? icon;

  /// Principal: "Reintentar", "Permitir acceso", "Abrir ajustes".
  final TakiStateAction? action;

  /// Terciaria opcional (p. ej. "Ver detalles").
  final TakiStateAction? secondaryAction;

  @override
  Widget build(BuildContext context) {
    final isError = kind == TakiErrorStateKind.error;

    return TakiStateView(
      visual: TakiStateIcon(
        icon: icon ?? kind.defaultIcon,
        color: isError ? TakiColors.error : TakiColors.iconPrimary,
        circle: isError ? TakiColors.errorContainer : TakiColors.surface,
      ),
      title: title,
      message: message,
      centered: true,
      action: action,
      secondaryAction: secondaryAction,
    );
  }
}
