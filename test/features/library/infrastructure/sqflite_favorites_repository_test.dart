import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taki/core/database/taki_database.dart';
import 'package:taki/core/domain/entities/local_music_identity.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/features/library/infrastructure/sqflite_favorites_repository.dart';

import '../../../helpers/universal_song.dart';
import '../../../helpers/library_fakes.dart';

void main() {
  late Database db;
  late SqfliteFavoritesRepository repository;
  late DateTime now;

  final a = buildSong(id: 1, title: 'A', artist: 'Artista A', durationMs: 1000);
  final b = buildSong(id: 2, title: 'B');
  final c = buildSong(id: 3, title: 'C');
  final idA = localMusicIdentity(1);
  final idB = localMusicIdentity(2);
  final idC = localMusicIdentity(3);

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await TakiDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    now = DateTime(2026, 9, 1, 12);
    repository = SqfliteFavoritesRepository(
      () async => db,
      // Cada escritura ocurre un minuto después de la anterior.
      clock: () => now = now.add(const Duration(minutes: 1)),
    );
  });

  tearDown(() async {
    await repository.dispose();
    await db.close();
  });

  List<MusicIdentity> identities(List<dynamic> entries) =>
      [for (final e in entries) e.musicIdentity as MusicIdentity];

  test('crea la tabla favorites con identidad fuente + id externo', () async {
    final columns = await db.rawQuery('PRAGMA table_info(favorites)');
    expect(
      columns.map((c) => c['name']),
      [
        'source',
        'external_id',
        'added_at',
        'title',
        'artist',
        'album',
        'duration_ms',
        'path',
      ],
    );
    final primaryKey = {
      for (final c in columns.where((c) => (c['pk']! as int) > 0))
        c['pk']! as int: c['name'],
    };
    expect(primaryKey, {1: 'source', 2: 'external_id'});
    final types = {for (final c in columns) c['name']: c['type']};
    expect(types['external_id'], 'TEXT');
  });

  test('añade con los datos de respaldo', () async {
    await repository.add(a);

    final entry = (await repository.getFavorites()).single;
    expect(entry.musicIdentity, idA);
    expect(entry.musicIdentity.source, 'local');
    expect(entry.musicIdentity.externalId, '1');
    expect(entry.addedAt, DateTime(2026, 9, 1, 12, 1));
    expect(entry.title, 'A');
    expect(entry.artist, 'Artista A');
    expect(entry.album, a.album);
    expect(entry.durationMs, 1000);
    expect(entry.path, a.path);
  });

  test('el respaldo guarda la ruta solo de canciones locales', () async {
    await repository.add(a);
    await repository.add(buildUniversalSong(MusicIdentity('otra', 'z')));

    final entries = await repository.getFavorites();
    final local = entries.singleWhere((e) => e.musicIdentity == idA);
    final other = entries.singleWhere((e) => e.musicIdentity.source == 'otra');
    expect(local.path, a.path);
    expect(other.path, isNull);
    expect(other.title, 'Remota'); // lo universal sí se respalda
    expect(other.durationMs, 200000);
  });

  test('no duplica y conserva la fecha original', () async {
    await repository.add(a);
    await repository.add(a);

    final entries = await repository.getFavorites();
    expect(entries, hasLength(1));
    expect(entries.single.addedAt, DateTime(2026, 9, 1, 12, 1));
  });

  test('ordena por más reciente primero', () async {
    await repository.add(a);
    await repository.add(b);
    await repository.add(c);

    expect(identities(await repository.getFavorites()), [idC, idB, idA]);
  });

  test('quita', () async {
    await repository.add(a);
    await repository.add(b);
    await repository.remove(idA);

    expect(identities(await repository.getFavorites()), [idB]);
  });

  test('el stream emite el estado inicial y tras cada cambio', () async {
    await repository.add(a);

    final expectation = expectLater(
      repository.watchFavoriteIdentities(),
      emitsInOrder([
        {idA},
        {idA, idB},
        {idB},
        <MusicIdentity>{},
      ]),
    );
    await pumpEventQueue();
    await repository.add(b);
    await repository.remove(idA);
    await repository.remove(idB);
    await expectation;
  });

  test('las escrituras se serializan', () async {
    // Sin esperar entre llamadas: el resultado final respeta el orden.
    unawaited(repository.add(a));
    unawaited(repository.add(b));
    unawaited(repository.remove(idA));
    await repository.add(c);

    expect(
      identities(await repository.getFavorites()).toSet(),
      {idB, idC},
    );
  });

  group('identidades opacas (Fase 2.4)', () {
    test('ids alfanuméricos, con ceros a la izquierda y otros textos se '
        'guardan y se leen tal cual', () async {
      final values = [
        MusicIdentity('x', 'abc123'),
        MusicIdentity('x', 'track-xyz'),
        MusicIdentity('x', '007'),
        MusicIdentity('x', '42'),
        MusicIdentity('x', 'mWB22'),
        MusicIdentity('x', 'https://ejemplo.invalid/a?b=c'),
        MusicIdentity('x', 'a:b,c'),
        MusicIdentity('x', ' con espacios '),
      ];
      for (final id in values) {
        await repository.add(buildUniversalSong(id));
      }

      final stored = identities(await repository.getFavorites()).toSet();
      expect(stored, values.toSet());
      // "007" no se convirtió a número.
      expect(stored, contains(MusicIdentity('x', '007')));
      expect(stored, isNot(contains(MusicIdentity('x', '7'))));
    });

    test('el mismo id externo en fuentes distintas son favoritos distintos',
        () async {
      await repository.add(buildUniversalSong(MusicIdentity('a', '123')));
      await repository.add(buildUniversalSong(MusicIdentity('b', '123')));
      await repository.add(buildUniversalSong(MusicIdentity('local', '123')));

      expect(await repository.getFavorites(), hasLength(3));

      await repository.remove(MusicIdentity('a', '123'));
      expect(
        identities(await repository.getFavorites()).toSet(),
        {MusicIdentity('b', '123'), MusicIdentity('local', '123')},
      );
    });

    test('mayúsculas y minúsculas son identidades distintas', () async {
      await repository.add(buildUniversalSong(MusicIdentity('x', 'ABC')));
      await repository.add(buildUniversalSong(MusicIdentity('x', 'abc')));

      expect(await repository.getFavorites(), hasLength(2));
      await repository.remove(MusicIdentity('x', 'ABC'));
      expect(identities(await repository.getFavorites()),
          [MusicIdentity('x', 'abc')]);
    });

    test('la restricción de la base rechaza una identidad vacía', () async {
      Future<void> insert(String source, String externalId) => db.insert(
            'favorites',
            {'source': source, 'external_id': externalId, 'added_at': 1},
          );

      await expectLater(insert('', 'x'), throwsA(isA<DatabaseException>()));
      await expectLater(insert('x', ''), throwsA(isA<DatabaseException>()));
      await expectLater(insert('  ', 'x'), throwsA(isA<DatabaseException>()));
      await expectLater(insert('x', '  '), throwsA(isA<DatabaseException>()));
    });

    test('la restricción de la base rechaza duplicados de fuente + id',
        () async {
      await db.insert(
        'favorites',
        {'source': 'x', 'external_id': '1', 'added_at': 1},
      );

      await expectLater(
        db.insert('favorites', {'source': 'x', 'external_id': '1', 'added_at': 2}),
        throwsA(isA<DatabaseException>()),
      );
      // La misma cadena en otra fuente sí cabe.
      await db.insert(
        'favorites',
        {'source': 'y', 'external_id': '1', 'added_at': 3},
      );
    });
  });

  group('relink', () {
    test('cambia la identidad, actualiza el respaldo y conserva la fecha',
        () async {
      await repository.add(a);
      final moved = buildSong(id: 99, title: 'A (nuevo)', durationMs: 1000);

      await repository.relink(idA, moved);

      final entry = (await repository.getFavorites()).single;
      expect(entry.musicIdentity, localMusicIdentity(99));
      expect(entry.title, 'A (nuevo)');
      expect(entry.addedAt, DateTime(2026, 9, 1, 12, 1));
    });

    test('si la identidad nueva ya es favorita, borra el registro viejo',
        () async {
      await repository.add(a);
      await repository.add(b);

      await repository.relink(idA, b);

      expect(identities(await repository.getFavorites()), [idB]);
    });

    test('con la misma identidad no hace nada', () async {
      await repository.add(a);

      await repository.relink(idA, a);

      expect(identities(await repository.getFavorites()), [idA]);
    });
  });

  test('si la base no está disponible, las operaciones fallan', () async {
    final broken = SqfliteFavoritesRepository(
      () => Future.error(StateError('No se pudo abrir taki.db')),
    );

    await expectLater(broken.getFavorites(), throwsStateError);
    await expectLater(broken.add(a), throwsStateError);
    await expectLater(
      broken.watchFavoriteIdentities(),
      emitsError(isStateError),
    );
    await broken.dispose();
  });
}
