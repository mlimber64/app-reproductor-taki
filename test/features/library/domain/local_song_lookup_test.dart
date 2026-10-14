import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/entities/local_music_identity.dart';
import 'package:taki/core/domain/entities/local_song.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/core/domain/entities/song_lookup_failure.dart';
import 'package:taki/features/library/domain/services/local_song_lookup.dart';

import '../../../helpers/library_fakes.dart';

void main() {
  final one = buildSong(id: 1, title: 'Uno');
  final two = buildSong(id: 2, title: 'Dos');

  LocalSongLookup over(List<LocalSong> library, {void Function()? onLoad}) =>
      LocalSongLookup(() async {
        onLoad?.call();
        return library;
      });

  test('identidad local encontrada: devuelve la LocalSong de la biblioteca',
      () async {
    final result = await over([one, two]).findAll([localMusicIdentity(2)]);

    expect(result.found.keys, [localMusicIdentity(2)]);
    expect(result.found[localMusicIdentity(2)], same(two));
    expect(result.missing, isEmpty);
    expect(result.unsupported, isEmpty);
  });

  test('la canción devuelta tiene la identidad pedida', () async {
    final result = await over([one, two])
        .findAll([localMusicIdentity(1), localMusicIdentity(2)]);

    for (final entry in result.found.entries) {
      expect(entry.value.musicIdentity, entry.key);
    }
    expect(result.found, hasLength(2));
  });

  test('identidad local inexistente → missing (no es un error)', () async {
    final result = await over([one]).findAll([localMusicIdentity(99)]);

    expect(result.missing, {localMusicIdentity(99)});
    expect(result.found, isEmpty);
  });

  test('biblioteca vacía → todo missing', () async {
    final result = await over(const []).findAll([localMusicIdentity(1)]);
    expect(result.missing, {localMusicIdentity(1)});
  });

  test('identidad de otra fuente → unsupported, sin leer la biblioteca',
      () async {
    var loads = 0;
    final remote = MusicIdentity('proveedor', '1');

    final result = await over([one], onLoad: () => loads++).findAll([remote]);

    expect(result.unsupported, {remote});
    expect(result.found, isEmpty);
    expect(result.missing, isEmpty);
    expect(loads, 0);
  });

  test('mezcla: encontrada, inexistente y de otra fuente', () async {
    final remote = MusicIdentity('proveedor', '1');

    final result = await over([one])
        .findAll([localMusicIdentity(1), localMusicIdentity(7), remote]);

    expect(result.found.keys, [localMusicIdentity(1)]);
    expect(result.missing, {localMusicIdentity(7)});
    expect(result.unsupported, {remote});
  });

  test('la biblioteca se lee una sola vez por lote', () async {
    var loads = 0;

    await over([one, two], onLoad: () => loads++).findAll([
      localMusicIdentity(1),
      localMusicIdentity(2),
      localMusicIdentity(3),
    ]);

    expect(loads, 1);
  });

  test('sin identidades no se lee la biblioteca', () async {
    var loads = 0;
    final result = await over([one], onLoad: () => loads++).findAll(const []);

    expect(loads, 0);
    expect(result.found, isEmpty);
  });

  group('solo identidad exacta (no es un matcher)', () {
    test('mismo título, ruta y duración pero otra identidad → missing',
        () async {
      // Reinstalación: la canción es «la misma» pero el id cambió.
      final reinstalled = buildSong(id: 50, title: 'Uno');
      expect(reinstalled.path, one.path);

      final result = await over([reinstalled]).findAll([one.musicIdentity]);

      expect(result.found, isEmpty);
      expect(result.missing, {one.musicIdentity});
    });

    test('el externalId se compara carácter a carácter', () async {
      final seven = buildSong(id: 7);

      for (final other in ['007', ' 7', '7 ', '7.0', '+7']) {
        final result = await over([seven])
            .findAll([MusicIdentity(localMusicSource, other)]);
        expect(result.missing, hasLength(1), reason: "'$other'");
        expect(result.found, isEmpty, reason: "'$other'");
      }
      final exact = await over([seven])
          .findAll([MusicIdentity(localMusicSource, '7')]);
      expect(exact.found, hasLength(1));
    });

    test('la etiqueta de fuente distingue mayúsculas', () async {
      final result = await over([one])
          .findAll([MusicIdentity('LOCAL', '1')]);
      expect(result.unsupported, hasLength(1));
      expect(result.found, isEmpty);
    });
  });

  group('errores', () {
    test('si la biblioteca no se puede leer → SongLookupFailure, no missing',
        () async {
      final lookup = LocalSongLookup(() async => throw StateError('sin acceso'));

      await expectLater(
        lookup.findAll([localMusicIdentity(1)]),
        throwsA(
          isA<SongLookupFailure>()
              .having((e) => e.source, 'source', localMusicSource)
              .having((e) => e.cause, 'cause', isA<StateError>()),
        ),
      );
    });
  });

  test('solo ve la biblioteca que le dan (la filtrada)', () async {
    // `two` existe en el dispositivo pero la biblioteca (filtrada) no lo
    // incluye: para el lookup no existe.
    final result = await over([one]).findAll([localMusicIdentity(2)]);
    expect(result.missing, {localMusicIdentity(2)});
  });
}
