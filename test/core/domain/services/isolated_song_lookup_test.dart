import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/core/domain/entities/song_lookup_failure.dart';
import 'package:taki/core/domain/entities/song_lookup_result.dart';
import 'package:taki/core/domain/ports/song_lookup.dart';
import 'package:taki/core/domain/services/isolated_song_lookup.dart';
import 'package:taki/core/domain/services/source_song_lookup.dart';

import '../../../helpers/song_lookup_fakes.dart';
import '../../../helpers/universal_song.dart';

/// Un lookup que lanza `SongLookupFailure` si recibe identidades de [failing].
class _FailingFor implements SongLookup {
  _FailingFor(this.failing, this.inner);

  final Set<String> failing;
  final SongLookup inner;
  final calls = <Set<MusicIdentity>>[];

  @override
  Future<SongLookupResult> findAll(Iterable<MusicIdentity> identities) {
    final set = identities.toSet();
    calls.add(set);
    if (set.any((i) => failing.contains(i.source))) {
      throw SongLookupFailure('falló', source: set.first.source);
    }
    return inner.findAll(set);
  }
}

void main() {
  final a1 = MusicIdentity('a', '1');
  final a2 = MusicIdentity('a', '2');
  final b1 = MusicIdentity('b', '1');
  final songA1 = buildUniversalSong(a1, title: 'A1');
  final songB1 = buildUniversalSong(b1, title: 'B1');

  SongLookup both() => SourceSongLookup({
        'a': FakeSourceLookup([songA1]),
        'b': FakeSourceLookup([songB1]),
      });

  test('sin identidades: no consulta nada', () async {
    final lookup = _FailingFor({}, both());
    final out = await findAllIsolatingSources(lookup, const []);
    expect(lookup.calls, isEmpty);
    expect(out.result.found, isEmpty);
    expect(out.failed, isEmpty);
  });

  test('una consulta por fuente, solo con sus identidades', () async {
    final lookup = _FailingFor({}, both());
    await findAllIsolatingSources(lookup, [a1, a2, b1]);
    expect(lookup.calls, hasLength(2));
    expect(lookup.calls, containsAll([{a1, a2}, {b1}]));
  });

  test('sin fallos: found/missing se conservan y failed está vacío', () async {
    final out =
        await findAllIsolatingSources(_FailingFor({}, both()), [a1, a2, b1]);
    expect(out.result.found, {a1: songA1, b1: songB1});
    expect(out.result.missing, {a2});
    expect(out.failed, isEmpty);
  });

  test('una fuente falla: sus identidades van a failed, NO a missing; la otra '
      'se resuelve', () async {
    final out =
        await findAllIsolatingSources(_FailingFor({'b'}, both()), [a1, a2, b1]);
    expect(out.failed, {b1});
    expect(out.result.found, {a1: songA1});
    expect(out.result.missing, {a2});
    expect(out.result.missing.contains(b1), isFalse);
    expect(out.result.unsupported, isEmpty);
  });

  test('falla la otra fuente: simétrico', () async {
    final out =
        await findAllIsolatingSources(_FailingFor({'a'}, both()), [a1, a2, b1]);
    expect(out.failed, {a1, a2});
    expect(out.result.found, {b1: songB1});
  });

  test('fallan todas las fuentes: relanza el fallo', () async {
    await expectLater(
      findAllIsolatingSources(_FailingFor({'a', 'b'}, both()), [a1, b1]),
      throwsA(isA<SongLookupFailure>()),
    );
  });

  test('una sola fuente y falla: relanza', () async {
    await expectLater(
      findAllIsolatingSources(_FailingFor({'a'}, both()), [a1, a2]),
      throwsA(isA<SongLookupFailure>()),
    );
  });

  test('una fuente sin lookup registrado sigue siendo unsupported', () async {
    final c1 = MusicIdentity('c', '1');
    final out = await findAllIsolatingSources(both(), [a1, c1]);
    expect(out.result.unsupported, {c1});
    expect(out.result.found, {a1: songA1});
    expect(out.failed, isEmpty);
  });

  test('un error que no es SongLookupFailure no se traga', () async {
    final lookup = SourceSongLookup({'a': FakeSourceLookup()..failure = 1});
    // SourceSongLookup lo envuelve en SongLookupFailure → llega como fallo.
    await expectLater(
      findAllIsolatingSources(lookup, [a1]),
      throwsA(isA<SongLookupFailure>()),
    );
  });
}
