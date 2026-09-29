import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/taki_colors.dart';
import '../theme/taki_icon_size.dart';
import '../theme/taki_motion.dart';

/// Relación de un elemento (canción, playlist) con lo que está sonando.
enum TakiNowPlaying {
  /// No es lo que suena.
  none,

  /// Es lo que suena: indicador en movimiento.
  playing,

  /// Es lo que suena, en pausa: indicador quieto.
  paused;

  bool get isCurrent => this != none;
}

/// Indicador "sonando" de Taki: tres barras tipo ecualizador
/// (docs/DESIGN_SYSTEM.md §8, §12, §18).
///
/// Se mueven solo mientras [animate] (sonando) y quedan quietas a media altura
/// en pausa o si el sistema pide reducir animaciones: la barra sigue marcando
/// la canción aunque no se mueva. Es decorativo para la accesibilidad: quien lo
/// muestra anuncia "Reproduciendo".
class TakiPlayingIndicator extends StatefulWidget {
  const TakiPlayingIndicator({
    super.key,
    required this.animate,
    this.size = TakiIconSize.xs,
  });

  final bool animate;
  final TakiIconSize size;

  @override
  State<TakiPlayingIndicator> createState() => _TakiPlayingIndicatorState();
}

class _TakiPlayingIndicatorState extends State<TakiPlayingIndicator>
    with SingleTickerProviderStateMixin {
  /// Desfase de cada barra dentro del ciclo.
  static const List<double> _phases = [0, 0.35, 0.7];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TakiMotion.playingLoop,
  );

  bool _moving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(TakiPlayingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final moving = widget.animate && !MediaQuery.disableAnimationsOf(context);
    if (moving == _moving) return;
    _moving = moving;
    if (moving) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _heightFactor(double phase) {
    if (!_moving) return 0.5;
    final t = (_controller.value + phase) * 2 * math.pi;
    return 0.3 + 0.7 * (0.5 + 0.5 * math.sin(t));
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size.value;
    final barWidth = size / 5;

    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final phase in _phases)
                SizedBox(
                  width: barWidth,
                  height: size * _heightFactor(phase),
                  child: const DecoratedBox(
                    decoration: ShapeDecoration(
                      shape: StadiumBorder(),
                      color: TakiColors.active,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
