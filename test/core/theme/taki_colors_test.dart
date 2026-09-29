import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/theme/taki_colors.dart';

import 'design_system_doc.dart';

void main() {
  const surfaces = {
    'background': TakiColors.background,
    'surface': TakiColors.surface,
    'surfaceElevated': TakiColors.surfaceElevated,
    'surfaceHighest': TakiColors.surfaceHighest,
  };

  group('coincide con docs/DESIGN_SYSTEM.md §1', () {
    // Tokens con HEX propio en las tablas de color.
    final code = <String, Color>{
      ...surfaces,
      'textPrimary': TakiColors.textPrimary,
      'textSecondary': TakiColors.textSecondary,
      'textMuted': TakiColors.textMuted,
      'onTextPrimary': TakiColors.onTextPrimary,
      'primary': TakiColors.primary,
      'onPrimary': TakiColors.onPrimary,
      'primaryPressed': TakiColors.primaryPressed,
      'primaryContainer': TakiColors.primaryContainer,
      'onPrimaryContainer': TakiColors.onPrimaryContainer,
      'divider': TakiColors.divider,
      'outline': TakiColors.outline,
      'error': TakiColors.error,
      'errorContainer': TakiColors.errorContainer,
      'success': TakiColors.success,
      'warning': TakiColors.warning,
    };

    final documented = <String, Color>{};
    final rows = DesignSystemDoc.load().tableRows(1);
    for (final row in rows) {
      if (row.length < 3) continue;
      final token = DesignSystemDoc.token(row[1]);
      final hex = DesignSystemDoc.hexColor(row[2]);
      if (token != null && hex != null) documented[token] = hex;
    }

    test('cada token con HEX en el documento tiene el mismo valor en código',
        () {
      expect(documented.keys, containsAll(code.keys));
      for (final entry in code.entries) {
        expect(
          entry.value,
          documented[entry.key],
          reason: '${entry.key}: código y documento difieren',
        );
      }
    });

    test('degradado de marca', () {
      final row = rows.firstWhere(
        (r) => DesignSystemDoc.token(r.first) == 'brandGradient',
      );
      expect(TakiColors.brandGradient.colors, DesignSystemDoc.hexColors(row[1]));
      // 135°: de arriba a la izquierda hacia abajo a la derecha.
      expect(TakiColors.brandGradient.begin, Alignment.topLeft);
      expect(TakiColors.brandGradient.end, Alignment.bottomRight);
    });
  });

  test('las superficies aclaran de forma progresiva (§1.2, §5)', () {
    final levels = surfaces.values.toList();
    for (var i = 1; i < levels.length; i++) {
      final step = contrastRatio(levels[i], levels[i - 1]);
      expect(
        levels[i].computeLuminance(),
        greaterThan(levels[i - 1].computeLuminance()),
      );
      // Un escalón distinguible (el tema anterior tenía 1.06 y no se veía).
      expect(step, greaterThanOrEqualTo(1.07), reason: 'nivel $i');
    }
  });

  group('contraste mínimo WCAG AA (§19)', () {
    void expectAtLeast(Color fg, Color bg, double min, String what) {
      expect(contrastRatio(fg, bg), greaterThanOrEqualTo(min), reason: what);
    }

    test('texto principal y secundario sobre todas las superficies', () {
      for (final entry in surfaces.entries) {
        expectAtLeast(TakiColors.textPrimary, entry.value, 4.5,
            'textPrimary / ${entry.key}');
        expectAtLeast(TakiColors.textSecondary, entry.value, 4.5,
            'textSecondary / ${entry.key}');
      }
    });

    test('texto atenuado sobre los niveles 0 a 2', () {
      for (final bg in [
        TakiColors.background,
        TakiColors.surface,
        TakiColors.surfaceElevated,
      ]) {
        expectAtLeast(TakiColors.textMuted, bg, 4.5, 'textMuted');
      }
    });

    test('naranja y contenido sobre naranja', () {
      expectAtLeast(TakiColors.primary, TakiColors.background, 4.5,
          'primary / background');
      expectAtLeast(TakiColors.onPrimary, TakiColors.primary, 4.5,
          'onPrimary / primary');
      expectAtLeast(TakiColors.onPrimary, TakiColors.primaryPressed, 4.5,
          'onPrimary / primaryPressed');
      expectAtLeast(TakiColors.primary, TakiColors.primaryContainer, 4.5,
          'primary / primaryContainer (pestaña activa)');
      expectAtLeast(TakiColors.onPrimaryContainer, TakiColors.primaryContainer,
          4.5, 'onPrimaryContainer / primaryContainer');
      expectAtLeast(TakiColors.onTextPrimary, TakiColors.textPrimary, 4.5,
          'onTextPrimary / textPrimary (play del mini player)');
    });

    test('colores de estado', () {
      for (final c in [TakiColors.error, TakiColors.success, TakiColors.warning]) {
        expectAtLeast(c, TakiColors.background, 4.5, '$c / background');
      }
      expectAtLeast(TakiColors.error, TakiColors.errorContainer, 4.5,
          'error / errorContainer');
      expectAtLeast(TakiColors.onPrimary, TakiColors.error, 4.5,
          'botón destructivo relleno');
    });

    test('anillo de foco visible (≥ 3:1 para componentes)', () {
      // El anillo va a 2 px del componente (§9, §17): lo que tiene al lado es
      // la superficie de detrás, no el componente. Pegado a un botón naranja,
      // focusRingOnPrimary solo daría 2.1:1: por eso el hueco es obligatorio.
      for (final bg in surfaces.values) {
        expectAtLeast(TakiColors.focusRing, bg, 3, 'focusRing');
        expectAtLeast(TakiColors.focusRingOnPrimary, bg, 3,
            'focusRingOnPrimary');
      }
    });
  });

  group('estados derivados (§1.4.1) reutilizan la paleta', () {
    test('seleccionado y activo', () {
      expect(TakiColors.selected, TakiColors.primaryContainer);
      expect(TakiColors.active, TakiColors.primary);
      expect(TakiColors.focusRing, TakiColors.primary);
    });

    test('capas de pulsado y deshabilitado sobre textPrimary', () {
      void expectOverlay(Color c, double alpha) {
        expect(c.withValues(alpha: 1), TakiColors.textPrimary);
        expect(c.a, closeTo(alpha, 0.001));
      }

      expectOverlay(TakiColors.pressedOverlay, 0.10);
      expectOverlay(TakiColors.disabledContent, 0.38);
      expectOverlay(TakiColors.disabledContainer, 0.12);
      expect(TakiColors.artworkScrim.withValues(alpha: 1), TakiColors.background);
      expect(TakiColors.artworkScrim.a, closeTo(0.55, 0.001));
      expect(TakiColors.scrim.withValues(alpha: 1), const Color(0xFF000000));
      expect(TakiColors.scrim.a, closeTo(0.6, 0.001));
    });
  });
}
