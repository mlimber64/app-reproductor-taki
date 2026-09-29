import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taki/features/library/domain/entities/song.dart';
import 'package:taki/features/player/domain/entities/playback_state.dart';
import 'package:taki/features/player/domain/usecases/player_usecases.dart';

import '../../../helpers/library_fakes.dart';
import '../../../helpers/player_fakes.dart';

void main() {
  late MockAudioPlayerPort player;

  setUpAll(() {
    registerFallbackValue(RepeatMode.off);
    registerFallbackValue(Duration.zero);
    registerFallbackValue(<Song>[]);
  });

  setUp(() {
    player = MockAudioPlayerPort();
    for (final stub in <Future<void> Function()>[
      player.play,
      player.pause,
      player.skipToNext,
      player.skipToPrevious,
    ]) {
      when(stub).thenAnswer((_) async {});
    }
    when(() => player.setQueue(any(), startIndex: any(named: 'startIndex')))
        .thenAnswer((_) async {});
    when(() => player.seek(any())).thenAnswer((_) async {});
    when(() => player.setShuffle(any())).thenAnswer((_) async {});
    when(() => player.setRepeatMode(any())).thenAnswer((_) async {});
    when(() => player.skipToIndex(any())).thenAnswer((_) async {});
    when(() => player.removeFromQueue(any())).thenAnswer((_) async {});
    when(() => player.moveInQueue(any(), any())).thenAnswer((_) async {});
    when(() => player.addToQueue(any())).thenAnswer((_) async {});
    when(() => player.playNext(any())).thenAnswer((_) async {});
    when(player.clearUpcoming).thenAnswer((_) async {});
  });

  void givenState(PlaybackState state) =>
      when(() => player.state).thenReturn(state);

  test('PlaySongs pone la cola desde el índice y luego reproduce', () async {
    final songs = [buildSong(id: 1), buildSong(id: 2), buildSong(id: 3)];

    await PlaySongs(player)(songs, 2);

    verifyInOrder([
      () => player.setQueue(songs, startIndex: 2),
      () => player.play(),
    ]);
  });

  test('PlaySongsShuffled activa aleatorio antes de empezar', () async {
    final songs = [for (var i = 0; i < 5; i++) buildSong(id: i)];
    final expectedStart = Random(3).nextInt(songs.length);

    await PlaySongsShuffled(player, random: Random(3))(songs);

    verifyInOrder([
      () => player.setShuffle(true),
      () => player.setQueue(songs, startIndex: expectedStart),
      () => player.play(),
    ]);
  });

  test('PlaySongsShuffled ignora listas vacías', () async {
    await PlaySongsShuffled(player)(const []);
    verifyNever(() => player.setShuffle(any()));
  });

  group('TogglePlayPause', () {
    test('pausa si está sonando', () async {
      givenState(const PlaybackState(isPlaying: true));
      await TogglePlayPause(player)();
      verify(player.pause).called(1);
      verifyNever(player.play);
    });

    test('reproduce si está en pausa', () async {
      givenState(const PlaybackState(isPlaying: false));
      await TogglePlayPause(player)();
      verify(player.play).called(1);
      verifyNever(player.pause);
    });
  });

  test('SkipNext, SkipPrevious y Seek delegan en el port', () async {
    await SkipNext(player)();
    await SkipPrevious(player)();
    await Seek(player)(const Duration(seconds: 42));

    verify(player.skipToNext).called(1);
    verify(player.skipToPrevious).called(1);
    verify(() => player.seek(const Duration(seconds: 42))).called(1);
  });

  test('ToggleShuffle invierte el estado actual', () async {
    givenState(const PlaybackState(shuffleEnabled: false));
    await ToggleShuffle(player)();
    verify(() => player.setShuffle(true)).called(1);

    givenState(const PlaybackState(shuffleEnabled: true));
    await ToggleShuffle(player)();
    verify(() => player.setShuffle(false)).called(1);
  });

  test('CycleRepeatMode recorre off → all → one → off', () async {
    const transitions = {
      RepeatMode.off: RepeatMode.all,
      RepeatMode.all: RepeatMode.one,
      RepeatMode.one: RepeatMode.off,
    };

    for (final MapEntry(key: from, value: to) in transitions.entries) {
      givenState(PlaybackState(repeatMode: from));
      await CycleRepeatMode(player)();
      verify(() => player.setRepeatMode(to)).called(1);
    }
  });

  group('cola', () {
    // Cola A B C D E sonando C (índice 2): lo que viene es D (3) y E (4).
    final queue = [
      for (var i = 0; i < 5; i++) buildSong(id: i, title: 'ABCDE'[i]),
    ];
    final playing = PlaybackState(queue: queue, currentIndex: 2);
    final newSongs = [buildSong(id: 10), buildSong(id: 11)];

    test('SkipToQueueItem delega si el índice existe', () async {
      givenState(playing);
      await SkipToQueueItem(player)(4);
      await SkipToQueueItem(player)(5);
      verify(() => player.skipToIndex(4)).called(1);
      verifyNever(() => player.skipToIndex(5));
    });

    test('RemoveFromQueue solo quita lo que viene', () async {
      givenState(playing);
      for (final index in [0, 2, 3, 5, -1]) {
        await RemoveFromQueue(player)(index);
      }
      verify(() => player.removeFromQueue(3)).called(1);
      for (final index in [0, 2, 5, -1]) {
        verifyNever(() => player.removeFromQueue(index));
      }
    });

    test('MoveInQueue solo mueve dentro de lo que viene', () async {
      givenState(playing);
      await MoveInQueue(player)(3, 4);
      await MoveInQueue(player)(2, 4); // la actual
      await MoveInQueue(player)(4, 1); // antes de la actual
      await MoveInQueue(player)(3, 3); // sin cambio
      await MoveInQueue(player)(4, 5); // fuera de rango

      verify(() => player.moveInQueue(3, 4)).called(1);
      verifyNever(() => player.moveInQueue(2, 4));
      verifyNever(() => player.moveInQueue(4, 1));
      verifyNever(() => player.moveInQueue(4, 5));
    });

    test('AddToQueue añade al final si algo suena', () async {
      givenState(playing);
      await AddToQueue(player)(newSongs);
      verify(() => player.addToQueue(newSongs)).called(1);
      verifyNever(player.play);
    });

    test('PlayNext inserta después de la actual si algo suena', () async {
      givenState(playing);
      await PlayNext(player)(newSongs);
      verify(() => player.playNext(newSongs)).called(1);
      verifyNever(player.play);
    });

    for (final (name, useCase) in [
      ('AddToQueue', (MockAudioPlayerPort p) => AddToQueue(p).call),
      ('PlayNext', (MockAudioPlayerPort p) => PlayNext(p).call),
    ]) {
      test('$name sin canción actual reproduce desde la primera añadida',
          () async {
        givenState(PlaybackState.empty);
        await useCase(player)(newSongs);

        verifyInOrder([
          () => player.setQueue(newSongs, startIndex: 0),
          () => player.play(),
        ]);
        verifyNever(() => player.addToQueue(any()));
        verifyNever(() => player.playNext(any()));
      });
    }

    test('AddToQueue y PlayNext ignoran listas vacías', () async {
      givenState(playing);
      await AddToQueue(player)(const []);
      await PlayNext(player)(const []);
      verifyNever(() => player.addToQueue(any()));
      verifyNever(() => player.playNext(any()));
    });

    test('ClearUpcoming solo actúa si hay algo por venir', () async {
      givenState(playing);
      await ClearUpcoming(player)();
      verify(player.clearUpcoming).called(1);

      givenState(PlaybackState(queue: queue, currentIndex: 4));
      await ClearUpcoming(player)();
      verifyNever(player.clearUpcoming);
    });
  });
}
