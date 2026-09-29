import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:taki/features/library/domain/entities/song.dart';
import 'package:taki/features/player/domain/entities/playback_error.dart';
import 'package:taki/features/player/domain/entities/playback_state.dart';
import 'package:taki/features/player/infrastructure/just_audio_player_adapter.dart';

import '../../../helpers/fake_just_audio_player.dart';
import '../../../helpers/library_fakes.dart';

void main() {
  late FakeJustAudioPlayer player;
  late JustAudioPlayerAdapter adapter;

  final a = buildSong(id: 1, title: 'A');
  final b = buildSong(id: 2, title: 'B');
  final c = buildSong(id: 3, title: 'C');
  final d = buildSong(id: 4, title: 'D');
  final e = buildSong(id: 5, title: 'E');
  final x = buildSong(id: 10, title: 'X');
  final y = buildSong(id: 11, title: 'Y');
  final songs = [a, b, c, d, e];

  setUp(() {
    player = FakeJustAudioPlayer();
    adapter = JustAudioPlayerAdapter(player: player);
  });

  tearDown(() => player.close());

  List<String> titles(List<Song> list) => [for (final s in list) s.title];

  /// Canción actual una vez que el reproductor avisó del cambio.
  Future<Song?> current() async {
    await pumpEventQueue();
    return adapter.state.currentSong;
  }
  List<String> queueTitles() => titles(adapter.state.queue);

  group('setQueue', () {
    test('usa los content URI, perezosa y desde el índice', () async {
      await adapter.setQueue(songs, startIndex: 2);

      expect(
        player.sources.map((s) => (s as UriAudioSource).uri.toString()),
        songs.map((s) => s.contentUri),
      );
      expect(adapter.state.queue, songs);
      expect(adapter.state.currentSong, c);
    });

    test('con una cola vacía no hay canción actual', () async {
      await adapter.setQueue(const []);
      expect(adapter.state.queue, isEmpty);
      expect(adapter.state.currentSong, isNull);
    });
  });

  group('removeFromQueue', () {
    setUp(() => adapter.setQueue(songs, startIndex: 1));

    test('quita lo que viene, sin tocar la actual', () async {
      await adapter.removeFromQueue(3);

      expect(queueTitles(), ['A', 'B', 'C', 'E']);
      expect(adapter.state.currentSong, b);
      expect(player.log, isNot(contains(startsWith('seek'))));
    });

    test('ignora la actual, las ya reproducidas y fuera de rango', () async {
      for (final index in [1, 0, -1, 5, 99]) {
        await adapter.removeFromQueue(index);
      }
      expect(queueTitles(), ['A', 'B', 'C', 'D', 'E']);
    });

    test('cada cambio publica una lista nueva', () async {
      final before = adapter.state.queue;
      await adapter.removeFromQueue(2);
      expect(identical(before, adapter.state.queue), isFalse);
    });
  });

  group('moveInQueue', () {
    setUp(() => adapter.setQueue(songs));

    test('mueve lo que viene a su posición final', () async {
      await adapter.moveInQueue(1, 3);
      expect(queueTitles(), ['A', 'C', 'D', 'B', 'E']);

      await adapter.moveInQueue(4, 1);
      expect(queueTitles(), ['A', 'E', 'C', 'D', 'B']);
      expect(adapter.state.currentSong, a);
    });

    test('no mueve la actual ni lleva nada antes de ella', () async {
      await adapter.moveInQueue(0, 2);
      await adapter.moveInQueue(2, 0);
      await adapter.moveInQueue(1, 9);
      expect(queueTitles(), ['A', 'B', 'C', 'D', 'E']);
    });
  });

  group('addToQueue', () {
    test('añade al final', () async {
      await adapter.setQueue(songs, startIndex: 1);
      await adapter.addToQueue([x, y]);

      expect(queueTitles(), ['A', 'B', 'C', 'D', 'E', 'X', 'Y']);
      expect(adapter.state.currentSong, b);
    });

    test('con la cola vacía, las añadidas pasan a ser la cola', () async {
      await adapter.addToQueue([x, y]);

      expect(queueTitles(), ['X', 'Y']);
      expect(adapter.state.currentSong, x);
    });
  });

  group('playNext', () {
    test('inserta justo después de la actual', () async {
      await adapter.setQueue(songs, startIndex: 1);
      await adapter.playNext([x, y]);

      expect(queueTitles(), ['A', 'B', 'X', 'Y', 'C', 'D', 'E']);
      expect(adapter.state.currentSong, b);
    });

    test('con la cola vacía, las añadidas pasan a ser la cola', () async {
      await adapter.playNext([x]);
      expect(queueTitles(), ['X']);
      expect(adapter.state.currentSong, x);
    });
  });

  group('clearUpcoming', () {
    test('quita todo lo que viene y deja la actual', () async {
      await adapter.setQueue(songs, startIndex: 1);
      await adapter.clearUpcoming();

      expect(queueTitles(), ['A', 'B']);
      expect(adapter.state.currentSong, b);
      expect(adapter.state.hasNext, isFalse);
      // Sin aleatorio, lo que viene es un solo tramo: una sola llamada.
      expect(
        player.log.where((l) => l.startsWith('removeAudioSourceRange')),
        ['removeAudioSourceRange(2, 5)'],
      );
    });

    test('sin nada por venir no hace nada', () async {
      await adapter.setQueue(songs, startIndex: 4);
      await adapter.clearUpcoming();
      expect(queueTitles(), ['A', 'B', 'C', 'D', 'E']);
    });
  });

  group('con aleatorio', () {
    setUp(() async {
      await adapter.setQueue(songs, startIndex: 2);
      await adapter.setShuffle(true);
    });

    test('la cola es el orden real de reproducción, con la actual primero',
        () {
      expect(adapter.state.currentIndex, 0);
      expect(adapter.state.currentSong, c);
      expect(adapter.state.queue.toSet(), songs.toSet());
    });

    test('reproducir a continuación va justo después de la actual', () async {
      await adapter.playNext([x]);

      expect(adapter.state.queue[1], x);
      expect(adapter.state.currentSong, c);
    });

    test('añadir a la cola va al final del orden de reproducción', () async {
      await adapter.addToQueue([x]);
      expect(adapter.state.queue.last, x);
    });

    test('mover reordena la reproducción sin tocar las fuentes', () async {
      final expected = List.of(adapter.state.queue);
      expected.insert(4, expected.removeAt(1));
      final sourcesBefore = player.sourceSongs;

      await adapter.moveInQueue(1, 4);

      expect(adapter.state.queue, expected);
      expect(player.sourceSongs, sourcesBefore);
    });

    test('quitar conserva el orden del resto', () async {
      final expected = List.of(adapter.state.queue)..removeAt(2);
      await adapter.removeFromQueue(2);
      expect(adapter.state.queue, expected);
    });

    test('limpiar deja solo la actual', () async {
      await adapter.clearUpcoming();
      expect(adapter.state.queue, [c]);
      expect(player.sourceSongs, [c]);
    });

    test('siguiente sigue el orden real de reproducción', () async {
      final next = adapter.state.queue[1];
      await adapter.skipToNext();
      expect(await current(), next);
    });

    test('al desactivarlo vuelve al orden original', () async {
      await adapter.playNext([x]);
      await adapter.setShuffle(false);

      expect(queueTitles(), ['A', 'B', 'C', 'X', 'D', 'E']);
      expect(adapter.state.currentSong, c);
    });
  });

  group('navegación', () {
    test('siguiente y saltar a un índice', () async {
      await adapter.setQueue(songs);
      await adapter.skipToNext();
      expect(await current(), b);

      await adapter.skipToIndex(4);
      expect(await current(), e);

      await adapter.skipToIndex(99);
      expect(await current(), e);
    });

    test('anterior: antes de 3 s va a la previa; después reinicia', () async {
      await adapter.setQueue(songs, startIndex: 2);

      player.fakePosition = const Duration(seconds: 10);
      await adapter.skipToPrevious();
      expect(await current(), c);
      expect(player.log.last, 'seek(0s, index: null)');

      player.fakePosition = const Duration(seconds: 2);
      await adapter.skipToPrevious();
      expect(await current(), b);
    });
  });

  group('errores', () {
    test('emite el error y salta a la siguiente sin tocar la cola', () async {
      await adapter.setQueue(songs, startIndex: 1);
      final emitted = <PlaybackError>[];
      adapter.errors.listen(emitted.add);

      player.errors.add(PlayerException(0, 'Source error', 1));
      await pumpEventQueue();

      expect(emitted.single.song, b);
      expect(emitted.single.index, 1);
      expect(await current(), c);
      expect(adapter.state.queue, songs);
      expect(player.log, isNot(contains('stop')));
    });

    test('si falla la última canción, pausa', () async {
      await adapter.setQueue(songs, startIndex: 4);

      player.errors.add(PlayerException(0, 'Source error', 4));
      await pumpEventQueue();

      expect(player.log.last, 'pause');
      expect(adapter.state.currentSong, e);
    });

    test('tras 10 fallos seguidos deja de saltar y pausa', () async {
      final many = [for (var i = 0; i < 20; i++) buildSong(id: 100 + i)];
      await adapter.setQueue(many);

      for (var i = 0; i < 11; i++) {
        player.errors.add(PlayerException(0, 'Source error', i));
        await pumpEventQueue();
      }

      expect(player.log.where((l) => l.startsWith('seek')), hasLength(10));
      expect(player.log.last, 'pause');
    });
  });

  test('hasNext y hasPrevious se actualizan al editar la cola', () async {
    await adapter.setQueue([a, b, c], startIndex: 1);
    expect(adapter.state.hasNext, isTrue);
    expect(adapter.state.hasPrevious, isTrue);

    await adapter.removeFromQueue(2);
    expect(adapter.state.hasNext, isFalse);

    await adapter.addToQueue([x]);
    expect(adapter.state.hasNext, isTrue);

    await adapter.setRepeatMode(RepeatMode.all);
    await adapter.clearUpcoming();
    expect(adapter.state.hasNext, isTrue, reason: 'repetir todo da la vuelta');
  });
}
