import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/utils/dominant_color.dart';

/// `count` pixels of one RGBA color.
Uint8List solid(int r, int g, int b, {int a = 255, int count = 100}) {
  final bytes = Uint8List(count * 4);
  for (var i = 0; i < count; i++) {
    bytes[i * 4] = r;
    bytes[i * 4 + 1] = g;
    bytes[i * 4 + 2] = b;
    bytes[i * 4 + 3] = a;
  }
  return bytes;
}

Uint8List concat(List<Uint8List> parts) =>
    Uint8List.fromList([for (final part in parts) ...part]);

void main() {
  group('dominantColor', () {
    test('a solid image gives that color', () {
      final color = dominantColor(solid(200, 40, 40), stride: 1);

      expect(color, const Color.fromARGB(255, 200, 40, 40));
    });

    test('the most common color wins', () {
      final bytes = concat([
        solid(30, 120, 220, count: 300),
        solid(220, 40, 40, count: 100),
      ]);

      expect(dominantColor(bytes, stride: 1),
          const Color.fromARGB(255, 30, 120, 220));
    });

    test('a vivid color beats a grey one of similar size', () {
      final bytes = concat([
        solid(120, 120, 120, count: 110),
        solid(230, 60, 30, count: 100),
      ]);

      expect(dominantColor(bytes, stride: 1),
          const Color.fromARGB(255, 230, 60, 30));
    });

    test('near-black and near-white pixels are ignored', () {
      final bytes = concat([
        solid(5, 5, 5, count: 500),
        solid(255, 255, 255, count: 500),
        solid(40, 160, 90, count: 10),
      ]);

      expect(dominantColor(bytes, stride: 1),
          const Color.fromARGB(255, 40, 160, 90));
    });

    test('nothing usable gives null', () {
      expect(dominantColor(solid(0, 0, 0)), isNull);
      expect(dominantColor(solid(255, 255, 255)), isNull);
      expect(dominantColor(solid(200, 40, 40, a: 0)), isNull);
      expect(dominantColor(Uint8List(0)), isNull);
    });

    test('rejects a stride below one', () {
      expect(() => dominantColor(solid(1, 2, 3), stride: 0), throwsArgumentError);
    });
  });

  group('backdropTint', () {
    test('is darker than the color and keeps its hue', () {
      const bright = Color.fromARGB(255, 230, 60, 30);

      final tint = backdropTint(bright);

      expect(tint.computeLuminance(), lessThan(bright.computeLuminance()));
      expect(tint.r, greaterThan(tint.b), reason: 'still reddish');
    });
  });
}
