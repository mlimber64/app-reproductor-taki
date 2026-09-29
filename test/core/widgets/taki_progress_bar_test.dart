import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/theme/taki_colors.dart';
import 'package:taki/core/theme/taki_typography.dart';
import 'package:taki/core/widgets/taki_progress_bar.dart';

import 'widget_test_utils.dart';

const _duration = Duration(minutes: 3, seconds: 20);

Future<void> _pump(
  WidgetTester tester, {
  Duration position = Duration.zero,
  Duration duration = _duration,
  ValueChanged<Duration>? onSeek,
  bool enabled = true,
  double width = 412,
}) {
  return pumpInScreen(
    tester,
    TakiProgressBar(
      position: position,
      duration: duration,
      onSeek: onSeek ?? (_) {},
      enabled: enabled,
    ),
    width: width,
  );
}

Slider _slider(WidgetTester tester) => tester.widget<Slider>(find.byType(Slider));

double _fraction(WidgetTester tester) {
  final slider = _slider(tester);
  return slider.value / slider.max;
}

void main() {
  group('progreso', () {
    testWidgets('inicial', (tester) async {
      await _pump(tester);
      expect(_fraction(tester), 0);
      expect(find.text('0:00'), findsOneWidget);
      expect(find.text('3:20'), findsOneWidget);
    });

    testWidgets('intermedio', (tester) async {
      await _pump(tester, position: const Duration(minutes: 1, seconds: 40));
      expect(_fraction(tester), closeTo(0.5, 0.001));
      expect(find.text('1:40'), findsOneWidget);
    });

    testWidgets('final', (tester) async {
      await _pump(tester, position: _duration);
      expect(_fraction(tester), 1);
      expect(find.text('3:20'), findsNWidgets(2));
    });
  });

  group('valores fuera de rango', () {
    testWidgets('posición mayor que la duración: se queda al final',
        (tester) async {
      await _pump(tester, position: const Duration(minutes: 9));
      expect(tester.takeException(), isNull);
      expect(_fraction(tester), 1);
      expect(find.text('3:20'), findsNWidgets(2));
    });

    testWidgets('posición negativa: se queda al principio', (tester) async {
      await _pump(tester, position: const Duration(seconds: -30));
      expect(tester.takeException(), isNull);
      expect(_fraction(tester), 0);
      expect(find.text('0:00'), findsOneWidget);
    });

    testWidgets('duración 0: en 0:00 y sin poder moverse', (tester) async {
      await _pump(
        tester,
        duration: Duration.zero,
        position: const Duration(seconds: 20),
      );
      expect(tester.takeException(), isNull);
      expect(_slider(tester).value, 0);
      expect(_slider(tester).onChanged, isNull);
      expect(find.text('0:00'), findsNWidgets(2));
    });

    testWidgets('duración negativa: igual que 0', (tester) async {
      await _pump(tester, duration: const Duration(seconds: -5));
      expect(tester.takeException(), isNull);
      expect(_slider(tester).onChanged, isNull);
    });
  });

  group('seek', () {
    testWidgets('arrastrar muestra la posición y solo avisa al soltar',
        (tester) async {
      final seeks = <Duration>[];
      await _pump(tester, onSeek: seeks.add);

      final rect = tester.getRect(find.byType(Slider));
      final gesture = await tester.startGesture(
        Offset(rect.left + TakiProgressBar.thumbRadius, rect.center.dy),
      );
      await tester.pump();
      await gesture.moveTo(rect.center);
      await tester.pump();

      expect(seeks, isEmpty);
      expect(find.text('1:40'), findsOneWidget);

      await gesture.up();
      await tester.pump();
      expect(seeks, hasLength(1));
      expect(seeks.single.inMilliseconds, closeTo(100000, 1000));
    });

    testWidgets('tocar un punto de la barra busca ahí', (tester) async {
      final seeks = <Duration>[];
      await _pump(tester, onSeek: seeks.add);

      await tester.tap(find.byType(Slider));
      await tester.pump();
      expect(seeks.single.inMilliseconds, closeTo(100000, 1000));
    });

    testWidgets('con TalkBack (acción aumentar) también busca',
        (tester) async {
      final handle = tester.ensureSemantics();
      final seeks = <Duration>[];
      await _pump(tester, onSeek: seeks.add);

      final node = tester.getSemantics(find.byType(Slider));
      node.owner!.performAction(node.id, SemanticsAction.increase);
      await tester.pump();

      expect(seeks, hasLength(1));
      expect(seeks.single, greaterThan(Duration.zero));
      handle.dispose();
    });
  });

  group('deshabilitada', () {
    testWidgets('no se puede mover ni busca', (tester) async {
      final seeks = <Duration>[];
      await _pump(
        tester,
        enabled: false,
        position: const Duration(minutes: 1),
        onSeek: seeks.add,
      );

      expect(_slider(tester).onChanged, isNull);
      await tester.tap(find.byType(Slider));
      await tester.pump();
      expect(seeks, isEmpty);
      // Sigue mostrando dónde va.
      expect(find.text('1:00'), findsOneWidget);
    });

    testWidgets('sin onSeek se comporta como deshabilitada', (tester) async {
      await pumpInScreen(
        tester,
        const TakiProgressBar(position: Duration.zero, duration: _duration, onSeek: null),
      );
      expect(_slider(tester).onChanged, isNull);
    });
  });

  testWidgets('semántica: etiqueta, posición y duración', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, position: const Duration(minutes: 1, seconds: 5));

    expect(
      tester.getSemantics(find.byType(Slider)),
      isSemantics(
        label: TakiProgressBar.semanticLabel,
        value: '1:05 de 3:20',
        isSlider: true,
        hasIncreaseAction: true,
        hasDecreaseAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('tokens: pista naranja sobre divider; tiempos caption tabular',
      (tester) async {
    await _pump(tester);
    final theme = SliderTheme.of(tester.element(find.byType(Slider)));
    expect(theme.activeTrackColor, TakiColors.primary);
    expect(theme.inactiveTrackColor, TakiColors.divider);
    expect(theme.thumbColor, TakiColors.textPrimary);
    expect(theme.trackHeight, TakiProgressBar.trackHeight);

    final time = tester.widget<Text>(find.text('3:20')).style!;
    expect(time.fontSize, TakiTypography.caption.fontSize);
    expect(time.fontFeatures, TakiTypography.caption.fontFeatures);
    expect(time.color, TakiColors.textSecondary);
  });

  testWidgets('área táctil de 48 y sin desbordes en pantallas estrechas',
      (tester) async {
    await _pump(tester, width: 240, position: const Duration(minutes: 59));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(Slider)).height, greaterThanOrEqualTo(48));
  });
}
