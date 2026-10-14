import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taki/app/theme/app_theme.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/core/domain/entities/song.dart';
import 'package:taki/features/library/presentation/providers/favorites_providers.dart';
import 'package:taki/features/player/domain/entities/playback_error.dart';
import 'package:taki/features/player/domain/entities/playback_state.dart';
import 'package:taki/features/player/presentation/providers/player_providers.dart';
import 'package:taki/features/player/presentation/widgets/playback_error_listener.dart';
import 'package:taki/features/playlists/presentation/providers/playlists_providers.dart';

import '../../../helpers/favorites_fakes.dart';
import '../../../helpers/player_fakes.dart';
import '../../../helpers/playlists_fakes.dart';
import '../../../helpers/universal_song.dart';

void main() {
  // Canciones remotas de una fuente de prueba (el aviso no distingue fuentes).
  final a = buildUniversalSong(MusicIdentity('jamendo', '1'), title: 'A');
  final b = buildUniversalSong(MusicIdentity('jamendo', '2'), title: 'B');

  late FakeAudioPlayerPort player;
  late FakeFavoritesRepository favorites;
  late FakePlaylistsRepository playlists;
  late ProviderContainer container;

  setUp(() {
    player = FakeAudioPlayerPort();
    favorites = FakeFavoritesRepository();
    playlists = FakePlaylistsRepository();
  });

  Future<void> pump(WidgetTester tester) async {
    container = ProviderContainer(overrides: [
      audioPlayerPortProvider.overrideWithValue(player),
      favoritesRepositoryProvider.overrideWithValue(favorites),
      playlistsRepositoryProvider.overrideWithValue(playlists),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(),
          builder: (context, child) => PlaybackErrorListener(child: child!),
          home: const Scaffold(body: Text('Página')),
        ),
      ),
    );
  }

  /// Emite [error] y deja pasar el frame del SnackBar.
  Future<void> fail(WidgetTester tester, PlaybackError error) async {
    player.emitError(error);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  PlaybackError errorOf(Song song, [int index = 0]) =>
      PlaybackError(song: song, index: index, message: 'detalle técnico https://x');

  Finder skipping() => find.text(PlaybackErrorTexts.skipping);
  Finder failed() => find.text(PlaybackErrorTexts.failed);

  group('mensaje', () {
    test('sin canción ni posición: no hay aviso', () {
      expect(playbackErrorMessage(const PlaybackError(), willSkip: true), isNull);
      expect(
        playbackErrorMessage(const PlaybackError(message: 'x'), willSkip: false),
        isNull,
      );
    });

    test('con canción o con posición: hay aviso; salta o no', () {
      expect(playbackErrorMessage(PlaybackError(song: a), willSkip: true),
          PlaybackErrorTexts.skipping);
      expect(playbackErrorMessage(const PlaybackError(index: 3), willSkip: false),
          PlaybackErrorTexts.failed);
    });

    test('los textos no filtran detalles técnicos', () {
      for (final text in [PlaybackErrorTexts.failed, PlaybackErrorTexts.skipping]) {
        final t = text.toLowerCase();
        for (final banned in ['http', 'jamendo', 'exception', 'error', 'api']) {
          expect(t.contains(banned), isFalse, reason: '$text ~ $banned');
        }
      }
    });
  });

  group('aviso visible', () {
    testWidgets('A: un error con hay siguiente avisa y dice que pasa a la '
        'siguiente (una sola vez)', (tester) async {
      await pump(tester);
      player.emitState(PlaybackState(queue: [a, b], currentIndex: 0));
      await fail(tester, errorOf(a));

      expect(skipping(), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('sin siguiente: mensaje simple, una sola vez', (tester) async {
      await pump(tester);
      player.emitState(PlaybackState(queue: [a], currentIndex: 0));
      await fail(tester, errorOf(a));

      expect(failed(), findsOneWidget);
      expect(skipping(), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('no se muestran detalles del error', (tester) async {
      await pump(tester);
      await fail(tester, errorOf(a));
      expect(find.textContaining('https'), findsNothing);
      expect(find.textContaining('detalle'), findsNothing);
    });

    testWidgets('I: un error sin canción ni posición no genera UI',
        (tester) async {
      await pump(tester);
      await fail(tester, const PlaybackError(message: 'interno'));
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('G: un único evento = un único SnackBar', (tester) async {
      await pump(tester);
      await fail(tester, errorOf(a));
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('varios eventos', () {
    testWidgets('una cascada deja solo el aviso más reciente', (tester) async {
      await pump(tester);
      player.emitState(PlaybackState(queue: [a, b], currentIndex: 0));
      player.emitError(errorOf(a));
      await tester.pump();
      player.emitState(PlaybackState(queue: [a, b], currentIndex: 1));
      await fail(tester, errorOf(b, 1)); // sin siguiente

      expect(find.byType(SnackBar), findsOneWidget);
      expect(failed(), findsOneWidget);
      expect(skipping(), findsNothing);
    });

    testWidgets('la misma canción fallando dos veces: cada intento avisa',
        (tester) async {
      await pump(tester);
      await fail(tester, errorOf(a));
      expect(find.byType(SnackBar), findsOneWidget);

      // Pasa el tiempo del aviso y desaparece.
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);

      // Mismo evento (igual por valor): vuelve a avisar.
      await fail(tester, errorOf(a));
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('no altera nada', () {
    testWidgets('B/C/D/E: favoritos, playlists, identidad y cola intactos',
        (tester) async {
      await pump(tester);
      await favorites.add(a);
      final playlistId = playlists.seed('Mix', songs: [a, b, a]);
      final queue = [a, b, a];
      player.emitState(PlaybackState(queue: queue, currentIndex: 0));
      final calls = List.of(player.calls);

      await fail(tester, errorOf(a));

      expect(favorites.entries.keys, [a.musicIdentity]);
      expect(favorites.relinks, isEmpty);
      expect(playlists.entriesOf(playlistId).map((e) => e.musicIdentity),
          [a.musicIdentity, b.musicIdentity, a.musicIdentity]);
      expect(playlists.relinks, isEmpty);
      expect(player.state.queue, queue); // la cola (con duplicados) no cambia
      expect(player.state.currentSong, a);
      expect(a.musicIdentity, MusicIdentity('jamendo', '1'));
      expect(player.calls, calls); // ni setQueue, ni skip, ni limpiar
    });

    testWidgets('F/H: tras el fallo se puede seguir reproduciendo otra canción',
        (tester) async {
      await pump(tester);
      await fail(tester, errorOf(a));

      await container.read(playSongsProvider).call([b], 0);
      expect(player.calls, contains('setQueue(1, 0)'));
      expect(player.calls, contains('play'));
    });
  });

  testWidgets('al salir la suscripción se cancela (sin avisos ni excepciones)',
      (tester) async {
    await pump(tester);
    await tester.pumpWidget(const SizedBox());
    player.emitError(errorOf(a));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
