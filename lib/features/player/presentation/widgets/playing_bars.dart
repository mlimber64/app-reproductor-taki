import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Tres barras tipo ecualizador. Se animan solo si [animate] es `true`; si no,
/// quedan quietas a media altura.
class PlayingBars extends StatefulWidget {
  const PlayingBars({super.key, required this.animate, this.size = 18});

  final bool animate;
  final double size;

  @override
  State<PlayingBars> createState() => _PlayingBarsState();
}

class _PlayingBarsState extends State<PlayingBars>
    with SingleTickerProviderStateMixin {
  static const List<double> _phases = [0, 0.35, 0.7];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(PlayingBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate == oldWidget.animate) return;
    if (widget.animate) {
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

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final barWidth = widget.size / 5;

    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final phase in _phases)
                Container(
                  width: barWidth,
                  height: widget.size * _heightFactor(phase),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(barWidth / 2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  double _heightFactor(double phase) {
    if (!widget.animate) return 0.5;
    final t = (_controller.value + phase) * 2 * math.pi;
    return 0.3 + 0.7 * (0.5 + 0.5 * math.sin(t));
  }
}
