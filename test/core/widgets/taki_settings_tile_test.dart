import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/theme/taki_colors.dart';
import 'package:taki/core/widgets/taki_settings_tile.dart';

import 'widget_test_utils.dart';

void main() {
  testWidgets('shows title and subtitle and reacts to taps', (tester) async {
    var taps = 0;
    await pumpInScreen(
      tester,
      TakiSettingsTile(
        icon: Icons.refresh_rounded,
        title: 'Volver a escanear',
        subtitle: 'Busca cambios',
        onTap: () => taps++,
      ),
    );

    expect(find.text('Volver a escanear'), findsOneWidget);
    expect(find.text('Busca cambios'), findsOneWidget);

    await tester.tap(find.text('Volver a escanear'));
    expect(taps, 1);
  });

  testWidgets('without onTap it is informational', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpInScreen(
      tester,
      const TakiSettingsTile(
        icon: Icons.info_outline_rounded,
        title: 'Versión',
        subtitle: '1.0.0',
      ),
    );

    final node = tester.getSemantics(find.byType(TakiSettingsTile));
    expect(node, isSemantics(label: 'Versión, 1.0.0', isButton: false));
    handle.dispose();
  });

  testWidgets('with onTap it is announced as a button', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpInScreen(
      tester,
      TakiSettingsTile(
        icon: Icons.refresh_rounded,
        title: 'Volver a escanear',
        onTap: () {},
      ),
    );

    final node = tester.getSemantics(find.byType(TakiSettingsTile));
    expect(
      node,
      isSemantics(
        label: 'Volver a escanear',
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('destructive tiles paint the title with the error color',
      (tester) async {
    await pumpInScreen(
      tester,
      TakiSettingsTile(
        icon: Icons.delete_outline_rounded,
        title: 'Vaciar',
        destructive: true,
        onTap: () {},
      ),
    );

    expect(
      tester.widget<Text>(find.text('Vaciar')).style!.color,
      TakiColors.error,
    );
  });

  testWidgets('keeps the minimum touch target and grows with text scale',
      (tester) async {
    await pumpInScreen(
      tester,
      TakiSettingsTile(
        icon: Icons.refresh_rounded,
        title: 'Volver a escanear',
        subtitle: 'Busca canciones nuevas o cambios en tu música',
        onTap: () {},
      ),
      textScale: 1.5,
    );

    final size = tester.getSize(find.byType(TakiSettingsTile));
    expect(size.height, greaterThanOrEqualTo(TakiSettingsTile.minHeight));
    expect(tester.takeException(), isNull);
  });
}
