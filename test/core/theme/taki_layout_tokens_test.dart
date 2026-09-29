import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/theme/taki_colors.dart';
import 'package:taki/core/theme/taki_elevation.dart';
import 'package:taki/core/theme/taki_radius.dart';
import 'package:taki/core/theme/taki_spacing.dart';

import 'design_system_doc.dart';

/// Valores de la tabla de una sección: `token` → número.
Map<String, double> _tokenValues(int section) => {
      for (final row in DesignSystemDoc.load().tableRows(section))
        if (row.length >= 2 &&
            DesignSystemDoc.token(row[0]) != null &&
            DesignSystemDoc.number(row[1]) != null)
          DesignSystemDoc.token(row[0])!: DesignSystemDoc.number(row[1])!,
    };

void main() {
  group('espaciado (§3)', () {
    const code = {
      'space2xs': TakiSpacing.xxs,
      'spaceXs': TakiSpacing.xs,
      'spaceSm': TakiSpacing.sm,
      'spaceMd': TakiSpacing.md,
      'spaceLg': TakiSpacing.lg,
      'spaceXl': TakiSpacing.xl,
      'space2xl': TakiSpacing.xxl,
      'space3xl': TakiSpacing.xxxl,
    };

    test('la escala es la del documento, ni más ni menos', () {
      expect(code, _tokenValues(3));
    });

    test('base 4 (salvo el 2 entre líneas de texto) y creciente', () {
      final values = code.values.toList();
      for (var i = 1; i < values.length; i++) {
        expect(values[i], greaterThan(values[i - 1]));
        expect(values[i] % 4, 0, reason: '${values[i]} no es múltiplo de 4');
      }
    });

    test('las reglas con nombre usan la escala', () {
      expect(TakiSpacing.pageGutter, TakiSpacing.lg);
      expect(TakiSpacing.pageGutterImmersive, TakiSpacing.xl);
      expect(TakiSpacing.sectionGap, TakiSpacing.xl);
    });
  });

  group('radios (§4)', () {
    test('cuatro radios del documento', () {
      expect(
        {
          'radiusSm': TakiRadius.sm,
          'radiusMd': TakiRadius.md,
          'radiusLg': TakiRadius.lg,
          'radiusXl': TakiRadius.xl,
        },
        _tokenValues(4),
      );
    });

    test('el radio del artwork depende de su tamaño', () {
      expect(TakiRadius.forArtwork(44), TakiRadius.sm);
      expect(TakiRadius.forArtwork(64), TakiRadius.sm);
      expect(TakiRadius.forArtwork(65), TakiRadius.md);
      expect(TakiRadius.forArtwork(128), TakiRadius.md);
      expect(TakiRadius.forArtwork(160), TakiRadius.md);
      expect(TakiRadius.forArtwork(161), TakiRadius.xl);
      expect(TakiRadius.forArtwork(360), TakiRadius.xl);
    });

    test('BorderRadius y valores coinciden', () {
      expect(TakiRadius.smAll, BorderRadius.circular(TakiRadius.sm));
      expect(TakiRadius.mdAll, BorderRadius.circular(TakiRadius.md));
      expect(TakiRadius.lgAll, BorderRadius.circular(TakiRadius.lg));
      expect(TakiRadius.xlAll, BorderRadius.circular(TakiRadius.xl));
    });
  });

  group('elevación (§5)', () {
    test('cuatro niveles, cada uno al menos tan claro como el anterior', () {
      expect(TakiElevation.values, hasLength(4));
      for (var i = 1; i < TakiElevation.values.length; i++) {
        expect(
          TakiElevation.values[i].surface.computeLuminance(),
          greaterThanOrEqualTo(
            TakiElevation.values[i - 1].surface.computeLuminance(),
          ),
        );
      }
      expect(TakiElevation.integrated.surface, TakiColors.background);
      expect(TakiElevation.raised.surface, TakiColors.surface);
      expect(TakiElevation.floating.surface, TakiColors.surfaceElevated);
    });

    test('solo el nivel modal oscurece lo de detrás', () {
      expect(
        [for (final level in TakiElevation.values) if (level.hasScrim) level],
        [TakiElevation.modal],
      );
    });

    test('la única sombra es la del artwork: negro al 40 %, 32 de desenfoque',
        () {
      expect(TakiElevation.artworkShadow.color.a, closeTo(0.4, 0.002));
      expect(TakiElevation.artworkShadow.blurRadius, 32);
      expect(TakiElevation.artworkShadow.offset, const Offset(0, 12));
    });
  });
}
