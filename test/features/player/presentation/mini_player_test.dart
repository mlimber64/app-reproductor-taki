import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taki/app/app.dart';
import 'package:taki/features/player/domain/entities/playback_state.dart';
import 'package:taki/features/player/presentation/pages/now_playing_page.dart';
import 'package:taki/features/player/presentation/providers/player_providers.dart';
import 'package:taki/features/player/presentation/widgets/mini_player.dart';

import '../../../helpers/library_fakes.dart';
import '../../../helpers/player_fakes.dart';

void main() {
  late FakeAudioPlayerPort player;
  late MockTogglePlayPause togglePlayPause;

  final song = buildSong(
    title: 'Canción de prueba',
    artist: 'Artista de prueba',
    durationMs: 200000,
  );

  setUp(() {
    player = FakeAudioPlayerPort();
    togglePlayPause = MockTogglePlayPause();
    when(() => togglePlayPause()).thenAnswer((_) async {});
  });

  Future<void> pumpApp(WidgetTester tester) async {
    final permission = MockMediaPermission();
    when(permission.isGranted).thenAnswer((_) async => true);
    final songs = MockSongRepository();
    when(songs.getSongs).thenAnswer((_) async => []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...libraryOverrides(
            permission: permission,
            songs: songs,
            player: player,
          ),
          togglePlayPauseProvider.overrideWithValue(togglePlayPause),
        ],
        child: const TakiApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> startSong(WidgetTester tester, {bool isPlaying = false}) async {
    player.emitState(
      PlaybackState(queue: [song], currentIndex: 0, isPlaying: isPlaying),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sin canción actual no ocupa espacio', (tester) async {
    await pumpApp(tester);

    expect(tester.getSize(find.byType(MiniPlayer)).height, 0);
    expect(find.text('Canción de prueba'), findsNothing);
  });

  testWidgets('con canción muestra título y artista', (tester) async {
    await pumpApp(tester);
    await startSong(tester);

    expect(find.text('Canción de prueba'), findsOneWidget);
    expect(find.text('Artista de prueba'), findsOneWidget);
    expect(tester.getSize(find.byType(MiniPlayer)).height, greaterThan(0));
  });

  testWidgets('el botón llama a TogglePlayPause y refleja el estado',
      (tester) async {
    await pumpApp(tester);
    await startSong(tester);

    await tester.tap(find.byTooltip('Reproducir'));
    verify(() => togglePlayPause()).called(1);

    await startSong(tester, isPlaying: true);
    expect(find.byTooltip('Pausar'), findsOneWidget);
  });

  testWidgets('el botón tiene un área táctil de al menos 48', (tester) async {
    await pumpApp(tester);
    await startSong(tester);

    final size = tester.getSize(
      find.ancestor(
        of: find.byTooltip('Reproducir'),
        matching: find.byType(IconButton),
      ),
    );
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('la barra de progreso sigue la posición', (tester) async {
    await pumpApp(tester);
    await startSong(tester);

    player.emitPosition(const Duration(seconds: 50));
    await tester.pump();
    await tester.pump();

    final bar = tester.widget<FractionallySizedBox>(
      find.descendant(
        of: find.byType(MiniPlayer),
        matching: find.byType(FractionallySizedBox),
      ),
    );
    expect(bar.widthFactor, closeTo(0.25, 0.001));
  });

  testWidgets('tocar el cuerpo abre Reproduciendo', (tester) async {
    await pumpApp(tester);
    await startSong(tester);

    await tester.tap(find.text('Canción de prueba'));
    await tester.pumpAndSettle();

    expect(find.byType(NowPlayingPage), findsOneWidget);
    expect(find.text('REPRODUCIENDO DESDE'), findsOneWidget);
  });

  testWidgets('deslizar hacia arriba abre Reproduciendo', (tester) async {
    await pumpApp(tester);
    await startSong(tester);

    await tester.fling(
      find.text('Canción de prueba'),
      const Offset(0, -200),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.byType(NowPlayingPage), findsOneWidget);
  });

  testWidgets('sigue visible al cambiar de pestaña', (tester) async {
    await pumpApp(tester);
    await startSong(tester);

    for (final tab in ['Playlists', 'Favoritos', 'Ajustes']) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(tab),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Canción de prueba'), findsOneWidget, reason: tab);
    }
  });
}
