import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/theme/taki_icon_size.dart';
import 'package:taki/core/theme/taki_motion.dart';

import 'design_system_doc.dart';

void main() {
  test('tamaños de icono: los de docs/DESIGN_SYSTEM.md §6.1', () {
    final documented = {
      for (final row in DesignSystemDoc.load().tableRows(6))
        if (row.length >= 2 &&
            DesignSystemDoc.token(row[0]) != null &&
            DesignSystemDoc.number(row[1]) != null)
          DesignSystemDoc.token(row[0])!: DesignSystemDoc.number(row[1])!,
    };

    expect(
      {
        'iconXs': TakiIconSize.xs.value,
        'iconSm': TakiIconSize.sm.value,
        'iconMd': TakiIconSize.md.value,
        'iconLg': TakiIconSize.lg.value,
        'iconXl': TakiIconSize.xl.value,
        'iconHero': TakiIconSize.hero.value,
      },
      documented,
    );
  });

  group('movimiento: docs/DESIGN_SYSTEM.md §18', () {
    final rows = DesignSystemDoc.load().tableRows(18);

    List<int> millis(String token) {
      final row =
          rows.firstWhere((r) => DesignSystemDoc.token(r.first) == token);
      return [
        for (final m in RegExp(r'(\d+) ms').allMatches(row[1]))
          int.parse(m.group(1)!),
      ];
    }

    test('duraciones', () {
      expect(TakiMotion.instant.inMilliseconds, millis('motionInstant').single);
      expect(TakiMotion.short.inMilliseconds, millis('motionShort').single);
      expect(TakiMotion.medium.inMilliseconds, millis('motionMedium').single);
      expect(
        TakiMotion.playingLoop.inMilliseconds,
        millis('motionPlayingLoop').single,
      );
      expect(
        [TakiMotion.longEnter.inMilliseconds, TakiMotion.longExit.inMilliseconds],
        millis('motionLong'),
      );
    });

    test('ninguna animación pasa de 320 ms (§20)', () {
      for (final d in [
        TakiMotion.instant,
        TakiMotion.short,
        TakiMotion.medium,
        TakiMotion.longEnter,
        TakiMotion.longExit,
      ]) {
        expect(d.inMilliseconds, lessThanOrEqualTo(320));
      }
    });

    test('curvas: entrar, salir y cambiar', () {
      final curves = {
        for (final row in rows)
          if (DesignSystemDoc.token(row.first) != null) row.first: row,
      };
      expect(curves.keys, containsAll(['`easeOutCubic`', '`easeInCubic`', '`easeInOutCubic`']));
      expect(TakiMotion.enter, Curves.easeOutCubic);
      expect(TakiMotion.exit, Curves.easeInCubic);
      expect(TakiMotion.change, Curves.easeInOutCubic);
    });
  });
}
