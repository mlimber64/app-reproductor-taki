import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../utils/dominant_color.dart';

/// Gives its [builder] the dominant color of [image], or `null` while it is
/// not known (loading, no cover, or an image with no usable color).
///
/// It only reads the pixels of an image that is already being shown; it never
/// fetches anything by itself. The color is computed once per image.
class ArtworkTint extends StatefulWidget {
  const ArtworkTint({
    super.key,
    required this.image,
    required this.builder,
    this.onTint,
  });

  final ImageProvider? image;

  /// Told every time the color changes (including back to `null`), outside of
  /// the build phase, so it can feed state held elsewhere.
  final ValueChanged<Color?>? onTint;
  final Widget Function(BuildContext context, Color? tint) builder;

  @override
  State<ArtworkTint> createState() => _ArtworkTintState();
}

class _ArtworkTintState extends State<ArtworkTint> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Color? _tint;
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscribe();
  }

  @override
  void didUpdateWidget(ArtworkTint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) _subscribe();
  }

  void _subscribe() {
    _unsubscribe();
    final image = widget.image;
    if (image == null) {
      if (_tint != null) {
        _tint = null;
        _announce(null);
      }
      return;
    }
    final generation = ++_generation;
    final stream = image.resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener(
      (info, _) => _read(info.image, generation),
      onError: (_, _) {},
    );
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  Future<void> _read(ui.Image image, int generation) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null || !mounted || generation != _generation) return;
    final color = dominantColor(data.buffer.asUint8List());
    if (color == _tint) return;
    setState(() => _tint = color);
    _announce(color);
  }

  void _announce(Color? color) {
    final callback = widget.onTint;
    if (callback == null) return;
    // May be reached while the tree is building: deliver it right after.
    scheduleMicrotask(() {
      if (mounted) callback(color);
    });
  }

  void _unsubscribe() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _tint);
}
