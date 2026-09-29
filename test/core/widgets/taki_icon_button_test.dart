import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/theme/taki_colors.dart';
import 'package:taki/core/theme/taki_icon_size.dart';
import 'package:taki/core/theme/taki_motion.dart';
import 'package:taki/core/widgets/taki_icon_button.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Center(child: child))),
  );
}

Icon _icon(WidgetTester tester) => tester.widget<Icon>(find.descendant(
      of: find.byType(TakiIconButton),
      matching: find.byType(Icon),
    ));

ShapeDecoration _container(WidgetTester tester) =>
    tester.widget<Container>(find.descendant(
      of: find.byType(TakiIconButton),
      matching: find.byType(Container),
    )).decoration! as ShapeDecoration;

void main() {
  testWidgets('pulsar llama a onPressed', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      TakiIconButton(
        icon: Icons.more_horiz_rounded,
        semanticLabel: 'Más opciones',
        onPressed: () => taps++,
      ),
    );

    await tester.tap(find.byType(TakiIconButton));
    expect(taps, 1);
  });

  testWidgets('área táctil de 48 aunque el icono sea menor', (tester) async {
    await _pump(
      tester,
      TakiIconButton(
        icon: Icons.close_rounded,
        semanticLabel: 'Cerrar',
        iconSize: TakiIconSize.sm,
        onPressed: () {},
      ),
    );

    expect(tester.getSize(find.byType(TakiIconButton)), const Size(48, 48));
    expect(_icon(tester).size, 20);
  });

  testWidgets('semántica: botón con etiqueta, habilitado y pulsable',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      TakiIconButton(
        icon: Icons.more_horiz_rounded,
        semanticLabel: 'Más opciones',
        onPressed: () {},
      ),
    );

    expect(
      tester.getSemantics(find.byType(TakiIconButton)),
      isSemantics(
        label: 'Más opciones',
        isButton: true,
        isEnabled: true,
        hasEnabledState: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('el tooltip usa la etiqueta semántica', (tester) async {
    await _pump(
      tester,
      TakiIconButton(
        icon: Icons.queue_music_rounded,
        semanticLabel: 'Abrir la cola',
        onPressed: () {},
      ),
    );

    expect(
      tester.widget<Tooltip>(find.byType(Tooltip)).message,
      'Abrir la cola',
    );
  });

  group('deshabilitado', () {
    testWidgets('no responde, se anuncia deshabilitado e icono al 38 %',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const TakiIconButton(
          icon: Icons.skip_next_rounded,
          semanticLabel: 'Siguiente',
          onPressed: null,
        ),
      );

      await tester.tap(find.byType(TakiIconButton), warnIfMissed: false);
      expect(_icon(tester).color!.a, closeTo(0.38, 0.01));
      expect(
        tester.getSemantics(find.byType(TakiIconButton)),
        isSemantics(
          label: 'Siguiente',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('con contenedor: contenedor al 12 %', (tester) async {
      await _pump(
        tester,
        const TakiIconButton(
          icon: Icons.play_arrow_rounded,
          semanticLabel: 'Reproducir',
          variant: TakiIconButtonVariant.inverse,
          onPressed: null,
        ),
      );
      expect(_container(tester).color, TakiColors.disabledContainer);
    });
  });

  group('toggle (selected)', () {
    Widget toggle({required bool selected}) => TakiIconButton(
          icon: Icons.shuffle_rounded,
          selectedIcon: Icons.shuffle_on_rounded,
          semanticLabel: 'Aleatorio',
          selected: selected,
          onPressed: () {},
        );

    testWidgets('activo: color primary **y** otra forma de icono',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, toggle(selected: true));

      expect(_icon(tester).icon, Icons.shuffle_on_rounded);
      expect(_icon(tester).color, TakiColors.active);
      expect(
        tester.getSemantics(find.byType(TakiIconButton)),
        isSemantics(hasToggledState: true, isToggled: true),
      );
      handle.dispose();
    });

    testWidgets('apagado: icono normal, se anuncia como interruptor',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, toggle(selected: false));

      expect(_icon(tester).icon, Icons.shuffle_rounded);
      expect(_icon(tester).color, isNot(TakiColors.active));
      expect(
        tester.getSemantics(find.byType(TakiIconButton)),
        isSemantics(hasToggledState: true, isToggled: false),
      );
      handle.dispose();
    });

    testWidgets('sin selected no es un interruptor', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        TakiIconButton(
          icon: Icons.close_rounded,
          semanticLabel: 'Cerrar',
          onPressed: () {},
        ),
      );
      expect(
        tester.getSemantics(find.byType(TakiIconButton)),
        isSemantics(hasToggledState: false),
      );
      handle.dispose();
    });
  });

  testWidgets('variantes: color de icono y de contenedor', (tester) async {
    Future<void> check(
      TakiIconButtonVariant variant, {
      required Color icon,
      Color? container,
    }) async {
      await _pump(
        tester,
        TakiIconButton(
          icon: Icons.close_rounded,
          semanticLabel: 'Cerrar',
          variant: variant,
          onPressed: () {},
        ),
      );
      expect(_icon(tester).color, icon, reason: variant.name);
      expect(_container(tester).color, container, reason: variant.name);
    }

    await check(TakiIconButtonVariant.standard, icon: TakiColors.iconPrimary);
    await check(TakiIconButtonVariant.subtle, icon: TakiColors.iconSecondary);
    await check(
      TakiIconButtonVariant.tonal,
      icon: TakiColors.iconPrimary,
      container: TakiColors.surfaceElevated,
    );
    await check(
      TakiIconButtonVariant.inverse,
      icon: TakiColors.onTextPrimary,
      container: TakiColors.textPrimary,
    );
  });

  testWidgets('pulsado: capa circular de pulsado', (tester) async {
    await _pump(
      tester,
      TakiIconButton(
        icon: Icons.close_rounded,
        semanticLabel: 'Cerrar',
        onPressed: () {},
      ),
    );

    Color? overlay() => (tester.widget<Container>(find.descendant(
          of: find.byType(TakiIconButton),
          matching: find.byType(Container),
        )).foregroundDecoration as ShapeDecoration?)?.color;

    expect(overlay(), isNull);
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(TakiIconButton)));
    // Con tooltip compiten dos gestos: el pulsado se confirma a los 100 ms
    // (kPressTimeout), dentro del límite de respuesta de §17.
    await tester.pump(TakiMotion.instant);
    expect(overlay(), TakiColors.pressedOverlay);
    await gesture.up();
    await tester.pump();
    expect(overlay(), isNull);
  });

  testWidgets('teclado: el foco muestra el anillo y Enter lo activa',
      (tester) async {
    var taps = 0;
    await _pump(
      tester,
      TakiIconButton(
        icon: Icons.close_rounded,
        semanticLabel: 'Cerrar',
        onPressed: () => taps++,
      ),
    );

    bool ringVisible() => find
        .descendant(
          of: find.byType(TakiIconButton),
          matching: find.byWidgetPredicate((w) =>
              w is DecoratedBox &&
              w.decoration is ShapeDecoration &&
              ((w.decoration as ShapeDecoration).shape as OutlinedBorder)
                      .side
                      .color ==
                  TakiColors.focusRing),
        )
        .evaluate()
        .isNotEmpty;

    expect(ringVisible(), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(ringVisible(), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);
  });
}
