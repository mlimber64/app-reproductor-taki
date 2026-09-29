import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/theme/taki_colors.dart';
import 'package:taki/core/theme/taki_motion.dart';
import 'package:taki/core/theme/taki_spacing.dart';
import 'package:taki/core/widgets/taki_button.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Center(child: child))),
  );
}

Container _pill(WidgetTester tester) => tester.widget<Container>(
      find.descendant(
        of: find.byType(TakiButton),
        matching: find.byType(Container),
      ),
    );

ShapeDecoration _decoration(WidgetTester tester) =>
    _pill(tester).decoration! as ShapeDecoration;

Color? _labelColor(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label)).style!.color;

void main() {
  testWidgets('pulsar llama a onPressed', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      TakiButton(label: 'Reproducir', onPressed: () => taps++),
    );

    await tester.tap(find.byType(TakiButton));
    expect(taps, 1);
  });

  testWidgets('alto 48 y forma de píldora', (tester) async {
    await _pump(tester, TakiButton(label: 'Crear', onPressed: () {}));

    expect(tester.getSize(find.byType(TakiButton)).height, TakiButton.height);
    expect(_decoration(tester).shape, isA<StadiumBorder>());
  });

  testWidgets('variantes: fondo, texto y borde de §9', (tester) async {
    Future<void> check(
      TakiButtonVariant variant, {
      required Color text,
      Color? background,
      Color? border,
    }) async {
      await _pump(
        tester,
        TakiButton(label: 'Acción', variant: variant, onPressed: () {}),
      );
      final decoration = _decoration(tester);
      final side = (decoration.shape as StadiumBorder).side;
      expect(decoration.color, background, reason: variant.name);
      expect(_labelColor(tester, 'Acción'), text, reason: variant.name);
      expect(
        side == BorderSide.none ? null : side.color,
        border,
        reason: variant.name,
      );
    }

    await check(
      TakiButtonVariant.primary,
      background: TakiColors.primary,
      text: TakiColors.onPrimary,
    );
    await check(
      TakiButtonVariant.secondary,
      background: TakiColors.surfaceElevated,
      text: TakiColors.textPrimary,
      border: TakiColors.outline,
    );
    await check(TakiButtonVariant.tertiary, text: TakiColors.primary);
    await check(
      TakiButtonVariant.destructive,
      background: TakiColors.error,
      text: TakiColors.onPrimary,
    );
    await check(TakiButtonVariant.destructiveTertiary, text: TakiColors.error);
  });

  group('icono', () {
    testWidgets('icono de 20 delante y relleno 16 izq. / 24 der.',
        (tester) async {
      await _pump(
        tester,
        TakiButton(
          label: 'Aleatorio',
          icon: Icons.shuffle_rounded,
          onPressed: () {},
        ),
      );

      expect(tester.widget<Icon>(find.byIcon(Icons.shuffle_rounded)).size, 20);
      expect(
        _pill(tester).padding,
        const EdgeInsets.only(left: TakiSpacing.lg, right: TakiSpacing.xl),
      );
      expect(
        tester.getTopLeft(find.byIcon(Icons.shuffle_rounded)).dx,
        lessThan(tester.getTopLeft(find.text('Aleatorio')).dx),
      );
    });

    testWidgets('sin icono, 24 a ambos lados', (tester) async {
      await _pump(tester, TakiButton(label: 'Crear', onPressed: () {}));
      expect(
        _pill(tester).padding,
        const EdgeInsets.symmetric(horizontal: TakiSpacing.xl),
      );
    });
  });

  group('deshabilitado', () {
    testWidgets('no responde y se anuncia deshabilitado', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const TakiButton(label: 'Crear', onPressed: null));

      await tester.tap(find.byType(TakiButton), warnIfMissed: false);
      expect(
        tester.getSemantics(find.byType(TakiButton)),
        isSemantics(
          label: 'Crear',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('primario: fondo al 12 % y texto al 38 %', (tester) async {
      await _pump(tester, const TakiButton(label: 'Crear', onPressed: null));

      expect(_decoration(tester).color, TakiColors.disabledContainer);
      expect(_labelColor(tester, 'Crear'), TakiColors.disabledContent);
    });

    testWidgets('secundario: texto al 38 % y borde al 12 %', (tester) async {
      await _pump(
        tester,
        const TakiButton(
          label: 'Aleatorio',
          variant: TakiButtonVariant.secondary,
          onPressed: null,
        ),
      );

      expect(_labelColor(tester, 'Aleatorio'), TakiColors.disabledContent);
      expect(
        (_decoration(tester).shape as StadiumBorder).side.color,
        TakiColors.disabledContainer,
      );
    });
  });

  group('cargando', () {
    testWidgets('no se puede pulsar dos veces ni mientras carga',
        (tester) async {
      var taps = 0;
      await _pump(
        tester,
        TakiButton(label: 'Guardar', loading: true, onPressed: () => taps++),
      );

      await tester.tap(find.byType(TakiButton), warnIfMissed: false);
      await tester.pump();
      expect(taps, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('mantiene el tamaño, con y sin icono', (tester) async {
      for (final icon in [null, Icons.add_rounded]) {
        await _pump(
          tester,
          TakiButton(label: 'Nueva playlist', icon: icon, onPressed: () {}),
        );
        final idle = tester.getSize(find.byType(TakiButton));

        await _pump(
          tester,
          TakiButton(
            label: 'Nueva playlist',
            icon: icon,
            loading: true,
            onPressed: () {},
          ),
        );
        expect(tester.getSize(find.byType(TakiButton)), idle,
            reason: 'icono: $icon');
      }
    });

    testWidgets('con icono: el spinner sustituye al icono, el texto sigue',
        (tester) async {
      await _pump(
        tester,
        TakiButton(
          label: 'Guardar',
          icon: Icons.check_rounded,
          loading: true,
          onPressed: () {},
        ),
      );

      expect(find.byIcon(Icons.check_rounded), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Guardar'), findsOneWidget);
    });

    testWidgets('conserva su aspecto (no parece deshabilitado)',
        (tester) async {
      await _pump(
        tester,
        TakiButton(label: 'Guardar', loading: true, onPressed: () {}),
      );
      expect(_decoration(tester).color, TakiColors.primary);
    });

    testWidgets('se anuncia como "Cargando"', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        TakiButton(label: 'Guardar', loading: true, onPressed: () {}),
      );

      expect(
        tester.getSemantics(find.byType(TakiButton)),
        isSemantics(
          label: 'Guardar',
          value: TakiButton.loadingSemanticValue,
          isButton: true,
          isEnabled: false,
        ),
      );
      handle.dispose();
    });
  });

  group('pulsado', () {
    testWidgets('primario: fondo primaryPressed y escala 0.98',
        (tester) async {
      await _pump(tester, TakiButton(label: 'Reproducir', onPressed: () {}));

      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(TakiButton)));
      await tester.pump();

      expect(_decoration(tester).color, TakiColors.primaryPressed);
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        TakiMotion.pressedScale,
      );
      await gesture.up();
    });

    testWidgets('secundario: capa de pulsado, sin escala', (tester) async {
      await _pump(
        tester,
        TakiButton(
          label: 'Aleatorio',
          variant: TakiButtonVariant.secondary,
          onPressed: () {},
        ),
      );

      final gesture =
          await tester.startGesture(tester.getCenter(find.byType(TakiButton)));
      await tester.pump();

      expect(
        (_pill(tester).foregroundDecoration! as ShapeDecoration).color,
        TakiColors.pressedOverlay,
      );
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        1,
      );
      await gesture.up();
    });
  });

  testWidgets('semanticLabel sustituye a la etiqueta visible', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      TakiButton(
        label: 'Ver todo',
        semanticLabel: 'Ver todos los álbumes',
        variant: TakiButtonVariant.tertiary,
        onPressed: () {},
      ),
    );

    expect(find.bySemanticsLabel('Ver todos los álbumes'), findsOneWidget);
    expect(find.bySemanticsLabel('Ver todo'), findsNothing);
    handle.dispose();
  });
}
