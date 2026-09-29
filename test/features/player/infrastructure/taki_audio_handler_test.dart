import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taki/features/player/domain/entities/playback_error.dart';
import 'package:taki/features/player/domain/entities/playback_state.dart'
    as player;
import 'package:taki/features/player/infrastructure/artwork_file_cache.dart';
import 'package:taki/features/player/infrastructure/taki_audio_handler.dart';

import '../../../helpers/library_fakes.dart';
import '../../../helpers/player_fakes.dart';

class MockArtworkFileCache extends Mock implements ArtworkFileCache {}

void main() {
  late FakeAudioPlayerPort port;
  late MockArtworkFileCache artwork;
  late TakiAudioHandler handler;

  final songA = buildSong(id: 1, title: 'A', artist: 'Artista A');
  final songB = buildSong(id: 2, title: 'B', artist: null);
  final queue = [songA, songB];

  setUpAll(() => registerFallbackValue(buildSong()));

  setUp(() {
    port = FakeAudioPlayerPort();
    artwork = MockArtworkFileCache();
    when(() => artwork.artUriFor(any())).thenAnswer((_) async => null);
    handler = TakiAudioHandler(port, artwork);
  });

  tearDown(() => handler.dispose());

  Future<void> emit(player.PlaybackState state) async {
    port.emitState(state);
    await pumpEventQueue();
  }

  test('sin cola, audio_service queda en idle', () {
    expect(handler.playbackState.value.processingState,
        AudioProcessingState.idle);
    expect(handler.playbackState.value.playing, isFalse);
  });

  test('un cambio de estado del port se refleja en audio_service', () async {
    await emit(
      player.PlaybackState(
        queue: queue,
        currentIndex: 1,
        isPlaying: true,
        position: const Duration(seconds: 42),
        shuffleEnabled: true,
        repeatMode: player.RepeatMode.one,
      ),
    );

    final state = handler.playbackState.value;
    expect(state.playing, isTrue);
    expect(state.processingState, AudioProcessingState.ready);
    expect(state.queueIndex, 1);
    expect(state.updatePosition, const Duration(seconds: 42));
    expect(state.shuffleMode, AudioServiceShuffleMode.all);
    expect(state.repeatMode, AudioServiceRepeatMode.one);
    // Última de la cola, sin repetir todo: hay anterior pero no siguiente.
    expect(state.controls, [MediaControl.skipToPrevious, MediaControl.pause]);
    expect(state.systemActions, contains(MediaAction.seek));
    expect(state.androidCompactActionIndices, [0, 1]);
  });

  group('siguiente y anterior tras cambios de cola', () {
    final songC = buildSong(id: 3, title: 'C');

    Future<List<MediaControl>> controlsFor(player.PlaybackState state) async {
      await emit(state);
      return handler.playbackState.value.controls;
    }

    test('"anterior" siempre; "siguiente" solo si hay algo después',
        () async {
      final three = [songA, songB, songC];

      // Primera canción: "anterior" sigue ahí (reinicia la canción).
      expect(
        await controlsFor(player.PlaybackState(queue: three, currentIndex: 0)),
        [
          MediaControl.skipToPrevious,
          MediaControl.play,
          MediaControl.skipToNext,
        ],
      );
      expect(
        await controlsFor(player.PlaybackState(queue: three, currentIndex: 1)),
        [
          MediaControl.skipToPrevious,
          MediaControl.play,
          MediaControl.skipToNext,
        ],
      );
      expect(handler.playbackState.value.androidCompactActionIndices,
          [0, 1, 2]);

      expect(
        await controlsFor(player.PlaybackState(queue: three, currentIndex: 2)),
        [MediaControl.skipToPrevious, MediaControl.play],
      );
      expect(handler.playbackState.value.androidCompactActionIndices, [0, 1]);
    });

    test('una sola canción: "anterior" sigue habilitado', () async {
      expect(
        await controlsFor(player.PlaybackState(queue: [songA], currentIndex: 0)),
        [MediaControl.skipToPrevious, MediaControl.play],
      );
    });

    test('sin canción no hay "anterior"', () {
      expect(handler.playbackState.value.controls, [MediaControl.play]);
    });

    test('al limpiar lo que viene desaparece "siguiente"', () async {
      await emit(player.PlaybackState(queue: queue, currentIndex: 0));
      expect(handler.playbackState.value.controls,
          contains(MediaControl.skipToNext));

      await port.clearUpcoming();
      await pumpEventQueue();

      expect(handler.playbackState.value.controls,
          [MediaControl.skipToPrevious, MediaControl.play]);
    });

    test('al añadir a la cola vuelve "siguiente"', () async {
      await emit(player.PlaybackState(queue: [songA], currentIndex: 0));
      expect(handler.playbackState.value.controls,
          [MediaControl.skipToPrevious, MediaControl.play]);

      await port.addToQueue([songC]);
      await pumpEventQueue();

      expect(handler.playbackState.value.controls, [
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.skipToNext,
      ]);
    });

    test('con repetir todo siempre hay siguiente y anterior', () async {
      await emit(player.PlaybackState(
        queue: queue,
        currentIndex: 1,
        repeatMode: player.RepeatMode.all,
      ));
      expect(handler.playbackState.value.controls, [
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.skipToNext,
      ]);
    });
  });

  test('en pausa muestra el botón play; cargando pasa a buffering', () async {
    await emit(player.PlaybackState(
      queue: queue,
      currentIndex: 0,
      isBuffering: true,
    ));

    final state = handler.playbackState.value;
    expect(state.controls, contains(MediaControl.play));
    expect(state.controls, isNot(contains(MediaControl.pause)));
    expect(state.processingState, AudioProcessingState.buffering);
  });

  test('publica el MediaItem de la canción actual', () async {
    await emit(player.PlaybackState(queue: queue, currentIndex: 0));

    final item = handler.mediaItem.value!;
    expect(item.id, songA.contentUri);
    expect(item.title, 'A');
    expect(item.artist, 'Artista A');
    expect(item.album, songA.album);
    expect(item.duration, songA.duration);
    expect(item.artUri, isNull);
  });

  test('añade artUri cuando la carátula está en caché', () async {
    final uri = Uri.file('/data/cache/artwork/album_10_512.jpg');
    when(() => artwork.artUriFor(songA)).thenAnswer((_) async => uri);

    await emit(player.PlaybackState(queue: queue, currentIndex: 0));

    expect(handler.mediaItem.value!.artUri, uri);
  });

  test('un error de canción no rompe la cola', () async {
    await emit(
      player.PlaybackState(queue: queue, currentIndex: 0, isPlaying: true),
    );

    // La canción A falla; el port salta a B y sigue sonando.
    port.emitError(PlaybackError(song: songA, index: 0, message: 'borrado'));
    await emit(
      player.PlaybackState(queue: queue, currentIndex: 1, isPlaying: true),
    );

    final state = handler.playbackState.value;
    expect(state.processingState, AudioProcessingState.ready);
    expect(state.playing, isTrue);
    expect(state.queueIndex, 1);
    expect(handler.mediaItem.value!.id, songB.contentUri);
    expect(port.calls, isNot(contains('stop')));

    // Los controles siguen funcionando.
    await handler.skipToPrevious();
    expect(port.calls, contains('skipToPrevious'));
  });

  group('comandos del sistema', () {
    test('se reenvían al port', () async {
      await handler.play();
      await handler.pause();
      await handler.seek(const Duration(seconds: 30));
      await handler.skipToNext();
      await handler.skipToQueueItem(3);
      await handler.setShuffleMode(AudioServiceShuffleMode.all);
      await handler.setRepeatMode(AudioServiceRepeatMode.all);

      expect(port.calls, [
        'play',
        'pause',
        'seek(30s)',
        'skipToNext',
        'skipToIndex(3)',
        'setShuffle(true)',
        'setRepeatMode(all)',
      ]);
    });

    test('el botón de auriculares alterna play/pausa', () async {
      await emit(
        player.PlaybackState(queue: queue, currentIndex: 0, isPlaying: true),
      );
      await handler.click();
      expect(port.calls.last, 'pause');

      await emit(player.PlaybackState(queue: queue, currentIndex: 0));
      await handler.click();
      expect(port.calls.last, 'play');

      await handler.click(MediaButton.next);
      expect(port.calls.last, 'skipToNext');
    });
  });

  group('cerrar la app desde recientes', () {
    test('si está sonando, sigue', () async {
      await emit(
        player.PlaybackState(queue: queue, currentIndex: 0, isPlaying: true),
      );
      await handler.onTaskRemoved();
      expect(port.calls, isNot(contains('stop')));
    });

    test('si está en pausa, se detiene y libera el servicio', () async {
      await emit(player.PlaybackState(queue: queue, currentIndex: 0));
      await handler.onTaskRemoved();
      expect(port.calls, contains('stop'));
      expect(handler.playbackState.value.processingState,
          AudioProcessingState.idle);
    });
  });
}
