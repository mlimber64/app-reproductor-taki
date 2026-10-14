import 'package:flutter/material.dart';

import '../theme/taki_colors.dart';
import '../theme/taki_icon_size.dart';
import '../theme/taki_spacing.dart';
import '../theme/taki_typography.dart';
import 'taki_icon_button.dart';
import 'taki_interaction.dart';

/// Campo de búsqueda de Taki (docs/DESIGN_SYSTEM.md §9b).
///
/// Solo presentación: no busca ni hace debounce; avisa de lo que se escribe por
/// [onChanged] y [onSubmitted]. Quien lo usa es dueño de [controller] (y de
/// [focusNode], si lo pasa).
///
/// - Píldora (`radiusFull`) de alto mínimo 48 sobre `surface`, icono de lupa
///   a la izquierda y texto en `body`.
/// - Foco: anillo de 2 px en `primary` (el ancho es siempre el mismo, así que
///   la fila no se mueve al enfocar).
/// - Con texto y habilitado aparece el botón «Borrar búsqueda» (48 táctil):
///   vacía el campo, avisa con `onChanged('')` y deja el foco en el campo.
/// - [enabled] `false`: contenido al 38 %, sin botón de borrar.
class TakiSearchField extends StatefulWidget {
  const TakiSearchField({
    super.key,
    required this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.hintText = 'Buscar',
    this.semanticLabel,
    this.enabled = true,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String hintText;

  /// Etiqueta para lectores de pantalla; por defecto, [hintText].
  final String? semanticLabel;
  final bool enabled;

  /// Alto mínimo de la píldora (área táctil, §6).
  static const double minHeight = 48;

  static const String clearLabel = 'Borrar búsqueda';

  @override
  State<TakiSearchField> createState() => _TakiSearchFieldState();
}

class _TakiSearchFieldState extends State<TakiSearchField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(TakiSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  // Muestra u oculta «Borrar» según haya texto.
  void _onTextChanged() => setState(() {});

  void _clear() {
    widget.controller.clear();
    widget.onChanged?.call('');
    widget.focusNode?.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final showClear = enabled && widget.controller.text.isNotEmpty;

    return Semantics(
      container: true,
      label: widget.semanticLabel ?? widget.hintText,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: Opacity(
          opacity: enabled ? 1 : TakiColors.disabledContentOpacity,
          child: Container(
            constraints:
                const BoxConstraints(minHeight: TakiSearchField.minHeight),
            padding: const EdgeInsets.only(left: TakiSpacing.lg),
            decoration: ShapeDecoration(
              color: TakiColors.surface,
              shape: StadiumBorder(
                side: BorderSide(
                  color: _focused ? TakiColors.focusRing : TakiColors.surface,
                  width: TakiInteraction.focusRingWidth,
                ),
              ),
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.search_rounded,
                    size: TakiIconSize.md.value,
                    color: TakiColors.iconSecondary,
                  ),
                ),
                const SizedBox(width: TakiSpacing.md),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    enabled: enabled,
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                    textInputAction: TextInputAction.search,
                    style: TakiTypography.body
                        .copyWith(color: TakiColors.textPrimary),
                    cursorColor: TakiColors.primary,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: widget.hintText,
                      hintStyle: TakiTypography.body
                          .copyWith(color: TakiColors.textMuted),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: TakiSpacing.md,
                      ),
                    ),
                  ),
                ),
                if (showClear)
                  TakiIconButton(
                    icon: Icons.close_rounded,
                    semanticLabel: TakiSearchField.clearLabel,
                    variant: TakiIconButtonVariant.subtle,
                    onPressed: _clear,
                  )
                else
                  const SizedBox(width: TakiSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
