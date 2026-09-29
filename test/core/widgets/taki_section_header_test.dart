import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/theme/taki_colors.dart';
import 'package:taki/core/theme/taki_spacing.dart';
import 'package:taki/core/theme/taki_typography.dart';
import 'package:taki/core/widgets/taki_button.dart';
import 'package:taki/core/widgets/taki_icon_button.dart';
import 'package:taki/core/widgets/taki_section_header.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(home: Scaffold(body: ListView(children: [child]))),
  );
}

TextStyle _style(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

EdgeInsets _padding(WidgetTester tester) => tester
    .widget<Padding>(find.descendant(
      of: find.byType(TakiSectionHeader),
      matching: find.byType(Padding),
    ).first)
    .padding as EdgeInsets;

void main() {
  group('variante sección', () {
    testWidgets('título en titleLarge y textPrimary', (tester) async {
      await _pump(tester, const TakiSectionHeader(title: 'Álbumes'));

      final style = _style(tester, 'Álbumes');
      expect(style.fontFamily, TakiTypography.titleLarge.fontFamily);
      expect(style.fontSize, TakiTypography.titleLarge.fontSize);
      expect(style.color, TakiColors.textPrimary);
    });

    testWidgets('subtítulo opcional debajo, en textSecondary', (tester) async {
      await _pump(
        tester,
        const TakiSectionHeader(title: 'Álbumes', subtitle: '12 álbumes'),
      );

      expect(_style(tester, '12 álbumes').color, TakiColors.textSecondary);
      expect(
        tester.getTopLeft(find.text('12 álbumes')).dy,
        greaterThan(tester.getTopLeft(find.text('Álbumes')).dy),
      );
    });
  });

  group('variante grupo', () {
    testWidgets('eyebrow en MAYÚSCULAS y textMuted', (tester) async {
      await _pump(
        tester,
        const TakiSectionHeader(
          title: 'Tus playlists',
          variant: TakiSectionHeaderVariant.group,
        ),
      );

      expect(find.text('TUS PLAYLISTS'), findsOneWidget);
      final style = _style(tester, 'TUS PLAYLISTS');
      expect(style.fontSize, TakiTypography.eyebrow.fontSize);
      expect(style.letterSpacing, TakiTypography.eyebrow.letterSpacing);
      expect(style.color, TakiColors.textMuted);
    });

    test('no admite subtítulo', () {
      expect(
        () => TakiSectionHeader(
          title: 'Tus playlists',
          variant: TakiSectionHeaderVariant.group,
          subtitle: 'x',
        ),
        throwsAssertionError,
      );
    });
  });

  testWidgets('se anuncia como encabezado, con el título tal cual',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      const TakiSectionHeader(
        title: 'Tus playlists',
        variant: TakiSectionHeaderVariant.group,
      ),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Tus playlists')),
      isSemantics(label: 'Tus playlists', isHeader: true),
    );
    handle.dispose();
  });

  testWidgets('el encabezado y su acción son nodos separados para TalkBack',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      TakiSectionHeader(
        title: 'Álbumes',
        action: TakiSectionHeaderAction.text(
          label: 'Ver todo',
          onPressed: () {},
        ),
      ),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Álbumes')),
      isSemantics(label: 'Álbumes', isHeader: true, isButton: false),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Ver todo')),
      isSemantics(label: 'Ver todo', isButton: true, isHeader: false),
    );
    handle.dispose();
  });

  group('acción', () {
    testWidgets('de texto: botón terciario que se puede pulsar',
        (tester) async {
      var taps = 0;
      await _pump(
        tester,
        TakiSectionHeader(
          title: 'Álbumes',
          action: TakiSectionHeaderAction.text(
            label: 'Ver todo',
            onPressed: () => taps++,
          ),
        ),
      );

      final button = tester.widget<TakiButton>(find.byType(TakiButton));
      expect(button.variant, TakiButtonVariant.tertiary);
      await tester.tap(find.text('Ver todo'));
      expect(taps, 1);
    });

    testWidgets('de texto con etiqueta semántica propia', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        TakiSectionHeader(
          title: 'Álbumes',
          action: TakiSectionHeaderAction.text(
            label: 'Ver todo',
            semanticLabel: 'Ver todos los álbumes',
            onPressed: () {},
          ),
        ),
      );

      expect(find.bySemanticsLabel('Ver todos los álbumes'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('de icono: con su etiqueta semántica', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await _pump(
        tester,
        TakiSectionHeader(
          title: 'Álbumes',
          action: TakiSectionHeaderAction.icon(
            icon: Icons.chevron_right_rounded,
            semanticLabel: 'Ver todos los álbumes',
            onPressed: () => taps++,
          ),
        ),
      );

      expect(find.byType(TakiIconButton), findsOneWidget);
      expect(find.bySemanticsLabel('Ver todos los álbumes'), findsOneWidget);
      await tester.tap(find.byType(TakiIconButton));
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('sin acción no hay botones', (tester) async {
      await _pump(tester, const TakiSectionHeader(title: 'Álbumes'));
      expect(find.byType(TakiButton), findsNothing);
      expect(find.byType(TakiIconButton), findsNothing);
    });

    testWidgets('un título largo no desborda junto a la acción',
        (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 640 * 3);
      addTearDown(tester.view.reset);
      await _pump(
        tester,
        TakiSectionHeader(
          title: 'Una sección con un título larguísimo que no cabe',
          action: TakiSectionHeaderAction.text(
            label: 'Ver todo',
            onPressed: () {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Ver todo'), findsOneWidget);
    });
  });

  group('espaciado (§13)', () {
    testWidgets('sección: 24 arriba, 12 abajo, 16 a los lados',
        (tester) async {
      await _pump(tester, const TakiSectionHeader(title: 'Álbumes'));
      expect(
        _padding(tester),
        const EdgeInsets.fromLTRB(
          TakiSpacing.lg,
          TakiSpacing.xl,
          TakiSpacing.lg,
          TakiSpacing.md,
        ),
      );
    });

    testWidgets('grupo: 8 abajo; primero de la pantalla: 8 arriba',
        (tester) async {
      await _pump(
        tester,
        const TakiSectionHeader(
          title: 'Tus playlists',
          variant: TakiSectionHeaderVariant.group,
          isFirst: true,
        ),
      );
      expect(
        _padding(tester),
        const EdgeInsets.fromLTRB(
          TakiSpacing.lg,
          TakiSpacing.sm,
          TakiSpacing.lg,
          TakiSpacing.sm,
        ),
      );
    });
  });
}
