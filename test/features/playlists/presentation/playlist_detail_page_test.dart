import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taki/app/theme/app_theme.dart';
import 'package:taki/app/widgets/song_actions_sheet.dart';
import 'package:taki/core/domain/entities/song.dart';
import 'package:taki/features/player/presentation/providers/player_providers.dart';
import 'package:taki/features/playlists/presentation/pages/playlist_detail_page.dart';
import 'package:taki/features/playlists/presentation/providers/playlists_providers.dart';

import '../../../helpers/library_fakes.dart';
import '../../../helpers/player_fakes.dart';
import '../../../helpers/playlists_fakes.dart';

void main() {
  late FakePlaylistsRepository playlists;
  late MockSongRepository library;
  late MockPlaySongs playSongs;

  final a = buildSong(id: 1, title: 'A', durationMs: 60000);
  final b = buildSong(id: 2, title: 'B', durationMs: 120000);
  final c = buildSong(id: 3, title: 'C', durationMs: 180000);
  final d = buildSong(id: 4, title: 'D', durationMs: 240000);
  final missing = buildSong(id: 9, title: 'Borrada', durationMs: 1000);

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    registerFallbackValue(<Song>[]);
  });

  setUp(() {
    playlists = FakePlaylistsRepository();
    library = MockSongRepository();
    when(library.getSongs).thenAnswer((_) async => [a, b, c, d]);
    playSongs = MockPlaySongs();
    when(() => playSongs(any(), any())).thenAnswer((_) async {});
  });

  /// Abre el detalle de [playlistId] sobre una página base.
  Future<void> openDetail(
    WidgetTester tester,
    int playlistId, {
    List<Override> overrides = const [],
  }) async {
    final permission = MockMediaPermission();
    when(permission.isGranted).thenAnswer((_) async => true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...libraryOverrides(
            permission: permission,
            songs: library,
            playlists: playlists,
          ),
          playSongsProvider.overrideWithValue(playSongs),
          ...overrides,
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PlaylistDetailPage(
                      playlistId: playlistId,
                      onSongActions: showSongActions,
                    ),
                  ),
                ),
                child: const Text('Base'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Base'));
    await tester.pumpAndSettle();
  }

  Finder moreButtonOf(String title) => find.descendant(
        of: find.ancestor(of: find.text(title), matching: find.byType(Row))
            .first,
        matching: find.byTooltip('Más opciones'),
      );

  List<int> storedSongIds(int id) =>
      [for (final e in playlists.entriesOf(id)) e.songId];

  testWidgets('encabezado y canciones en orden; oculta las ausentes',
      (tester) async {
    final id = playlists.seed('Mi mix', songs: [c, missing, a]);
    await openDetail(tester, id);

    expect(find.text('PLAYLIST'), findsOneWidget);
    expect(find.text('Mi mix'), findsOneWidget);
    expect(find.text('2 canciones · 4 min'), findsOneWidget);
    expect(find.text('Borrada'), findsNothing);
    expect(
      tester.getTopLeft(find.text('C')).dy,
      lessThan(tester.getTopLeft(find.text('A')).dy),
    );
    expect(storedSongIds(id), [3, 9, 1], reason: 'la ausente no se borra');
  });

  testWidgets('Reproducir y tocar una canción usan la lista visible',
      (tester) async {
    final id = playlists.seed('Mi mix', songs: [c, missing, a]);
    await openDetail(tester, id);

    await tester.tap(find.text('Reproducir'));
    await tester.pumpAndSettle();
    verify(() => playSongs([c, a], 0)).called(1);

    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    verify(() => playSongs([c, a], 1)).called(1);
  });

  testWidgets('quitar y Deshacer', (tester) async {
    final id = playlists.seed('Mi mix', songs: [a, b, c]);
    await openDetail(tester, id);

    await tester.tap(moreButtonOf('B'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitar de la playlist'));
    await tester.pumpAndSettle();

    expect(storedSongIds(id), [1, 3]);
    expect(find.text('B'), findsNothing);
    expect(find.text('Quitada de la playlist'), findsOneWidget);

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();

    expect(storedSongIds(id), [1, 2, 3]);
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('reordenar traduce a las posiciones reales de la playlist',
      (tester) async {
    // Visible: A (pos 0), C (pos 2), D (pos 3); la borrada ocupa la pos 1.
    final id = playlists.seed('Mi mix', songs: [a, missing, c, d]);
    final move = MockMovePlaylistSong();
    when(() => move(any(), any(), any())).thenAnswer((_) async {});
    await openDetail(
      tester,
      id,
      overrides: [movePlaylistSongProvider.overrideWithValue(move)],
    );

    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    // A (fila 0) soltada después de C (fila 1): Flutter informa (0, 2).
    list.onReorder(0, 2);
    await tester.pump();
    verify(() => move(id, 0, 2)).called(1);

    // D (fila 2) soltada al principio: pasa a la posición de A.
    list.onReorder(2, 0);
    await tester.pump();
    verify(() => move(id, 3, 0)).called(1);
  });

  testWidgets('arrastrar el asa reordena la playlist guardada',
      (tester) async {
    final id = playlists.seed('Mi mix', songs: [a, b, c]);
    await openDetail(tester, id);

    final handle = find.descendant(
      of: find.ancestor(of: find.text('A'), matching: find.byType(Row)).first,
      matching: find.byIcon(Icons.drag_handle_rounded),
    );
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 100));
    // Una fila (64 px) y un poco más: A queda después de B.
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(0, 12));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(storedSongIds(id), [2, 1, 3]);
  });

  testWidgets('añadir a otra playlist desde el menú de una canción',
      (tester) async {
    final id = playlists.seed('Mi mix', songs: [a]);
    playlists.seed('Otra', songs: [a]);
    final otra = id + 1;
    await openDetail(tester, id);

    await tester.tap(moreButtonOf('A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Añadir a una playlist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Otra'));
    await tester.pumpAndSettle();

    expect(storedSongIds(otra), [1, 1]);
    expect(
      find.text('Ya estaba en «Otra»; se añadió otra vez'),
      findsOneWidget,
    );
  });

  testWidgets('eliminar desde el menú del encabezado vuelve atrás',
      (tester) async {
    final id = playlists.seed('Mi mix', songs: [a]);
    await openDetail(tester, id);

    await tester.tap(find.byTooltip('Opciones de la playlist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar playlist'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(playlists.namesInOrder(), isEmpty);
    expect(find.byType(PlaylistDetailPage), findsNothing);
    expect(find.text('Playlist eliminada'), findsOneWidget);
  });

  testWidgets('estado vacío', (tester) async {
    final id = playlists.seed('Nueva');
    await openDetail(tester, id);

    expect(
      find.text('Esta playlist está vacía. Añade canciones desde la '
          'Biblioteca.'),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton).first).onPressed,
      isNull,
    );
  });

  testWidgets('base no disponible: error y Reintentar', (tester) async {
    final id = playlists.seed('Mi mix', songs: [a]);
    playlists.failing = true;
    await openDetail(tester, id);

    expect(find.text('Playlist no disponible'), findsOneWidget);

    playlists.failing = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Mi mix'), findsOneWidget);
  });
}
