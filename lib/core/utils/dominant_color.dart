import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/painting.dart' show HSLColor;

/// The color that best represents an image, from its straight RGBA pixels.
///
/// Pixels are grouped into coarse color buckets (16 levels per channel) and
/// the heaviest bucket wins. Vivid pixels weigh more than grey ones, and
/// near-black and near-white pixels are ignored: they are usually borders or
/// backgrounds and make a poor accent. Returns `null` when nothing usable is
/// left (a plain black, white or fully transparent image).
///
/// [stride] reads every n-th pixel, which is plenty for a cover and keeps the
/// cost flat for larger images.
Color? dominantColor(Uint8List rgba, {int stride = 2}) {
  if (stride < 1) throw ArgumentError.value(stride, 'stride', 'must be >= 1');

  final weight = <int, double>{};
  final red = <int, int>{};
  final green = <int, int>{};
  final blue = <int, int>{};
  final count = <int, int>{};

  final pixels = rgba.length ~/ 4;
  for (var i = 0; i < pixels; i += stride) {
    final o = i * 4;
    if (rgba[o + 3] < 200) continue;
    final r = rgba[o];
    final g = rgba[o + 1];
    final b = rgba[o + 2];

    final maxChannel = r > g ? (r > b ? r : b) : (g > b ? g : b);
    final minChannel = r < g ? (r < b ? r : b) : (g < b ? g : b);
    final value = maxChannel / 255;
    final saturation = maxChannel == 0 ? 0.0 : (maxChannel - minChannel) / maxChannel;
    if (value < 0.15) continue;
    if (value > 0.95 && saturation < 0.1) continue;

    final bucket = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4);
    weight[bucket] = (weight[bucket] ?? 0) + 1 + saturation * 3;
    red[bucket] = (red[bucket] ?? 0) + r;
    green[bucket] = (green[bucket] ?? 0) + g;
    blue[bucket] = (blue[bucket] ?? 0) + b;
    count[bucket] = (count[bucket] ?? 0) + 1;
  }
  if (weight.isEmpty) return null;

  var best = weight.keys.first;
  for (final entry in weight.entries) {
    if (entry.value > weight[best]!) best = entry.key;
  }
  final n = count[best]!;
  return Color.fromARGB(255, red[best]! ~/ n, green[best]! ~/ n, blue[best]! ~/ n);
}

/// A dark, slightly muted version of [color] fit to sit behind light text:
/// the hue is kept, the lightness is pulled down and the saturation capped.
Color backdropTint(Color color, {double lightness = 0.24}) {
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withLightness(lightness)
      .withSaturation(hsl.saturation.clamp(0.0, 0.65).toDouble())
      .toColor();
}
