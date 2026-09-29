import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/theme/taki_icon_size.dart';
import 'package:taki/core/theme/taki_motion.dart';
import 'package:taki/core/widgets/taki_playing_indicator.dart';

List<double> _barHeights(WidgetTester tester) => [
      for (final box in tester.widgetList<SizedBox>(find.descendant(
        of: find.byType(Row),
        matching: find.byType(SizedBox),
      )))
        box.height!,
    ];

Future<void> _pump(
  WidgetTester tester, {
  required bool animate,
  bool disableAnimations = false,
}) {
  return tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Center(child: TakiPlayingIndicator(animate: animate)),
      ),
    ),
  );
}

void main() {
  testWidgets('sonando: las barras se mueven', (tester) async {
    await _pump(tester, animate: true);
    final before = _barHeights(tester);
    await tester.pump(TakiMotion.playingLoop * 0.25);
    expect(_barHeights(tester), isNot(before));
  });

  testWidgets('en pausa: quietas a media altura, pero visibles',
      (tester) async {
    await _pump(tester, animate: false);
    final half = TakiIconSize.xs.value / 2;
    expect(_barHeights(tester), [half, half, half]);
    await tester.pump(TakiMotion.playingLoop * 0.25);
    expect(_barHeights(tester), [half, half, half]);
  });

  testWidgets('con animaciones reducidas no se mueven', (tester) async {
    await _pump(tester, animate: true, disableAnimations: true);
    final before = _barHeights(tester);
    await tester.pump(TakiMotion.playingLoop * 0.25);
    expect(_barHeights(tester), before);
  });

  testWidgets('tamaño iconXs y sin semántica propia', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, animate: false);
    expect(
      tester.getSize(find.byType(TakiPlayingIndicator)),
      Size.square(TakiIconSize.xs.value),
    );
    expect(find.byType(ExcludeSemantics), findsOneWidget);
    handle.dispose();
  });
}
