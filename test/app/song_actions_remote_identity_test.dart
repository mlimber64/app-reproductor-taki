import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taki/app/theme/app_theme.dart';
import 'package:taki/app/widgets/song_actions_sheet.dart';
import 'package:taki/core/artwork/artwork_providers.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/core/domain/entities/song.dart';
import 'package:taki/features/library/presentation/providers/favorites_providers.dart';
import 'package:taki/features/player/presentation/providers/player_providers.dart';
import 'package:taki/features/playlists/presentation/providers/playlists_providers.dart';

import '../helpers/favorites_fakes.dart';
import '../helpers/library_fakes.dart';
import '../helpers/player_fakes.dart';
import '../helpers/playlists_fakes.dart';
import '../helpers/universal_song.dart';

/// 3.2F: el sistema de acciones existente funciona con una canción **remota**
/// sin convertirla en local ni conocer al proveedor: la identidad persistida es
/// `source + external_id` y la cola recibe la misma `Song`.
void main() {
  // La fuente es un texto cualquiera para `core`; aquí hace de proveedor real.
  final identity = MusicIdentity('jamendo', '123');
  final song = buildUniversalSong(identity, title: 'Don\'t Cry');

  late FakeFavoritesRepository favorites;
  late FakePlaylistsRepository playlists;
  late MockPlayNext playNext;
  late MockAddToQueue addToQueue;
  late FakeAudioPlayerPort player;

  setUpAll(() => registerFallbackValue(<Song>[]));

  setUp(() {
    favorites = FakeFavoritesRepository();
    playlists = FakePlaylistsRepository();
    playNext = MockPlayNext();
    addToQueue = MockAddToQueue();
    player = FakeAudioPlayerPort();
    when(() => playNext(any())).thenAnswer((_) async {});
    when(() => addToQueue(any())).thenAnswer((_) async {});
  });

  Future<void> openActions(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          favoritesRepositoryProvider.overrideWithValue(favorites),
          playlistsRepositoryProvider.overrideWithValue(playlists),
          playNextProvider.overrideWithValue(playNext),
          addToQueueProvider.overrideWithValue(addToQueue),
          audioPlayerPortProvider.overrideWithValue(player),
          notificationPermissionProvider
              .overrideWithValue(FakeNotificationPermission()),
          artworkRepositoryProvider.overrideWithValue(NoArtworkRepository()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () => showSongActions(context, ref, song),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('el menú muestra título y las cuatro acciones', (tester) async {
    await openActions(tester);
    expect(find.text('Don\'t Cry'), findsOneWidget);
    expect(find.text('Reproducir a continuación'), findsOneWidget);
    expect(find.text('Añadir a la cola'), findsOneWidget);
    expect(find.text('Añadir a favoritos'), findsOneWidget);
    expect(find.text('Añadir a una playlist'), findsOneWidget);
  });

  testWidgets('favorito: se guarda como jamendo:123, no como local',
      (tester) async {
    await openActions(tester);
    await tester.tap(find.text('Añadir a favoritos'));
    await tester.pumpAndSettle();

    expect(favorites.entries.keys, [identity]);
    expect(favorites.entries[identity]!.musicIdentity.source, 'jamendo');
    expect(favorites.entries[identity]!.path, isNull);
  });

  testWidgets('playlist: la entrada conserva source + external_id',
      (tester) async {
    final id = playlists.seed('Mix');
    await openActions(tester);
    await tester.tap(find.text('Añadir a una playlist'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mix'));
    await tester.pumpAndSettle();

    final entry = playlists.entriesOf(id).single;
    expect(entry.musicIdentity, identity);
    expect(entry.path, isNull);
  });

  testWidgets('reproducir a continuación: la misma canción, sin tocar la cola',
      (tester) async {
    await openActions(tester);
    await tester.tap(find.text('Reproducir a continuación'));
    await tester.pumpAndSettle();

    final songs =
        verify(() => playNext(captureAny())).captured.single as List<Song>;
    expect(songs.single.musicIdentity, identity);
    verifyNever(() => addToQueue(any()));
  });

  testWidgets('añadir a la cola: la misma canción', (tester) async {
    await openActions(tester);
    await tester.tap(find.text('Añadir a la cola'));
    await tester.pumpAndSettle();

    final songs =
        verify(() => addToQueue(captureAny())).captured.single as List<Song>;
    expect(songs.single.musicIdentity, identity);
    verifyNever(() => playNext(any()));
  });
}
