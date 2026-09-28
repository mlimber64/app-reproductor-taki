import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:taki/app/app.dart';

void main() {
  setUpAll(() {
    // Los tests no tienen red: evita que google_fonts intente descargar.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('la app arranca y muestra las 4 pestañas', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TakiApp()));
    await tester.pumpAndSettle();

    final navBar = find.byType(NavigationBar);
    expect(navBar, findsOneWidget);

    for (final label in ['Biblioteca', 'Playlists', 'Favoritos', 'Ajustes']) {
      expect(
        find.descendant(of: navBar, matching: find.text(label)),
        findsOneWidget,
        reason: 'Falta la pestaña "$label"',
      );
    }

    // Arranca en Biblioteca.
    expect(find.widgetWithText(AppBar, 'Biblioteca'), findsOneWidget);
  });

  testWidgets('navega entre pestañas', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TakiApp()));
    await tester.pumpAndSettle();

    final navBar = find.byType(NavigationBar);
    for (final label in ['Playlists', 'Favoritos', 'Ajustes', 'Biblioteca']) {
      await tester.tap(find.descendant(of: navBar, matching: find.text(label)));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, label), findsOneWidget);
    }
  });
}
