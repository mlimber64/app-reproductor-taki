import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/entities/local_music_identity.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/core/domain/entities/song_lookup_failure.dart';
import 'package:taki/core/domain/entities/song_lookup_result.dart';
import 'package:taki/core/domain/ports/song_lookup.dart';
import 'package:taki/core/domain/services/source_song_lookup.dart';

import '../../../helpers/song_lookup_fakes.dart';
import '../../../helpers/universal_song.dart';

void main() {
  final a1 = MusicIdentity('a', '1');
  final a2 = MusicIdentity('a', '2');
  final b1 = MusicIdentity('b', '1');
  final songA1 = buildUniversalSong(a1, title: 'A1');
  final songB1 = buildUniversalSong(b1, title: 'B1');

  group('enrutado por fuente', () {
    test('cada lookup solo recibe las identidades de su fuente', () async {
      final lookupA = FakeSourceLookup([songA1]);
      final lookupB = FakeSourceLookup([songB1]);
      final router = SourceSongLookup({'a': lookupA, 'b': lookupB});

      final result = await router.findAll([a1, b1, a2]);

      expect(lookupA.requests, [
        {a1, a2},
      ]);
      expect(lookupB.requests, [
        {b1},
      ]);
      expect(result.found, {a1: songA1, b1: songB1});
      expect(result.missing, {a2});
      expect(result.unsupported, isEmpty);
    });

    test('la fuente es parte de la identidad: mismo externalId, otra fuente',
        () async {
      final router = SourceSongLookup({
        'a': FakeSourceLookup([songA1]),
        'b': FakeSourceLookup(),
      });

      final result = await router.findAll([a1, b1]);

      expect(result.found.keys, [a1]);
      expect(result.missing, {b1});
    });

    test('el externalId se pasa tal cual, sin normalizar', () async {
      final lookup = FakeSourceLookup();
      final router = SourceSongLookup({'a': lookup});
      final odd = MusicIdentity('a', ' Ab:007/ ');

      await router.findAll([odd]);

      expect(lookup.requests.single.single.externalId, ' Ab:007/ ');
    });

    test('varios lookups se combinan en un solo resultado', () async {
      final router = SourceSongLookup({
        'a': FakeSourceLookup([songA1]),
        'b': FakeSourceLookup([songB1]),
      });
      final result = await router.findAll([a1, b1]);
      expect(result.found, {a1: songA1, b1: songB1});
    });

    test('los duplicados se tratan como una sola identidad', () async {
      final lookup = FakeSourceLookup([songA1]);
      final router = SourceSongLookup({'a': lookup});

      final result = await router.findAll([a1, a1, a1]);

      expect(lookup.requests.single, {a1});
      expect(result.found, {a1: songA1});
    });

    test('sin identidades: resultado vacío y ningún lookup consultado',
        () async {
      final lookup = FakeSourceLookup();
      final result = await SourceSongLookup({'a': lookup}).findAll(const []);

      expect(lookup.requests, isEmpty);
      expect(result.found, isEmpty);
      expect(result.missing, isEmpty);
      expect(result.unsupported, isEmpty);
    });

    test('el mapa recibido no se puede mutar desde fuera', () async {
      final map = <String, SongLookup>{};
      final router = SourceSongLookup(map);
      map['a'] = FakeSourceLookup([songA1]);

      expect((await router.findAll([a1])).unsupported, {a1});
    });
  });

  group('fuente desconocida', () {
    test('sin lookup registrado → unsupported (ni missing ni local)', () async {
      final router = SourceSongLookup({'a': FakeSourceLookup([songA1])});
      final unknown = MusicIdentity('proveedor', 'abc');

      final result = await router.findAll([unknown, a1]);

      expect(result.unsupported, {unknown});
      expect(result.missing, isEmpty);
      expect(result.found.keys, [a1]);
    });

    test('una identidad remota sin provider no cae en el lookup local',
        () async {
      final local = FakeSourceLookup();
      final router = SourceSongLookup({localMusicSource: local});

      final result = await router.findAll([MusicIdentity('proveedor', '42')]);

      expect(local.requests, isEmpty);
      expect(result.unsupported, hasLength(1));
    });

    test('sin ningún lookup registrado todo es unsupported', () async {
      final result = await SourceSongLookup({}).findAll([a1, b1]);
      expect(result.unsupported, {a1, b1});
    });
  });

  group('errores', () {
    test('un fallo genérico se traduce en SongLookupFailure con la fuente',
        () async {
      final lookup = FakeSourceLookup()..failure = StateError('sin red');
      final router = SourceSongLookup({'a': lookup});

      await expectLater(
        router.findAll([a1]),
        throwsA(
          isA<SongLookupFailure>()
              .having((e) => e.source, 'source', 'a')
              .having((e) => e.cause, 'cause', isA<StateError>()),
        ),
      );
    });

    test('un SongLookupFailure del lookup se propaga tal cual', () async {
      const failure = SongLookupFailure('x', source: 'a');
      final lookup = FakeSourceLookup()..failure = failure;

      await expectLater(
        SourceSongLookup({'a': lookup}).findAll([a1]),
        throwsA(same(failure)),
      );
    });

    test('un fallo no se convierte en missing ni en unsupported', () async {
      final lookup = FakeSourceLookup()..failure = StateError('x');
      final router = SourceSongLookup({'a': lookup});
      Object? caught;
      SongLookupResult? result;
      try {
        result = await router.findAll([a1]);
      } catch (e) {
        caught = e;
      }
      expect(result, isNull);
      expect(caught, isA<SongLookupFailure>());
    });

    test('el fallo de una fuente falla el lote entero (decisión documentada)',
        () async {
      final bad = FakeSourceLookup()..failure = StateError('x');
      final router = SourceSongLookup({
        'a': bad,
        'b': FakeSourceLookup([songB1]),
      });

      await expectLater(
        router.findAll([a1, b1]),
        throwsA(isA<SongLookupFailure>()),
      );
    });
  });

  group('contrato', () {
    test('una canción devuelta bajo otra identidad es un error', () async {
      final wrong = ScriptedLookup(SongLookupResult(found: {a1: songB1}));

      await expectLater(
        SourceSongLookup({'a': wrong}).findAll([a1]),
        throwsA(isA<SongLookupFailure>()),
      );
    });

    test('identidades que el lookup no contabilizó pasan a missing', () async {
      final silent = ScriptedLookup(const SongLookupResult());

      final result = await SourceSongLookup({'a': silent}).findAll([a1, a2]);

      expect(result.missing, {a1, a2});
    });

    test('lo que el lookup devuelve de más (no pedido) se ignora', () async {
      final extra = ScriptedLookup(
        SongLookupResult(found: {a1: songA1, a2: buildUniversalSong(a2)}),
      );

      final result = await SourceSongLookup({'a': extra}).findAll([a1]);

      expect(result.found.keys, [a1]);
      expect(result.missing, isEmpty);
    });

    test('un lookup puede declarar unsupported y se respeta', () async {
      final scripted = ScriptedLookup(SongLookupResult(unsupported: {a1}));

      final result = await SourceSongLookup({'a': scripted}).findAll([a1]);

      expect(result.unsupported, {a1});
      expect(result.missing, isEmpty);
    });

    test('cada identidad pedida cae en exactamente un cubo', () async {
      final router = SourceSongLookup({
        'a': FakeSourceLookup([songA1]),
      });
      final asked = [a1, a2, b1, MusicIdentity('c', '1')];

      final r = await router.findAll(asked);

      for (final identity in asked) {
        final buckets = [
          r.found.containsKey(identity),
          r.missing.contains(identity),
          r.unsupported.contains(identity),
        ].where((x) => x).length;
        expect(buckets, 1, reason: '$identity');
      }
    });
  });
}
