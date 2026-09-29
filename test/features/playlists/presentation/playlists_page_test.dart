import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taki/app/app.dart';
import 'package:taki/features/playlists/presentation/pages/playlist_detail_page.dart';

import '../../../helpers/library_fakes.dart';
import '../../../helpers/playlists_fakes.dart';

void main() {
  late FakePlaylistsRepository playlists;

  final a = buildSong(id: 1, title: 'A', durationMs: 120000);
  final b = buildSong(id: 2, title: 'B', durationMs: 180000);

  setUp(() => playlists = FakePlaylistsRepository());

  /// Abre la app y va a la pestaña Playlists.
  Future<void> openPlaylistsTab(WidgetTester tester) async {
    final permission = MockMediaPermission();
    when(permission.isGranted).thenAnswer((_) async => true);
    final library = MockSongRepository();
    when(library.getSongs).thenAnswer((_) async => [a, b]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: libraryOverrides(
          permission: permission,
          songs: library,
          playlists: playlists,
        ),
        child: const TakiApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Playlists'),
      ),
    );
    await tester.pumpAndSettle();
  }

  TextButton dialogButton(WidgetTester tester, String label) =>
      tester.widget<TextButton>(find.widgetWithText(TextButton, label));

  testWidgets('estado vacío', (tester) async {
    await openPlaylistsTab(tester);

    expect(find.text('Nueva playlist'), findsOneWidget);
    expect(
      find.text('Aún no tienes playlists. Crea la primera para agrupar tus '
          'canciones.'),
      findsOneWidget,
    );
  });

  testWidgets('crear valida el nombre y abre el detalle', (tester) async {
    await openPlaylistsTab(tester);

    await tester.tap(find.text('Nueva playlist'));
    await tester.pumpAndSettle();
    expect(find.text('Crear'), findsOneWidget);
    expect(dialogButton(tester, 'Crear').onPressed, isNull);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(find.text('Escribe un nombre'), findsOneWidget);
    expect(dialogButton(tester, 'Crear').onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'x' * 61);
    await tester.pump();
    expect(find.text('Máximo 60 caracteres'), findsOneWidget);
    expect(dialogButton(tester, 'Crear').onPressed, isNull);

    await tester.enterText(find.byType(TextField), '  Para correr ');
    await tester.pump();
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();

    expect(playlists.namesInOrder(), ['Para correr']);
    expect(find.byType(PlaylistDetailPage), findsOneWidget);
    expect(find.text('PLAYLIST'), findsOneWidget);
    // El detalle está dentro de la pestaña: la barra inferior sigue visible.
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('lista las playlists con su resumen', (tester) async {
    playlists
      ..seed('Vacía')
      ..seed('Con canciones', songs: [a, b]);
    await openPlaylistsTab(tester);

    expect(find.text('TUS PLAYLISTS'), findsOneWidget);
    expect(find.text('2 canciones · 5 min'), findsOneWidget);
    expect(find.text('0 canciones'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Con canciones')).dy,
      lessThan(tester.getTopLeft(find.text('Vacía')).dy),
      reason: 'la modificada más recientemente primero',
    );
  });

  testWidgets('renombrar desde la pulsación larga', (tester) async {
    playlists.seed('Vieja');
    await openPlaylistsTab(tester);

    await tester.longPress(find.text('Vieja'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Renombrar'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Vieja',
    );
    await tester.enterText(find.byType(TextField), 'Nueva');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(playlists.namesInOrder(), ['Nueva']);
    expect(find.text('Nueva'), findsOneWidget);
  });

  testWidgets('eliminar pide confirmación', (tester) async {
    playlists.seed('Adiós');
    await openPlaylistsTab(tester);

    await tester.longPress(find.text('Adiós'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar «Adiós»?'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(playlists.namesInOrder(), ['Adiós']);

    await tester.longPress(find.text('Adiós'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(playlists.namesInOrder(), isEmpty);
    expect(find.text('Playlist eliminada'), findsOneWidget);
  });

  testWidgets('base no disponible: error y Reintentar', (tester) async {
    playlists
      ..seed('Guardada')
      ..failing = true;
    await openPlaylistsTab(tester);

    expect(find.text('Playlists no disponibles'), findsOneWidget);

    playlists.failing = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Guardada'), findsOneWidget);
  });
}
