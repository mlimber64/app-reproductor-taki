import 'package:flutter/material.dart';

import '../theme/taki_colors.dart';

// Piezas de interacción compartidas por los botones de Taki
// (docs/DESIGN_SYSTEM.md §9, §17, §19). No son componentes por sí mismas.

/// Medidas de interacción documentadas.
abstract final class TakiInteraction {
  /// Área táctil mínima de todo lo pulsable (§19).
  static const double minTouchTarget = 48;

  /// Anillo de foco: 2 px de grosor, a 2 px del componente (§17).
  static const double focusRingWidth = 2;
  static const double focusRingGap = 2;
}

/// Estados de un componente pulsable, para que su `builder` elija colores.
///
/// Gestiona pulsado, foco de teclado (solo cuando el foco debe verse),
/// activación con Enter/Espacio y la respuesta táctil del sistema. Sin
/// [onPressed] el componente queda deshabilitado. [onLongPress] es opcional
/// (menú de acciones de una fila).
class TakiPressable extends StatefulWidget {
  const TakiPressable({
    super.key,
    required this.onPressed,
    required this.builder,
    this.onLongPress,
  });

  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final Widget Function(BuildContext context, Set<WidgetState> states) builder;

  @override
  State<TakiPressable> createState() => _TakiPressableState();
}

class _TakiPressableState extends State<TakiPressable> {
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onPressed != null;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  void _activate() {
    final onPressed = widget.onPressed;
    if (onPressed == null) return;
    Feedback.forTap(context);
    onPressed();
  }

  @override
  void didUpdateWidget(TakiPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled) _pressed = false;
  }

  @override
  Widget build(BuildContext context) {
    final states = <WidgetState>{
      if (!_enabled) WidgetState.disabled,
      if (_enabled && _pressed) WidgetState.pressed,
      if (_enabled && _focused) WidgetState.focused,
    };

    return FocusableActionDetector(
      enabled: _enabled,
      mouseCursor:
          _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => _activate(),
        ),
      },
      // La acción de tap se expone a TalkBack aquí; la etiqueta y el resto de
      // la semántica los pone cada componente.
      child: Semantics(
        onTap: _enabled ? _activate : null,
        onLongPress: _enabled ? widget.onLongPress : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTapDown: _enabled ? (_) => _setPressed(true) : null,
          onTapUp: _enabled ? (_) => _setPressed(false) : null,
          onTapCancel: _enabled ? () => _setPressed(false) : null,
          onTap: _enabled ? _activate : null,
          onLongPress: _enabled ? widget.onLongPress : null,
          child: widget.builder(context, states),
        ),
      ),
    );
  }
}

/// Dibuja el anillo de foco alrededor de [child], separado por
/// [TakiInteraction.focusRingGap], sin cambiar su tamaño.
///
/// Con [inset] el anillo va por dentro, a la misma distancia del borde: para
/// filas a ancho completo, donde uno exterior quedaría cortado por la
/// pantalla o tapado por las filas vecinas.
class TakiFocusRing extends StatelessWidget {
  const TakiFocusRing({
    super.key,
    required this.visible,
    required this.shape,
    required this.child,
    this.color = TakiColors.focusRing,
    this.inset = false,
  });

  final bool visible;

  /// Forma del componente (círculo o píldora); el anillo la sigue.
  final OutlinedBorder shape;
  final Color color;
  final bool inset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final outset = inset
        ? -TakiInteraction.focusRingGap
        : TakiInteraction.focusRingGap + TakiInteraction.focusRingWidth;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (visible)
          Positioned(
            left: -outset,
            top: -outset,
            right: -outset,
            bottom: -outset,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: shape.copyWith(
                    side: BorderSide(
                      color: color,
                      width: TakiInteraction.focusRingWidth,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
