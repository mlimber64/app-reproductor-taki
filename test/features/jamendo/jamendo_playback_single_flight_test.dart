import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/core/domain/entities/playback_resolution_exception.dart';
import 'package:taki/core/domain/entities/playback_resource.dart';
import 'package:taki/core/domain/entities/song.dart';
import 'package:taki/features/jamendo/domain/entities/jamendo_exception.dart';
import 'package:taki/features/jamendo/domain/entities/jamendo_track.dart';
import 'package:taki/features/jamendo/domain/ports/jamendo_api.dart';
import 'package:taki/features/jamendo/domain/services/caching_jamendo_api.dart';
import 'package:taki/features/jamendo/domain/services/jamendo_audio_cache.dart';
import 'package:taki/features/jamendo/domain/services/jamendo_playback_resolver.dart';
import 'package:taki/features/jamendo/domain/services/jamendo_song_mapper.dart';
import 'package:taki/features/player/infrastructure/just_audio_player_adapter.dart';

import '../../helpers/fake_just_audio_player.dart';
import '../../helpers/jamendo_fakes.dart';
import '../../helpers/library_fakes.dart';

/// `JamendoApi` lento: cada `tracksByIds` queda pendiente hasta que el test lo
/// completa (en orden de llegada) o lo hace fallar.
class _SlowApi implements JamendoApi {
  final calls = <List<String>>[];
  final _pending = <Completer<List<JamendoTrack>>>[];
  List<JamendoTrack> tracks = const [];

  @override
  Future<List<JamendoTrack>> tracksByIds(Iterable<String> ids) {
    calls.add(ids.toList());
    final c = Completer<List<JamendoTrack>>();
    _pending.add(c);
    return c.future;
  }

  void completeNext() {
    final c = _pending.removeAt(0);
    final ids = calls[calls.length - _pending.length - 1].toSet();
    c.complete([
      for (final t in tracks)
        if (ids.contains(t.id)) t,
    ]);
  }

  void failNext(Object error) => _pending.removeAt(0).completeError(error);

  bool get hasPending => _pending.isNotEmpty;

  @override
  Future<JamendoTrackPage> searchTracks({
    String? name,
    String? artistName,
    String? tag,
    required int limit,
    required int offset,
  }) =>
      throw UnimplementedError();

  @override
  Future<JamendoTrackPage> listTracks({
    required JamendoTrackOrder order,
    String? tag,
    required int limit,
    required int offset,
  }) =>
      throw UnimplementedError();
}

