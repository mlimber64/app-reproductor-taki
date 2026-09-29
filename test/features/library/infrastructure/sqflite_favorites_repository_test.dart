import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taki/core/database/taki_database.dart';
import 'package:taki/features/library/infrastructure/sqflite_favorites_repository.dart';

import '../../../helpers/library_fakes.dart';

void main() {
  late Database db;
  late SqfliteFavoritesRepository repository;
  late DateTime now;

  final a = buildSong(id: 1, title: 'A', artist: 'Artista A', durationMs: 1000);
  final b = buildSong(id: 2, title: 'B');
  final c = buildSong(id: 3, title: 'C');

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

  test('crea la tabla favorites con sus columnas', () async {
    final columns = await db.rawQuery('PRAGMA table_info(favorites)');
    expect(
      columns.map((c) => c['name']),
      ['song_id', 'added_at', 'title', 'artist', 'album', 'duration_ms', 'path'],
    );
    final primaryKey = columns.firstWhere((c) => c['pk'] == 1);
    expect(primaryKey['name'], 'song_id');
  });

  test('añade con los datos de respaldo', () async {
    await repository.add(a);

    final entry = (await repository.getFavorites()).single;
    expect(entry.songId, 1);
    expect(entry.addedAt, DateTime(2026, 9, 1, 12, 1));
    expect(entry.title, 'A');
    expect(entry.artist, 'Artista A');
    expect(entry.album, a.album);
    expect(entry.durationMs, 1000);
    expect(entry.path, a.path);
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

    final entries = await repository.getFavorites();
    expect(entries.map((e) => e.songId), [3, 2, 1]);
  });

  test('quita', () async {
    await repository.add(a);
    await repository.add(b);
    await repository.remove(1);

    expect((await repository.getFavorites()).map((e) => e.songId), [2]);
  });

  test('el stream emite el estado inicial y tras cada cambio', () async {
    await repository.add(a);

    final expectation = expectLater(
      repository.watchFavoriteIds(),
      emitsInOrder([
        {1},
        {1, 2},
        {2},
        <int>{},
      ]),
    );
    await pumpEventQueue();
    await repository.add(b);
    await repository.remove(1);
    await repository.remove(2);
    await expectation;
  });

  test('las escrituras se serializan', () async {
    // Sin esperar entre llamadas: el resultado final respeta el orden.
    unawaited(repository.add(a));
    unawaited(repository.add(b));
    unawaited(repository.remove(1));
    await repository.add(c);

    expect(
      (await repository.getFavorites()).map((e) => e.songId).toSet(),
      {2, 3},
    );
  });

  group('relink', () {
    test('cambia el id, actualiza el respaldo y conserva la fecha', () async {
      await repository.add(a);
      final moved = buildSong(id: 99, title: 'A (nuevo)', durationMs: 1000);

      await repository.relink(1, moved);

      final entry = (await repository.getFavorites()).single;
      expect(entry.songId, 99);
      expect(entry.title, 'A (nuevo)');
      expect(entry.addedAt, DateTime(2026, 9, 1, 12, 1));
    });

    test('si el id nuevo ya es favorito, borra el registro viejo', () async {
      await repository.add(a);
      await repository.add(b);

      await repository.relink(1, b);

      expect((await repository.getFavorites()).map((e) => e.songId), [2]);
    });
  });

  test('si la base no está disponible, las operaciones fallan', () async {
    final broken = SqfliteFavoritesRepository(
      () => Future.error(StateError('No se pudo abrir taki.db')),
    );

    await expectLater(broken.getFavorites(), throwsStateError);
    await expectLater(broken.add(a), throwsStateError);
    await expectLater(broken.watchFavoriteIds(), emitsError(isStateError));
    await broken.dispose();
  });
}
