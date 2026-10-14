import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taki/core/database/taki_database.dart';
import 'package:taki/core/domain/entities/local_music_identity.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/features/library/infrastructure/sqflite_favorites_repository.dart';
import 'package:taki/features/playlists/infrastructure/sqflite_playlists_repository.dart';

import '../../helpers/universal_song.dart';
import '../../helpers/library_fakes.dart';

// Esquemas congelados de las versiones anteriores: son lo que tienen las
// instalaciones existentes y no deben cambiar aunque cambie el código.
const _v1Favorites = '''
  CREATE TABLE favorites (
    song_id INTEGER PRIMARY KEY,
    added_at INTEGER NOT NULL,
    title TEXT, artist TEXT, album TEXT,
    duration_ms INTEGER, path TEXT
  )
''';
const _v1FavoritesIndex =
    'CREATE INDEX idx_favorites_added_at ON favorites (added_at)';
const _v2Playlists = '''
  CREATE TABLE playlists (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  )
''';
const _v2PlaylistSongs = '''
  CREATE TABLE playlist_songs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    playlist_id INTEGER NOT NULL
      REFERENCES playlists (id) ON DELETE CASCADE,
    position INTEGER NOT NULL,
    song_id INTEGER NOT NULL,
    title TEXT, artist TEXT, album TEXT,
    duration_ms INTEGER, path TEXT
  )
''';
const _v2PlaylistSongsIndex =
    'CREATE INDEX idx_playlist_songs_position '
    'ON playlist_songs (playlist_id, position)';

