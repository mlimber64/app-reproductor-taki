import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/entities/local_song.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/core/domain/entities/playback_resource.dart';
import 'package:taki/core/domain/entities/song.dart';
import 'package:taki/core/domain/ports/playback_resolver.dart';
import 'package:taki/features/player/infrastructure/just_audio_player_adapter.dart';

import '../../../helpers/fake_just_audio_player.dart';
import '../../../helpers/library_fakes.dart';

/// Resolvedor con compuerta: una identidad con compuerta no se resuelve hasta
/// que el test la abre (resolución lenta, p. ej. una consulta de red).
class _GatedResolver implements PlaybackResolver {
  final gates = <MusicIdentity, Completer<void>>{};
  final started = <MusicIdentity>[];

  Completer<void> gate(Song song) =>
      gates[song.musicIdentity] = Completer<void>();

  @override
  Future<PlaybackResource> resolve(Song song) async {
    started.add(song.musicIdentity);
    final g = gates[song.musicIdentity];
    if (g != null) await g.future;
    return LocalUriResource((song as LocalSong).contentUri);
  }
}

/// Fase 3.11A: las operaciones que cambian la cola se aplican **en el orden en
/// que se pidieron**, aunque se pidan a la vez o una resolución sea lenta. Una
/// comprobación del estado de la cola antes de entrar en la serialización
/// observaba un estado ya obsoleto.
void main() {
  late FakeJustAudioPlayer player;
  late _GatedResolver resolver;
  late JustAudioPlayerAdapter adapter;

  final a = buildSong(id: 1, title: 'A');
  final b = buildSong(id: 2, title: 'B');
  final c = buildSong(id: 3, title: 'C');
  final x = buildSong(id: 10, title: 'X');
  final y = buildSong(id: 11, title: 'Y');

  setUp(() {
    player = FakeJustAudioPlayer();
    resolver = _GatedResolver();
    adapter = JustAudioPlayerAdapter(player: player, resolver: resolver);
  });

  tearDown(() => player.close());

  List<String> queue() => [for (final s in adapter.state.queue) s.title];
  List<String> sourceTitles() => [
        for (final s in player.sourceSongs) s.title,
      ];

  group('cola vacía: dos operaciones a la vez', () {
    test('dos addToQueue concurrentes → las dos canciones, en orden', () async {
      await Future.wait([adapter.addToQueue([x]), adapter.addToQueue([y])]);

      expect(queue(), ['X', 'Y']);
      expect(sourceTitles(), ['X', 'Y']);
    });

    test('dos playNext concurrentes → la segunda va tras la primera, la cola '
        'no pierde ninguna', () async {
      await Future.wait([adapter.playNext([x]), adapter.playNext([y])]);

      expect(queue(), ['X', 'Y']);
    });

    test('addToQueue y playNext concurrentes', () async {
      await Future.wait([adapter.addToQueue([x]), adapter.playNext([y])]);

      expect(queue(), ['X', 'Y']);
    });
  });

  group('setQueue pendiente + otra operación', () {
    test('setQueue lento + addToQueue → se añade a la cola nueva, no la '
        'reemplaza', () async {
      final gate = resolver.gate(a);
      final set = adapter.setQueue([a, b]);
      final add = adapter.addToQueue([x]);
      await pumpEventQueue();
      gate.complete();
      await Future.wait([set, add]);

      expect(queue(), ['A', 'B', 'X']);
    });

    test('setQueue lento + playNext → va justo tras la actual', () async {
      final gate = resolver.gate(a);
      final set = adapter.setQueue([a, b]);
      final next = adapter.playNext([y]);
      await pumpEventQueue();
      gate.complete();
      await Future.wait([set, next]);

      expect(queue(), ['A', 'Y', 'B']);
    });

    test('addToQueue lento + setQueue → gana setQueue, que es posterior',
        () async {
      await adapter.setQueue([a]);
      final gate = resolver.gate(x);
      final add = adapter.addToQueue([x]);
      final set = adapter.setQueue([b, c]);
      await pumpEventQueue();
      gate.complete();
      await Future.wait([add, set]);

      expect(queue(), ['B', 'C']);
    });
  });

  group('cola con canciones + resolución lenta', () {
    setUp(() => adapter.setQueue([a, b, c]));

    test('clearUpcoming + addToQueue: se aplican en el orden pedido', () async {
      await Future.wait([adapter.clearUpcoming(), adapter.addToQueue([x])]);

      expect(queue(), ['A', 'X']);
    });

    test('addToQueue lento + clearUpcoming: el clear espera y también quita '
        'lo añadido', () async {
      final gate = resolver.gate(x);
      final add = adapter.addToQueue([x]);
      final clear = adapter.clearUpcoming();
      await pumpEventQueue();
      expect(queue(), ['A', 'B', 'C']); // nada se aplicó todavía
      gate.complete();
      await Future.wait([add, clear]);

      expect(queue(), ['A']);
    });

    test('playNext lento + removeFromQueue: el índice se aplica a la cola ya '
        'actualizada, en orden', () async {
      final gate = resolver.gate(y);
      final next = adapter.playNext([y]);
      final remove = adapter.removeFromQueue(2); // tras «Y»: quita «B»
      await pumpEventQueue();
      gate.complete();
      await Future.wait([next, remove]);

      expect(queue(), ['A', 'Y', 'C']);
    });

    test('una operación lenta no deja pasar a las siguientes', () async {
      final gate = resolver.gate(x);
      final add = adapter.addToQueue([x]);
      final addY = adapter.addToQueue([y]);
      await pumpEventQueue();
      expect(resolver.started, isNot(contains(y.musicIdentity)));
      gate.complete();
      await Future.wait([add, addY]);

      expect(queue(), ['A', 'B', 'C', 'X', 'Y']);
    });

    test('un fallo en una operación no bloquea las siguientes', () async {
      final failing = adapter.addToQueue(
        [buildSong(id: 99, title: 'rota')],
      );
      final ok = adapter.addToQueue([x]);
      await Future.wait([failing, ok]);

      expect(queue().last, 'X');
    });
  });

  group('compatibilidad (comportamiento existente)', () {
    test('addToQueue con la cola vacía las convierte en la cola (empieza por '
        'la primera)', () async {
      await adapter.addToQueue([x, y]);
      expect(queue(), ['X', 'Y']);
      expect(adapter.state.currentSong, x);
    });

    test('playNext con la cola vacía las convierte en la cola (empieza por la '
        'primera)', () async {
      await adapter.playNext([x, y]);
      expect(queue(), ['X', 'Y']);
      expect(adapter.state.currentSong, x);
    });

    test('operaciones concurrentes sobre cola vacía: la actual es la primera '
        'pedida', () async {
      await Future.wait([adapter.playNext([x, y]), adapter.addToQueue([a])]);
      expect(queue(), ['X', 'Y', 'A']);
      expect(adapter.state.currentSong, x);
    });

    test('addToQueue con lista vacía y cola vacía no rompe', () async {
      await adapter.addToQueue(const []);
      expect(queue(), isEmpty);
    });

    test('secuencias esperadas no cambian', () async {
      await adapter.setQueue([a, b]);
      await adapter.addToQueue([x]);
      await adapter.playNext([y]);
      expect(queue(), ['A', 'Y', 'B', 'X']);
    });
  });
}
