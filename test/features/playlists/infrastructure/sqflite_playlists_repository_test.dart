import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taki/core/database/taki_database.dart';
import 'package:taki/features/playlists/domain/entities/playlist.dart';
import 'package:taki/features/playlists/infrastructure/sqflite_playlists_repository.dart';

import '../../../helpers/library_fakes.dart';

void main() {
  late Database db;
  late SqflitePlaylistsRepository repository;
  late DateTime now;

  final a = buildSong(id: 1, title: 'A', durationMs: 60000);
  final b = buildSong(id: 2, title: 'B', durationMs: 120000);
  final c = buildSong(id: 3, title: 'C', durationMs: 180000);
  final d = buildSong(id: 4, title: 'D', durationMs: 240000);
  final e = buildSong(id: 5, title: 'E', durationMs: 300000);

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await TakiDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    now = DateTime(2026, 9, 1, 12);
    repository = SqflitePlaylistsRepository(
      () async => db,
      clock: () => now = now.add(const Duration(minutes: 1)),
    );
  });

  tearDown(() async {
    await repository.dispose();
    await db.close();
  });

  Future<List<int>> songIds(int playlistId) async =>
      [for (final e in await repository.getEntries(playlistId)) e.songId];

  Future<List<int>> positions(int playlistId) async =>
      [for (final e in await repository.getEntries(playlistId)) e.position];

  Future<Playlist> playlist(int id) async =>
      (await repository.watchPlaylists().first).firstWhere((p) => p.id == id);

  test('crea, renombra y ordena por modificación más reciente', () async {
    final first = await repository.create('Primera');
    final second = await repository.create('Segunda');

    var list = await repository.watchPlaylists().first;
    expect(list.map((p) => p.name), ['Segunda', 'Primera']);
    expect(list.last.createdAt, list.last.updatedAt);

    await repository.rename(first, 'Primera renombrada');
    list = await repository.watchPlaylists().first;
    expect(list.map((p) => p.id), [first, second]);
    expect(list.first.name, 'Primera renombrada');
    expect(list.first.updatedAt.isAfter(list.first.createdAt), isTrue);
  });

  test('añade al final, permite duplicados y calcula conteo y duración',
      () async {
    final id = await repository.create('Mix');
    await repository.addSongs(id, [a, b]);
    await repository.addSongs(id, [a]);

    expect(await songIds(id), [1, 2, 1]);
    expect(await positions(id), [0, 1, 2]);

    final summary = await playlist(id);
    expect(summary.songCount, 3);
    expect(summary.totalDurationMs, 240000);
    expect(summary.coverSongIds, [1, 2, 1]);
  });

  test('la portada son las 4 primeras canciones en orden', () async {
    final id = await repository.create('Mix');
    await repository.addSongs(id, [e, d, c, b, a]);
    expect((await playlist(id)).coverSongIds, [5, 4, 3, 2]);
  });

  test('quitar deja las posiciones contiguas', () async {
    final id = await repository.create('Mix');
    await repository.addSongs(id, [a, b, c, d]);
    final entries = await repository.getEntries(id);

    await repository.removeEntry(entries[1].id);

    expect(await songIds(id), [1, 3, 4]);
    expect(await positions(id), [0, 1, 2]);
  });

  test('reinsertar vuelve a la posición original con el mismo id', () async {
    final id = await repository.create('Mix');
    await repository.addSongs(id, [a, b, c, d]);
    final removed = (await repository.getEntries(id))[2];

    await repository.removeEntry(removed.id);
    await repository.reinsertEntry(removed);

    final entries = await repository.getEntries(id);
    expect(entries.map((e) => e.songId), [1, 2, 3, 4]);
    expect(entries.map((e) => e.position), [0, 1, 2, 3]);
    expect(entries[2].id, removed.id);
  });

  test('mover hacia abajo y hacia arriba', () async {
    final id = await repository.create('Mix');
    await repository.addSongs(id, [a, b, c, d, e]);

    await repository.move(id, 0, 3);
    expect(await songIds(id), [2, 3, 4, 1, 5]);

    await repository.move(id, 4, 1);
    expect(await songIds(id), [2, 5, 3, 4, 1]);
    expect(await positions(id), [0, 1, 2, 3, 4]);
  });

  test('mover fuera de rango no cambia nada', () async {
    final id = await repository.create('Mix');
    await repository.addSongs(id, [a, b]);

    await repository.move(id, 0, 5);
    await repository.move(id, -1, 0);
    expect(await songIds(id), [1, 2]);
  });

  test('borrar elimina sus canciones en cascada', () async {
    final id = await repository.create('Mix');
    await repository.addSongs(id, [a, b]);

    await repository.delete(id);

    expect(await repository.watchPlaylists().first, isEmpty);
    expect(await db.query(TakiDatabase.playlistSongsTable), isEmpty);
  });

  test('relink cambia la canción sin tocar updated_at', () async {
    final id = await repository.create('Mix');
    await repository.addSongs(id, [a]);
    final before = await playlist(id);
    final entry = (await repository.getEntries(id)).single;

    final moved = buildSong(id: 77, title: 'A movida');
    await repository.relink(entry.id, moved);

    final after = (await repository.getEntries(id)).single;
    expect(after.songId, 77);
    expect(after.title, 'A movida');
    expect((await playlist(id)).updatedAt, before.updatedAt);
  });

  test('cada cambio emite en el stream', () async {
    final names = <List<String>>[];
    final subscription = repository
        .watchPlaylists()
        .listen((list) => names.add([for (final p in list) p.name]));
    addTearDown(subscription.cancel);
    await pumpEventQueue();

    final id = await repository.create('Uno');
    await pumpEventQueue();
    await repository.addSongs(id, [a]);
    await pumpEventQueue();
    await repository.rename(id, 'Uno bis');
    await pumpEventQueue();
    await repository.delete(id);
    await pumpEventQueue();

    expect(names, [
      <String>[],
      ['Uno'],
      ['Uno'],
      ['Uno bis'],
      <String>[],
    ]);
  });

  test('las escrituras se serializan', () async {
    final id = await repository.create('Mix');
    unawaited(repository.addSongs(id, [a]));
    unawaited(repository.addSongs(id, [b]));
    await repository.addSongs(id, [c]);

    expect(await songIds(id), [1, 2, 3]);
    expect(await positions(id), [0, 1, 2]);
  });
}