/// Fase 3.11A: una misma `MusicIdentity` con la resolución pendiente se resuelve
/// **una sola vez** (single-flight); la caché sigue siendo solo de memoria.
void main() {
  late _SlowApi api;
  late JamendoAudioCache cache;
  late JamendoPlaybackResolver resolver;
  late DateTime now;

  Song songOf(String id) => songFromJamendoTrack(buildTrack(id));
  final s123 = songOf('123');
  final s124 = songOf('124');

  setUp(() {
    api = _SlowApi()..tracks = [buildTrack('123'), buildTrack('124')];
    now = DateTime(2026, 10, 2, 12);
    cache = JamendoAudioCache(clock: () => now);
    resolver = JamendoPlaybackResolver(CachingJamendoApi(api, cache), cache);
  });

  group('misma identidad', () {
    test('dos resoluciones concurrentes → una sola consulta al proveedor',
        () async {
      final first = resolver.resolve(s123);
      final second = resolver.resolve(s123);
      await pumpEventQueue();
      expect(api.calls, hasLength(1));

      api.completeNext();
      final results = await Future.wait([first, second]);

      expect(api.calls, hasLength(1));
      expect(results[0], RemoteUriResource('https://audio.example/123'));
      expect(results[1], results[0]);
    });

    test('muchas a la vez (la misma canción repetida en una cola) → una',
        () async {
      final all = [for (var i = 0; i < 5; i++) resolver.resolve(s123)];
      await pumpEventQueue();
      api.completeNext();
      final results = await Future.wait(all);

      expect(api.calls, hasLength(1));
      expect(results.toSet(), hasLength(1));
    });

    test('tras completarse, la siguiente es un acierto de caché (sin red)',
        () async {
      final first = resolver.resolve(s123);
      await pumpEventQueue();
      api.completeNext();
      await first;

      final again = await resolver.resolve(s123);

      expect(again, RemoteUriResource('https://audio.example/123'));
      expect(api.calls, hasLength(1));
    });

    test('con la URL ya en caché no se llama al proveedor', () async {
      cache.put(s123.musicIdentity, 'https://cache.example/123');

      final r = await resolver.resolve(s123);

      expect(r, RemoteUriResource('https://cache.example/123'));
      expect(api.calls, isEmpty);
    });

    test('TTL vencido → nueva resolución', () async {
      final first = resolver.resolve(s123);
      await pumpEventQueue();
      api.completeNext();
      await first;

      now = now.add(const Duration(minutes: 10));
      final second = resolver.resolve(s123);
      await pumpEventQueue();
      expect(api.calls, hasLength(2));
      api.completeNext();
      await second;
    });
  });

  group('fallos', () {
    test('un fallo llega a todos los que esperaban y libera la entrada',
        () async {
      final first = resolver.resolve(s123);
      final second = resolver.resolve(s123);
      await pumpEventQueue();
      api.failNext(const JamendoNetworkException('red'));

      await expectLater(first, throwsA(isA<PlaybackResolutionError>()));
      await expectLater(second, throwsA(isA<PlaybackResolutionError>()));
      expect(api.calls, hasLength(1));
    });

    test('tras un fallo, el siguiente intento vuelve a resolver', () async {
      final failed = resolver.resolve(s123);
      await pumpEventQueue();
      api.failNext(const JamendoNetworkException('red'));
      await expectLater(failed, throwsA(isA<PlaybackResolutionError>()));

      final retry = resolver.resolve(s123);
      await pumpEventQueue();
      expect(api.calls, hasLength(2));
      api.completeNext();

      expect(await retry, RemoteUriResource('https://audio.example/123'));
    });

    test('el fallo no se guarda en la caché', () async {
      final failed = resolver.resolve(s123);
      await pumpEventQueue();
      api.failNext(const JamendoNetworkException('red'));
      await expectLater(failed, throwsA(isA<PlaybackResolutionError>()));

      expect(cache.get(s123.musicIdentity), isNull);
    });

    test('pista que la API ya no devuelve → IdentityNotFound y entrada libre',
        () async {
      api.tracks = const [];
      final first = resolver.resolve(s123);
      await pumpEventQueue();
      api.completeNext();
      await expectLater(first, throwsA(isA<IdentityNotFound>()));

      api.tracks = [buildTrack('123')];
      final second = resolver.resolve(s123);
      await pumpEventQueue();
      expect(api.calls, hasLength(2));
      api.completeNext();
      expect(await second, RemoteUriResource('https://audio.example/123'));
    });

    test('sin audio → UnavailableResource compartido, sin caché', () async {
      api.tracks = [
        JamendoTrack(
          id: '123',
          name: 'x',
          artistName: null,
          albumName: null,
          durationSeconds: 1,
          albumImage: null,
          audio: '  ',
          shareUrl: null,
          licenseUrl: null,
        ),
      ];
      final a = resolver.resolve(s123);
      final b = resolver.resolve(s123);
      await pumpEventQueue();
      api.completeNext();

      expect(await a, isA<UnavailableResource>());
      expect(await b, isA<UnavailableResource>());
      expect(api.calls, hasLength(1));
      expect(cache.get(s123.musicIdentity), isNull);
    });
  });

  group('identidades distintas', () {
    test('jamendo:123 y jamendo:124 → consultas independientes', () async {
      final a = resolver.resolve(s123);
      final b = resolver.resolve(s124);
      await pumpEventQueue();

      expect(api.calls, hasLength(2));
      expect(api.calls.map((c) => c.single).toSet(), {'123', '124'});
      api.completeNext();
      api.completeNext();
      expect(await a, RemoteUriResource('https://audio.example/123'));
      expect(await b, RemoteUriResource('https://audio.example/124'));
    });

    test('el fallo de una no afecta a la otra', () async {
      final a = resolver.resolve(s123);
      final b = resolver.resolve(s124);
      await pumpEventQueue();
      api.failNext(const JamendoNetworkException('red')); // la 1.ª (123)
      api.completeNext(); // la 2.ª (124)

      await expectLater(a, throwsA(isA<PlaybackResolutionError>()));
      expect(await b, RemoteUriResource('https://audio.example/124'));
    });

    test('la misma id en otra fuente no comparte nada: local:123 ≠ jamendo:123',
        () async {
      final local = buildSong(id: 123, title: 'local');
      expect(local.musicIdentity, isNot(s123.musicIdentity));

      await expectLater(
        resolver.resolve(local),
        throwsA(isA<IdentityNotFound>()),
      );
      expect(api.calls, isEmpty);
    });

    test('ids con ceros a la izquierda son otra identidad (0123 ≠ 123)',
        () async {
      api.tracks = [buildTrack('123'), buildTrack('0123')];
      final a = resolver.resolve(s123);
      final b = resolver.resolve(songOf('0123'));
      await pumpEventQueue();

      expect(api.calls, hasLength(2));
      api.completeNext();
      api.completeNext();
      await Future.wait([a, b]);
    });
  });

  group('cola fría con el adaptador (estrategia actual: se resuelve toda la '
      'cola al encolar)', () {
    late FakeJustAudioPlayer player;
    late JustAudioPlayerAdapter adapter;

    setUp(() {
      player = FakeJustAudioPlayer();
      adapter = JustAudioPlayerAdapter(player: player, resolver: resolver);
    });

    tearDown(() => player.close());

    Future<void> completeAll() async {
      // Cada espera deja que se registren las consultas pendientes.
      for (var i = 0; i < 20; i++) {
        await pumpEventQueue();
        while (api.hasPending) {
          api.completeNext();
          await pumpEventQueue();
        }
      }
    }

    test('la misma canción repetida en la cola → una sola consulta', () async {
      final queue = adapter.setQueue([s123, s123, s123]);
      await completeAll();
      await queue;

      expect(api.calls, hasLength(1));
      expect(adapter.state.queue, hasLength(3)); // la cola conserva las 3
      expect(player.sources, hasLength(3));
    });

    test('canciones distintas → una consulta por identidad (sin cambios)',
        () async {
      final queue = adapter.setQueue([s123, s124, s123]);
      await completeAll();
      await queue;

      expect(api.calls.map((c) => c.single).toSet(), {'123', '124'});
      expect(api.calls, hasLength(2));
      expect(adapter.state.queue, hasLength(3));
    });

    test('una canción ya en caché no consulta; la fría sí', () async {
      cache.put(s123.musicIdentity, 'https://cache.example/123');
      final queue = adapter.setQueue([s123, s124]);
      await completeAll();
      await queue;

      expect(api.calls.map((c) => c.single), ['124']);
    });

    test('si una falla, la cola se arma igual (la entrada no es reproducible)',
        () async {
      final queue = adapter.setQueue([s123, s124]);
      await pumpEventQueue();
      api.failNext(const JamendoNetworkException('red')); // 123
      await pumpEventQueue();
      api.completeNext(); // 124
      await queue;

      expect(adapter.state.queue, hasLength(2));
    });
  });

  test('la identidad es la clave (no la instancia de Song)', () async {
    final copy = songFromJamendoTrack(buildTrack('123', name: 'Otro título'));
    expect(copy, isNot(s123)); // distinta Song…
    expect(copy.musicIdentity, MusicIdentity('jamendo', '123')); // …misma identidad

    final a = resolver.resolve(s123);
    final b = resolver.resolve(copy);
    await pumpEventQueue();
    expect(api.calls, hasLength(1));
    api.completeNext();
    await Future.wait([a, b]);
  });
}
