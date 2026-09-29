import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taki/core/database/taki_database.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  Future<Set<String>> tables(Database db) async => {
        for (final row in await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'table'",
        ))
          row['name']! as String,
      };

  test('instalación nueva: crea favoritos y playlists, versión 2', () async {
    final db = await TakiDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    addTearDown(db.close);

    expect(await db.getVersion(), 2);
    expect(
      await tables(db),
      containsAll(['favorites', 'playlists', 'playlist_songs']),
    );
    final foreignKeys = await db.rawQuery('PRAGMA foreign_keys');
    expect(foreignKeys.single.values.single, 1);
    final indexes = await db.rawQuery('PRAGMA index_list(playlist_songs)');
    expect(
      indexes.map((i) => i['name']),
      contains('idx_playlist_songs_position'),
    );
  });

  test('migración v1 → v2: conserva los favoritos y crea las playlists',
      () async {
    final dir = await Directory.systemTemp.createTemp('taki_migration');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/taki.db';

    // Base tal como la dejaba la versión 1 de la app.
    final v1 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE favorites (
              song_id INTEGER PRIMARY KEY,
              added_at INTEGER NOT NULL,
              title TEXT, artist TEXT, album TEXT,
              duration_ms INTEGER, path TEXT
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_favorites_added_at ON favorites (added_at)',
          );
        },
      ),
    );
    await v1.insert('favorites', {
      'song_id': 42,
      'added_at': 1000,
      'title': 'Favorita',
      'path': '/music/favorita.mp3',
    });
    await v1.close();

    final db = await TakiDatabase.open(factory: databaseFactoryFfi, path: path);
    addTearDown(db.close);

    expect(await db.getVersion(), 2);
    final favorites = await db.query('favorites');
    expect(favorites.single['song_id'], 42);
    expect(favorites.single['title'], 'Favorita');
    expect(await tables(db), containsAll(['playlists', 'playlist_songs']));

    // Las tablas nuevas funcionan, con borrado en cascada.
    final id = await db.insert(
      'playlists',
      {'name': 'Nueva', 'created_at': 1, 'updated_at': 1},
    );
    await db.insert('playlist_songs', {
      'playlist_id': id,
      'position': 0,
      'song_id': 42,
    });
    await db.delete('playlists', where: 'id = ?', whereArgs: [id]);
    expect(await db.query('playlist_songs'), isEmpty);
  });
}