/// Tables of the current schema: the identity ones plus history and preferences.
const _v4Tables = {
  'favorites',
  'playlists',
  'playlist_songs',
  'play_history',
  'preferences',
};

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory dir;
  late String path;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('taki_migration');
    path = '${dir.path}/taki.db';
  });
  tearDown(() => dir.delete(recursive: true));

  Future<Set<String>> tables(Database db) async => {
        for (final row in await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%'",
        ))
          row['name']! as String,
      };

  Future<int> count(Database db, String table) async =>
      (await db.rawQuery('SELECT COUNT(*) AS n FROM $table')).single['n']! as int;

  Future<List<String>> columns(Database db, String table) async => [
        for (final c in await db.rawQuery('PRAGMA table_info($table)'))
          c['name']! as String,
      ];

  Future<Set<String>> indexes(Database db, String table) async => {
        for (final i in await db.rawQuery('PRAGMA index_list($table)'))
          i['name']! as String,
      };

  /// Crea una base tal como la dejaba la versión [version] de la app.
  Future<Database> createLegacy(
    int version, {
    Future<void> Function(Database db)? seed,
  }) async {
    final db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          await db.execute(_v1Favorites);
          await db.execute(_v1FavoritesIndex);
          if (version >= 2) {
            await db.execute(_v2Playlists);
            await db.execute(_v2PlaylistSongs);
            await db.execute(_v2PlaylistSongsIndex);
          }
        },
      ),
    );
    if (seed != null) await seed(db);
    return db;
  }

  Future<Database> migrate() =>
      TakiDatabase.open(factory: databaseFactoryFfi, path: path);

  Future<void> fav(Database db, int songId, int addedAt,
      {String? title, String? path}) {
    return db.insert('favorites', {
      'song_id': songId,
      'added_at': addedAt,
      'title': title,
      'artist': 'Artista',
      'album': 'Álbum',
      'duration_ms': 1000 + songId,
      'path': path,
    });
  }

  Future<int> playlist(Database db, String name, int createdAt) => db.insert(
        'playlists',
        {'name': name, 'created_at': createdAt, 'updated_at': createdAt + 1},
      );

  Future<int> entry(Database db, int playlistId, int position, int songId,
      {String? title}) {
    return db.insert('playlist_songs', {
      'playlist_id': playlistId,
      'position': position,
      'song_id': songId,
      'title': title ?? 'Canción $songId',
      'artist': 'Artista',
      'album': 'Álbum',
      'duration_ms': 1000 * songId,
      'path': '/m/$songId.mp3',
    });
  }

  group('instalación nueva', () {
    test('crea el esquema v3 con identidad fuente + id externo', () async {
      final db = await TakiDatabase.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      addTearDown(db.close);

      expect(await db.getVersion(), 4);
      expect(await tables(db),
          _v4Tables);
      expect(await columns(db, 'favorites'), [
        'source',
        'external_id',
        'added_at',
        'title',
        'artist',
        'album',
        'duration_ms',
        'path',
      ]);
      expect(await columns(db, 'playlist_songs'), [
        'id',
        'playlist_id',
        'position',
        'source',
        'external_id',
        'title',
        'artist',
        'album',
        'duration_ms',
        'path',
      ]);
      expect(await columns(db, 'playlist_songs'), isNot(contains('song_id')));
      expect(await indexes(db, 'playlist_songs'),
          contains('idx_playlist_songs_position'));
      expect(await indexes(db, 'favorites'), contains('idx_favorites_added_at'));
      final foreignKeys = await db.rawQuery('PRAGMA foreign_keys');
      expect(foreignKeys.single.values.single, 1);
    });

    test('la clave primaria de favoritos es (source, external_id)', () async {
      final db = await TakiDatabase.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      addTearDown(db.close);

      final pk = {
        for (final c in await db.rawQuery('PRAGMA table_info(favorites)'))
          if ((c['pk']! as int) > 0) c['pk']! as int: c['name'],
      };
      expect(pk, {1: 'source', 2: 'external_id'});
    });
  });

  group('v2 → v3 (instalaciones existentes)', () {
    test('base existente sin datos', () async {
      await (await createLegacy(2)).close();

      final db = await migrate();
      addTearDown(db.close);

      expect(await db.getVersion(), 4);
      expect(await db.query('favorites'), isEmpty);
      expect(await db.query('playlists'), isEmpty);
      expect(await db.query('playlist_songs'), isEmpty);
      expect(await columns(db, 'favorites'), contains('external_id'));
      expect(await indexes(db, 'favorites'), contains('idx_favorites_added_at'));
      expect(await indexes(db, 'playlist_songs'),
          contains('idx_playlist_songs_position'));
    });

    test('un favorito local se conserva como ("local", "42")', () async {
      final legacy = await createLegacy(2);
      await fav(legacy, 42, 5000, title: 'Favorita', path: '/m/f.mp3');
      await legacy.close();

      final db = await migrate();
      addTearDown(db.close);

      final rows = await db.query('favorites');
      expect(rows, hasLength(1));
      expect(rows.single['source'], 'local');
      expect(rows.single['external_id'], '42');
      expect(rows.single['external_id'], isA<String>());
      expect(rows.single['added_at'], 5000);
      expect(rows.single['title'], 'Favorita');
      expect(rows.single['artist'], 'Artista');
      expect(rows.single['album'], 'Álbum');
      expect(rows.single['duration_ms'], 1042);
      expect(rows.single['path'], '/m/f.mp3');
    });

    test('varios favoritos: todos se conservan y el orden no cambia',
        () async {
      final legacy = await createLegacy(2);
      // Dos comparten fecha: en v2 el desempate era `rowid DESC` y, como `song_id`
      // era el rowid, equivalía a `song_id DESC`. La migración copia por rowid
      // ascendente, así que el desempate sigue dando el mismo orden.
      await fav(legacy, 7, 1000);
      await fav(legacy, 1000000, 3000);
      await fav(legacy, 3, 2000);
      await fav(legacy, 99, 3000);
      await legacy.close();

      final db = await migrate();
      addTearDown(db.close);

      final repository = SqfliteFavoritesRepository(() async => db);
      addTearDown(repository.dispose);
      final favorites = await repository.getFavorites();

      expect(favorites.map((e) => e.musicIdentity), [
        localMusicIdentity(1000000), // misma fecha que 99: gana el id mayor
        localMusicIdentity(99),
        localMusicIdentity(3),
        localMusicIdentity(7),
      ]);
      expect(favorites.map((e) => e.addedAt.millisecondsSinceEpoch),
          [3000, 3000, 2000, 1000]);
    });

    test('playlist vacía', () async {
      final legacy = await createLegacy(2);
      final id = await playlist(legacy, 'Vacía', 100);
      await legacy.close();

      final db = await migrate();
      addTearDown(db.close);

      final rows = await db.query('playlists');
      expect(rows.single['id'], id);
      expect(rows.single['name'], 'Vacía');
      expect(rows.single['created_at'], 100);
      expect(rows.single['updated_at'], 101);
      expect(await db.query('playlist_songs'), isEmpty);
    });

    test('playlist con canciones: orden, posiciones, ids de entrada y '
        'respaldo se conservan', () async {
      final legacy = await createLegacy(2);
      final id = await playlist(legacy, 'Mix', 100);
      final e1 = await entry(legacy, id, 0, 30);
      final e2 = await entry(legacy, id, 1, 10);
      final e3 = await entry(legacy, id, 2, 30); // la misma canción otra vez
      await legacy.close();

      final db = await migrate();
      addTearDown(db.close);

      final rows = await db.query('playlist_songs', orderBy: 'position');
      expect(rows.map((r) => r['id']), [e1, e2, e3]);
      expect(rows.map((r) => r['playlist_id']), [id, id, id]);
      expect(rows.map((r) => r['position']), [0, 1, 2]);
      expect(rows.map((r) => r['source']), ['local', 'local', 'local']);
      expect(rows.map((r) => r['external_id']), ['30', '10', '30']);
      expect(rows.first['title'], 'Canción 30');
      expect(rows.first['path'], '/m/30.mp3');
      expect(rows.first['duration_ms'], 30000);
    });

    test('los ids de entrada se conservan aunque haya huecos', () async {
      final legacy = await createLegacy(2);
      final p = await playlist(legacy, 'Mix', 100);
      await entry(legacy, p, 0, 1);
      final gap = await entry(legacy, p, 1, 2);
      final e3 = await entry(legacy, p, 2, 3);
      await legacy.delete('playlist_songs', where: 'id = ?', whereArgs: [gap]);
      await legacy.rawUpdate(
          'UPDATE playlist_songs SET position = 1 WHERE id = ?', [e3]);
      await legacy.close();

      final db = await migrate();
      addTearDown(db.close);

      final rows = await db.query('playlist_songs', orderBy: 'position');
      expect(rows.map((r) => r['id']), [1, e3]);
      expect(rows.map((r) => r['external_id']), ['1', '3']);
    });
    test('varias playlists (y una vacía entre ellas)', () async {
      final legacy = await createLegacy(2);
      final p1 = await playlist(legacy, 'Una', 100);
      final p2 = await playlist(legacy, 'Dos', 200);
      final p3 = await playlist(legacy, 'Tres', 300);
      await entry(legacy, p1, 0, 1);
      await entry(legacy, p1, 1, 2);
      await entry(legacy, p3, 0, 2);
      await legacy.close();

      final db = await migrate();
      addTearDown(db.close);

      final repository = SqflitePlaylistsRepository(() async => db);
      addTearDown(repository.dispose);
      final playlists = await repository.watchPlaylists().first;
      final byId = {for (final p in playlists) p.id: p};

      expect(byId[p1]!.songCount, 2);
      expect(byId[p1]!.coverIdentities,
          [localMusicIdentity(1), localMusicIdentity(2)]);
      expect(byId[p2]!.songCount, 0);
      expect(byId[p3]!.coverIdentities, [localMusicIdentity(2)]);
      expect([
        for (final e in await repository.getEntries(p1)) e.musicIdentity,
      ], [localMusicIdentity(1), localMusicIdentity(2)]);
    });

    test('favoritos y playlists juntos', () async {
      final legacy = await createLegacy(2);
      await fav(legacy, 5, 10);
      await fav(legacy, 6, 20);
      final p = await playlist(legacy, 'Mix', 1);
      await entry(legacy, p, 0, 5);
      await legacy.close();

      final db = await migrate();
      addTearDown(db.close);

      expect(await db.query('favorites'), hasLength(2));
      expect(await db.query('playlist_songs'), hasLength(1));
      expect(await db.query('playlists'), hasLength(1));
    });

    test('la secuencia de ids de entrada no se reutiliza', () async {
      final legacy = await createLegacy(2);
      final p = await playlist(legacy, 'Mix', 1);
      await entry(legacy, p, 0, 1);
      await entry(legacy, p, 1, 2);
      final last = await entry(legacy, p, 2, 3);
      // Se borra la última: la secuencia de la tabla sigue en 3.
      await legacy.delete('playlist_songs', where: 'id = ?', whereArgs: [last]);
      await legacy.close();

      final db = await migrate();
      addTearDown(db.close);

      final newId = await db.insert('playlist_songs', {
        'playlist_id': p,
        'position': 2,
        'source': 'local',
        'external_id': '9',
      });
      expect(newId, greaterThan(last));
    });

    test('la secuencia se conserva aunque no quede ninguna entrada', () async {
      final legacy = await createLegacy(2);
      final p = await playlist(legacy, 'Mix', 1);
      await entry(legacy, p, 0, 1);
      final last = await entry(legacy, p, 1, 2);
      await legacy.delete('playlist_songs');
      await legacy.close();

      final db = await migrate();
      addTearDown(db.close);

      final newId = await db.insert('playlist_songs', {
        'playlist_id': p,
        'position': 0,
        'source': 'local',
        'external_id': '9',
      });
      expect(newId, greaterThan(last));
    });

    test('muchos datos: no se pierde ninguna fila', () async {
      final legacy = await createLegacy(2);
      final batch = legacy.batch();
      for (var i = 1; i <= 2000; i++) {
        batch.insert('favorites', {'song_id': i, 'added_at': i});
      }
      await batch.commit(noResult: true);
      final p = await playlist(legacy, 'Grande', 1);
      final entries = legacy.batch();
      for (var i = 0; i < 3000; i++) {
        entries.insert('playlist_songs', {
          'playlist_id': p,
          'position': i,
          'song_id': i % 500 + 1,
        });
      }
      await entries.commit(noResult: true);
      await legacy.close();

      final db = await migrate();
      addTearDown(db.close);

      expect(await count(db, 'favorites'), 2000);
      expect(await count(db, 'playlist_songs'), 3000);
      expect(
        (await db.rawQuery(
          "SELECT COUNT(*) AS n FROM favorites WHERE source = 'local' "
          'AND external_id = CAST(added_at AS TEXT)',
        ))
            .single['n'],
        2000,
        reason: 'cada id entero pasó a su texto decimal',
      );
    });

    test('se ejecuta una sola vez: reabrir la base v3 no cambia nada',
        () async {
      final legacy = await createLegacy(2);
      await fav(legacy, 42, 1);
      await legacy.close();

      final first = await migrate();
      final snapshot = await first.query('favorites');
      await first.close();

      final second = await migrate();
      addTearDown(second.close);

      expect(await second.getVersion(), 4);
      expect(await second.query('favorites'), snapshot);
      expect(await tables(second), _v4Tables);
    });
  });

  group('v1 → v3', () {
    test('conserva los favoritos y crea las playlists con el esquema nuevo',
        () async {
      final legacy = await createLegacy(1);
      await fav(legacy, 42, 1000, title: 'Favorita');
      await legacy.close();

      final db = await migrate();
      addTearDown(db.close);

      expect(await db.getVersion(), 4);
      final favorites = await db.query('favorites');
      expect(favorites.single['source'], 'local');
      expect(favorites.single['external_id'], '42');
      expect(favorites.single['title'], 'Favorita');
      expect(await tables(db), _v4Tables);
      expect(await columns(db, 'playlist_songs'), contains('external_id'));
      expect(await columns(db, 'playlist_songs'), isNot(contains('song_id')));

      // Las tablas nuevas funcionan, con borrado en cascada.
      final id = await db.insert(
          'playlists', {'name': 'Nueva', 'created_at': 1, 'updated_at': 1});
      await db.insert('playlist_songs', {
        'playlist_id': id,
        'position': 0,
        'source': 'local',
        'external_id': '42',
      });
      await db.delete('playlists', where: 'id = ?', whereArgs: [id]);
      expect(await db.query('playlist_songs'), isEmpty);
    });
  });

  group('atomicidad', () {
    test('si la migración falla a mitad, la base queda como estaba (v2)',
        () async {
      final legacy = await createLegacy(2, seed: (db) async {
        await fav(db, 42, 1000, title: 'Favorita');
        final p = await playlist(db, 'Mix', 1);
        await entry(db, p, 0, 42);
        // Una tabla con el nombre temporal que usa la migración para
        // playlist_songs: la migración de favoritos termina bien y la de
        // playlists falla después.
        await db.execute('CREATE TABLE playlist_songs_v3 (x INTEGER)');
      });
      await legacy.close();

      await expectLater(migrate(), throwsA(anything));

      final raw = await databaseFactoryFfi.openDatabase(path);
      addTearDown(raw.close);
      expect(await raw.getVersion(), 2);
      expect(await columns(raw, 'favorites'), contains('song_id'));
      expect(await columns(raw, 'favorites'), isNot(contains('source')));
      expect(await tables(raw), isNot(contains('favorites_v3')));
      final favorites = await raw.query('favorites');
      expect(favorites.single['song_id'], 42);
      expect(favorites.single['title'], 'Favorita');
      final entries = await raw.query('playlist_songs');
      expect(entries.single['song_id'], 42);
      expect(await columns(raw, 'playlist_songs'), contains('song_id'));
    });

    test('tras arreglar la causa, la migración se puede repetir', () async {
      final legacy = await createLegacy(2, seed: (db) async {
        await fav(db, 42, 1000);
        await db.execute('CREATE TABLE playlist_songs_v3 (x INTEGER)');
      });
      await legacy.close();
      await expectLater(migrate(), throwsA(anything));

      final repaired = await databaseFactoryFfi.openDatabase(path);
      await repaired.execute('DROP TABLE playlist_songs_v3');
      await repaired.close();

      final db = await migrate();
      addTearDown(db.close);
      expect(await db.getVersion(), 4);
      expect((await db.query('favorites')).single['external_id'], '42');
    });
  });

  group('restricciones tras migrar', () {
    late Database db;

    setUp(() async {
      final legacy = await createLegacy(2);
      await fav(legacy, 1, 1);
      await legacy.close();
      db = await migrate();
    });
    tearDown(() => db.close());

    test('identidad única por (source, external_id)', () async {
      await expectLater(
        db.insert('favorites', {
          'source': 'local',
          'external_id': '1',
          'added_at': 2,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('el mismo id externo en otra fuente es otra identidad', () async {
      await db.insert('favorites', {
        'source': 'otra',
        'external_id': '1',
        'added_at': 2,
      });
      expect(await db.query('favorites'), hasLength(2));
    });

    test('ids opacos: alfanuméricos, con ceros, sensibles a mayúsculas',
        () async {
      for (final id in ['abc123', 'track-xyz', '007', 'ABC', 'abc', '7']) {
        await db.insert('favorites', {
          'source': 'x',
          'external_id': id,
          'added_at': 3,
        });
      }
      final stored = {
        for (final r in await db.query('favorites', where: "source = 'x'"))
          r['external_id'] as String,
      };
      expect(stored, {'abc123', 'track-xyz', '007', 'ABC', 'abc', '7'});
    });

    test('CHECK: fuente o id vacíos o en blanco se rechazan', () async {
      for (final (source, id) in [('', 'a'), ('a', ''), (' ', 'a'), ('a', '  ')]) {
        await expectLater(
          db.insert('favorites',
              {'source': source, 'external_id': id, 'added_at': 1}),
          throwsA(isA<DatabaseException>()),
          reason: '"$source" / "$id"',
        );
      }
    });

    test('clave foránea y cascada en playlist_songs', () async {
      await expectLater(
        db.insert('playlist_songs', {
          'playlist_id': 12345,
          'position': 0,
          'source': 'local',
          'external_id': '1',
        }),
        throwsA(isA<DatabaseException>()),
      );

      final p = await db.insert(
          'playlists', {'name': 'P', 'created_at': 1, 'updated_at': 1});
      await db.insert('playlist_songs', {
        'playlist_id': p,
        'position': 0,
        'source': 'local',
        'external_id': '1',
      });
      await db.delete('playlists', where: 'id = ?', whereArgs: [p]);
      expect(await db.query('playlist_songs'), isEmpty);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    });
  });

  group('los repositorios funcionan sobre datos migrados', () {
    test('favoritos: el local migrado se reconoce y se puede quitar, y se '
        'pueden añadir identidades de otras fuentes', () async {
      final legacy = await createLegacy(2);
      await fav(legacy, 42, 1000, title: 'Vieja');
      await legacy.close();

      final db = await migrate();
      addTearDown(db.close);
      final repository = SqfliteFavoritesRepository(() async => db);
      addTearDown(repository.dispose);

      final song = buildSong(id: 42, title: 'Nueva etiqueta');
      expect(await repository.watchFavoriteIdentities().first,
          {song.musicIdentity});

      await repository.add(buildUniversalSong(MusicIdentity('otra', '42')));
      expect((await repository.watchFavoriteIdentities().first).length, 2);

      await repository.remove(song.musicIdentity);
      expect(await repository.watchFavoriteIdentities().first,
          {MusicIdentity('otra', '42')});
    });

    test('playlists: se puede reordenar y añadir tras migrar', () async {
      final legacy = await createLegacy(2);
      final p = await playlist(legacy, 'Mix', 1);
      await entry(legacy, p, 0, 1);
      await entry(legacy, p, 1, 2);
      await legacy.close();

      final db = await migrate();
      addTearDown(db.close);
      final repository = SqflitePlaylistsRepository(() async => db);
      addTearDown(repository.dispose);

      await repository.addSongs(p, [buildSong(id: 3), buildUniversalSong(MusicIdentity('otra', 'z'))]);
      await repository.move(p, 0, 3);

      expect([
        for (final e in await repository.getEntries(p)) e.musicIdentity,
      ], [
        localMusicIdentity(2),
        localMusicIdentity(3),
        MusicIdentity('otra', 'z'),
        localMusicIdentity(1),
      ]);
    });
  });
}
