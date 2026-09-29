import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/taki_colors.dart';
import '../theme/taki_typography.dart';
import '../utils/duration_format.dart';
import 'taki_interaction.dart';

/// Barra de progreso de la canción, con tiempos debajo
/// (docs/DESIGN_SYSTEM.md §11). Solo presentación: recibe posición y duración
/// y avisa del seek por [onSeek]; no sabe nada del reproductor.
///
/// - Pista de 4 px (`divider` → `primary`) y pulgar de 16 en `textPrimary`
///   que crece a 20 mientras se arrastra.
/// - Durante el arrastre los tiempos siguen al dedo; [onSeek] se llama una
///   sola vez, al soltar (también con las acciones de accesibilidad).
/// - Valores fuera de rango se normalizan: posición negativa = 0; mayor que
///   la duración = la duración. Con duración 0 o sin [onSeek], o con
///   [enabled] `false`, no se puede mover.
class TakiProgressBar extends StatefulWidget {
  const TakiProgressBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.enabled = true,
  });

  final Duration position;
  final Duration duration;
  final ValueChanged<Duration>? onSeek;
  final bool enabled;

  /// Etiqueta para el lector de pantalla.
  static const String semanticLabel = 'Progreso de la canción';

  /// Grosor de la pista (§11).
  static const double trackHeight = 4;

  /// Radio del pulgar en reposo y mientras se arrastra (16 y 20 px, §11).
  static const double thumbRadius = 8;
  static const double draggingThumbRadius = 10;

  @override
  State<TakiProgressBar> createState() => _TakiProgressBarState();
}

class _TakiProgressBarState extends State<TakiProgressBar> {
  /// Posición bajo el dedo mientras se arrastra (ms).
  double? _dragMs;

  int get _durationMs => math.max(widget.duration.inMilliseconds, 0);

  bool get _interactive =>
      widget.enabled && widget.onSeek != null && _durationMs > 0;

  void _end(double valueMs) {
    setState(() => _dragMs = null);
    widget.onSeek?.call(Duration(milliseconds: valueMs.round()));
  }

  @override
  Widget build(BuildContext context) {
    // Con duración 0 el Slider necesita un máximo > 0; queda en 0 y quieto.
    final maxMs = math.max(_durationMs, 1).toDouble();
    final valueMs = _durationMs == 0
        ? 0.0
        : (_dragMs ?? widget.position.inMilliseconds.toDouble()).clamp(
            0.0,
            maxMs,
          );
    final shownPosition = Duration(
      milliseconds: math.min(valueMs.round(), _durationMs),
    );
    final duration = Duration(milliseconds: _durationMs);
    final timeStyle = TakiTypography.caption.copyWith(
      color: TakiColors.textSecondary,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: TakiInteraction.minTouchTarget,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: TakiProgressBar.trackHeight,
              activeTrackColor: TakiColors.primary,
              inactiveTrackColor: TakiColors.divider,
              thumbColor: TakiColors.textPrimary,
              disabledActiveTrackColor: TakiColors.disabledContent,
              disabledInactiveTrackColor: TakiColors.divider,
              disabledThumbColor: TakiColors.disabledContent,
              overlayColor: TakiColors.pressedOverlay,
              trackShape: const RoundedRectSliderTrackShape(),
              thumbShape: RoundSliderThumbShape(
                enabledThumbRadius: _dragMs == null
                    ? TakiProgressBar.thumbRadius
                    : TakiProgressBar.draggingThumbRadius,
                disabledThumbRadius: TakiProgressBar.thumbRadius,
                elevation: 0,
                pressedElevation: 0,
              ),
              overlayShape: const RoundSliderOverlayShape(
                overlayRadius: TakiInteraction.minTouchTarget / 2,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: TakiProgressBar.thumbRadius,
              ),
            ),
            // Un solo nodo: etiqueta, valor ("1:05 de 3:20") y acciones.
            child: MergeSemantics(
              child: Semantics(
                label: TakiProgressBar.semanticLabel,
                child: Slider(
                  value: valueMs,
                  max: maxMs,
                  semanticFormatterCallback: (value) =>
                      '${formatTrackDuration(Duration(milliseconds: value.round()))}'
                      ' de ${formatTrackDuration(duration)}',
                  onChangeStart: _interactive
                      ? (value) => setState(() => _dragMs = value)
                      : null,
                  onChanged: _interactive
                      ? (value) => setState(() => _dragMs = value)
                      : null,
                  onChangeEnd: _interactive ? _end : null,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TakiProgressBar.thumbRadius,
          ),
          child: ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(formatTrackDuration(shownPosition), style: timeStyle),
                Text(formatTrackDuration(duration), style: timeStyle),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
