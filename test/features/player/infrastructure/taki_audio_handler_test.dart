import 'dart:async';

import 'package:taki/core/domain/entities/local_song.dart';
import 'package:taki/core/domain/entities/artwork_reference.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/features/player/domain/entities/playback_error.dart';
import 'package:taki/features/player/domain/entities/playback_state.dart'
    as player;
import 'package:taki/features/player/infrastructure/artwork_file_cache.dart';
import 'package:taki/features/player/infrastructure/taki_audio_handler.dart';

import '../../../helpers/universal_song.dart';
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
    expect(item.id, 'local/1');
    expect(item.id, TakiAudioHandler.mediaIdFor(songA.musicIdentity));
    expect(item.id, isNot(songA.contentUri));
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

  group('MediaItem.id', () {
    test('identifica la canción, no su recurso: no depende de contentUri',
        () async {
      // Misma identidad, distinta URI de contenido → mismo id.
      final moved = LocalSong(
        id: 1,
        title: 'A',
        artist: null,
        album: null,
        albumId: null,
        artwork: const UnavailableArtworkReference(),
        durationMs: 1,
        path: '',
        contentUri: 'content://otro-volumen/1',
      );
      expect(moved.contentUri, isNot(songA.contentUri));
      expect(
        TakiAudioHandler.mediaIdFor(moved.musicIdentity),
        TakiAudioHandler.mediaIdFor(songA.musicIdentity),
      );

      // Canción de otra fuente sin contentUri: igualmente tiene id.
      final foreign = buildUniversalSong(MusicIdentity('otra', 'abc'));
      await emit(player.PlaybackState(queue: [foreign], currentIndex: 0));
      expect(handler.mediaItem.value!.id, 'otra/abc');
      expect(foreign, isNot(isA<LocalSong>())); // sin datos locales
    });

    test('identidades distintas dan ids distintos', () {
      final ids = {
        TakiAudioHandler.mediaIdFor(MusicIdentity('local', '1')),
        TakiAudioHandler.mediaIdFor(MusicIdentity('local', '2')),
        TakiAudioHandler.mediaIdFor(MusicIdentity('otra', '1')),
      };
      expect(ids, hasLength(3));
    });

    test('sin ambigüedad con separadores dentro de las partes', () {
      // «a/b» + «c» y «a» + «b/c» no pueden colisionar.
      expect(
        TakiAudioHandler.mediaIdFor(MusicIdentity('a/b', 'c')),
        isNot(TakiAudioHandler.mediaIdFor(MusicIdentity('a', 'b/c'))),
      );
      expect(
        TakiAudioHandler.mediaIdFor(MusicIdentity('a:b', 'c')),
        isNot(TakiAudioHandler.mediaIdFor(MusicIdentity('a', 'b:c'))),
      );
    });

    test('el externalId se conserva tal cual (mayúsculas, espacios)', () {
      expect(
        TakiAudioHandler.mediaIdFor(MusicIdentity('s', 'AbC 1')),
        isNot(TakiAudioHandler.mediaIdFor(MusicIdentity('s', 'abc 1'))),
      );
    });

    test('una carátula tardía de la canción anterior no se pega a la actual',
        () async {
      final slow = Completer<Uri?>();
      final uri = Uri.file('/data/cache/artwork/album_10_512.jpg');
      when(() => artwork.artUriFor(songA)).thenAnswer((_) => slow.future);

      await emit(player.PlaybackState(queue: queue, currentIndex: 0));
      await emit(player.PlaybackState(queue: queue, currentIndex: 1));
      slow.complete(uri);
      await pumpEventQueue();

      expect(handler.mediaItem.value!.id, 'local/2');
      expect(handler.mediaItem.value!.artUri, isNull);
    });

    test('canción remota con carátula remota: recibe el artUri file:// que '
        'resuelve la caché', () async {
      final remoteA = buildUniversalSong(
        MusicIdentity('otra', 'a'),
        artwork: RemoteArtworkReference('https://img.test/a.jpg'),
      );
      final uri = Uri.file('/data/cache/artwork/remote_af63dc4c8601ec8c.img');
      when(() => artwork.artUriFor(remoteA)).thenAnswer((_) async => uri);

      await emit(player.PlaybackState(queue: [remoteA], currentIndex: 0));

      final item = handler.mediaItem.value!;
      expect(item.id, 'otra/a');
      expect(item.title, remoteA.title);
      expect(item.artUri, uri);
      expect(item.artUri!.scheme, 'file');
    });

    test('la metadata remota se publica antes de esperar la carátula',
        () async {
      final remoteA = buildUniversalSong(
        MusicIdentity('otra', 'a'),
        artwork: RemoteArtworkReference('https://img.test/a.jpg'),
      );
      final slow = Completer<Uri?>();
      when(() => artwork.artUriFor(remoteA)).thenAnswer((_) => slow.future);

      await emit(player.PlaybackState(queue: [remoteA], currentIndex: 0));

      expect(handler.mediaItem.value!.id, 'otra/a');
      expect(handler.mediaItem.value!.artUri, isNull);
      slow.complete(Uri.file('/c/remote_x.img'));
      await pumpEventQueue();
      expect(handler.mediaItem.value!.artUri, Uri.file('/c/remote_x.img'));
    });

    test('una carátula remota que falla (null) no rompe el MediaItem',
        () async {
      final remoteA = buildUniversalSong(
        MusicIdentity('otra', 'a'),
        artwork: RemoteArtworkReference('https://img.test/a.jpg'),
      );
      when(() => artwork.artUriFor(remoteA)).thenAnswer((_) async => null);

      await emit(player.PlaybackState(queue: [remoteA], currentIndex: 0));

      expect(handler.mediaItem.value!.id, 'otra/a');
      expect(handler.mediaItem.value!.artUri, isNull);
    });

    test('A → B con carátulas remotas: la tardía de A nunca se publica sobre B',
        () async {
      final remoteA = buildUniversalSong(
        MusicIdentity('otra', 'a'),
        artwork: RemoteArtworkReference('https://img.test/a.jpg'),
      );
      final remoteB = buildUniversalSong(
        MusicIdentity('otra', 'b'),
        artwork: RemoteArtworkReference('https://img.test/b.jpg'),
      );
      final slowA = Completer<Uri?>();
      final uriA = Uri.file('/c/remote_a.img');
      final uriB = Uri.file('/c/remote_b.img');
      when(() => artwork.artUriFor(remoteA)).thenAnswer((_) => slowA.future);
      when(() => artwork.artUriFor(remoteB)).thenAnswer((_) async => uriB);

      await emit(player.PlaybackState(queue: [remoteA, remoteB], currentIndex: 0));
      await emit(player.PlaybackState(queue: [remoteA, remoteB], currentIndex: 1));
      expect(handler.mediaItem.value!.artUri, uriB);

      slowA.complete(uriA); // llega tarde
      await pumpEventQueue();

      expect(handler.mediaItem.value!.id, 'otra/b');
      expect(handler.mediaItem.value!.artUri, uriB);
    });

    test('la carátula de la canción actual sí se adjunta, conservando el id',
        () async {
      final uri = Uri.file('/data/cache/artwork/album_10_512.jpg');
      when(() => artwork.artUriFor(songA)).thenAnswer((_) async => uri);

      await emit(player.PlaybackState(queue: queue, currentIndex: 0));

      expect(handler.mediaItem.value!.id, 'local/1');
      expect(handler.mediaItem.value!.artUri, uri);
    });
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
    expect(handler.mediaItem.value!.id, 'local/2');
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
