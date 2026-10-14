import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taki/app/app.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/features/player/domain/entities/playback_error.dart';
import 'package:taki/features/player/domain/entities/playback_state.dart';
import 'package:taki/features/player/presentation/pages/now_playing_page.dart';
import 'package:taki/features/player/presentation/widgets/playback_error_listener.dart';

import '../helpers/library_fakes.dart';
import '../helpers/player_fakes.dart';
import '../helpers/universal_song.dart';

/// El consumidor de `PlaybackError` está cableado en la app real (`TakiApp`):
/// el aviso aparece sobre las pestañas y sobre Reproduciendo.
void main() {
  final song = buildUniversalSong(MusicIdentity('jamendo', '1'), title: 'Remota');
  late FakeAudioPlayerPort player;

  setUp(() => player = FakeAudioPlayerPort());

  Future<void> pumpApp(WidgetTester tester) async {
    final permission = MockMediaPermission();
    when(permission.isGranted).thenAnswer((_) async => true);
    final songs = MockSongRepository();
    when(songs.getSongs).thenAnswer((_) async => []);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...libraryOverrides(permission: permission, songs: songs, player: player),
        ],
        child: const TakiApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('un PlaybackError muestra el aviso sobre las pestañas',
      (tester) async {
    await pumpApp(tester);
    player.emitError(PlaybackError(song: song, index: 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(PlaybackErrorTexts.failed), findsOneWidget);
  });

  testWidgets('también sobre Reproduciendo', (tester) async {
    await pumpApp(tester);
    player.emitState(PlaybackState(queue: [song], currentIndex: 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remota'));
    await tester.pumpAndSettle();
    expect(find.byType(NowPlayingPage), findsOneWidget);

    player.emitError(PlaybackError(song: song, index: 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(PlaybackErrorTexts.failed), findsOneWidget);
    expect(find.byType(NowPlayingPage), findsOneWidget); // no se cierra
  });
}
