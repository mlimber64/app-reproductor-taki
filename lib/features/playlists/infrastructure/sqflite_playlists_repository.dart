import 'dart:async';

import '../../../core/domain/entities/local_song.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/taki_database.dart';
import '../../../core/domain/entities/music_identity.dart';
import '../../../core/domain/entities/song.dart';
import '../domain/entities/playlist.dart';
import '../domain/entities/playlist_entry.dart';
import '../domain/ports/playlists_repository.dart';

/// [PlaylistsRepository] sobre las tablas `playlists` y `playlist_songs`.
///
/// - Cada escritura es una transacción, y se ejecutan una detrás de otra.
/// - Las posiciones de cada playlist quedan siempre contiguas (0, 1, 2…).
/// - [watchPlaylists] vuelve a consultar tras cada escritura, avisado por un
///   StreamController interno: sin polling. Conteo, duración y portada se
///   calculan en la consulta.
class SqflitePlaylistsRepository implements PlaylistsRepository {
  SqflitePlaylistsRepository(
    this._database, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const String _playlists = TakiDatabase.playlistsTable;
  static const String _songs = TakiDatabase.playlistSongsTable;

  /// Canciones que se usan para el mosaico de portada.
  static const int _coverSize = 4;

  final Future<Database> Function() _database;
  final DateTime Function() _clock;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  Future<void> _pendingWrite = Future.value();

  @override
  Stream<List<Playlist>> watchPlaylists() {
    StreamSubscription<void>? subscription;
    late final StreamController<List<Playlist>> controller;

    Future<void> emit() async {
      try {
        final playlists = await _queryPlaylists();
        if (!controller.isClosed) controller.add(playlists);
      } catch (error, stackTrace) {
        if (!controller.isClosed) controller.addError(error, stackTrace);
      }
    }

    controller = StreamController<List<Playlist>>(
      onListen: () {
        subscription = _changes.stream.listen((_) => emit());
        emit();
      },
      // Sin esperar la cancelación interna: así `first` termina enseguida.
      onCancel: () {
        subscription?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<List<PlaylistEntry>> getEntries(int playlistId) async {
    final db = await _database();
    final rows = await db.query(
      _songs,
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
      orderBy: 'position',
    );
    return [for (final row in rows) _toEntry(row)];
  }

  @override
  Future<int> create(String name) async {
    late int id;
    await _write((txn) async {
      final now = _clock().millisecondsSinceEpoch;
      id = await txn.insert(_playlists, {
        'name': name,
        'created_at': now,
        'updated_at': now,
      });
    });
    return id;
  }

  @override
  Future<void> rename(int playlistId, String name) {
    return _write((txn) => txn.update(
          _playlists,
          {'name': name, 'updated_at': _now()},
          where: 'id = ?',
          whereArgs: [playlistId],
        ));
  }

  @override
  Future<void> delete(int playlistId) {
    // Las entradas se borran en cascada (clave foránea).
    return _write((txn) =>
        txn.delete(_playlists, where: 'id = ?', whereArgs: [playlistId]));
  }

  @override
  Future<void> addSongs(int playlistId, List<Song> songs) {
    if (songs.isEmpty) return Future.value();
    return _write((txn) async {
      var position = await _count(txn, playlistId);
      final batch = txn.batch();
      for (final song in songs) {
        batch.insert(_songs, {
          'playlist_id': playlistId,
          'position': position++,
          ..._identity(song.musicIdentity),
          ..._backup(song),
        });
      }
      await batch.commit(noResult: true);
      await _touch(txn, playlistId);
    });
  }

  @override
  Future<void> removeEntry(int entryId) {
    return _write((txn) async {
      final rows = await txn.query(
        _songs,
        columns: ['playlist_id', 'position'],
        where: 'id = ?',
        whereArgs: [entryId],
      );
      if (rows.isEmpty) return;
      final playlistId = rows.single['playlist_id']! as int;
      final position = rows.single['position']! as int;

      await txn.delete(_songs, where: 'id = ?', whereArgs: [entryId]);
      await txn.rawUpdate(
        'UPDATE $_songs SET position = position - 1 '
        'WHERE playlist_id = ? AND position > ?',
        [playlistId, position],
      );
      await _touch(txn, playlistId);
    });
  }

  @override
  Future<void> reinsertEntry(PlaylistEntry entry) {
    return _write((txn) async {
      final exists = await txn.query(
        _playlists,
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [entry.playlistId],
      );
      if (exists.isEmpty) return; // La playlist se borró mientras tanto.

      final count = await _count(txn, entry.playlistId);
      final position = entry.position.clamp(0, count);
      await txn.rawUpdate(
        'UPDATE $_songs SET position = position + 1 '
        'WHERE playlist_id = ? AND position >= ?',
        [entry.playlistId, position],
      );
      // Se reutiliza el id original si sigue libre (lo normal tras Deshacer).
      final idTaken = await txn.query(
        _songs,
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [entry.id],
      );
      await txn.insert(_songs, {
        if (idTaken.isEmpty) 'id': entry.id,
        'playlist_id': entry.playlistId,
        'position': position,
        ..._identity(entry.musicIdentity),
        'title': entry.title,
        'artist': entry.artist,
        'album': entry.album,
        'duration_ms': entry.durationMs,
        'path': entry.path,
      });
      await _touch(txn, entry.playlistId);
    });
  }

  @override
  Future<void> move(int playlistId, int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return Future.value();
    return _write((txn) async {
      final count = await _count(txn, playlistId);
      if (oldIndex < 0 ||
          newIndex < 0 ||
          oldIndex >= count ||
          newIndex >= count) {
        return;
      }
      final moving = await txn.query(
        _songs,
        columns: ['id'],
        where: 'playlist_id = ? AND position = ?',
        whereArgs: [playlistId, oldIndex],
      );
      if (moving.isEmpty) return;

      if (oldIndex < newIndex) {
        await txn.rawUpdate(
          'UPDATE $_songs SET position = position - 1 '
          'WHERE playlist_id = ? AND position > ? AND position <= ?',
          [playlistId, oldIndex, newIndex],
        );
      } else {
        await txn.rawUpdate(
          'UPDATE $_songs SET position = position + 1 '
          'WHERE playlist_id = ? AND position >= ? AND position < ?',
          [playlistId, newIndex, oldIndex],
        );
      }
      await txn.update(
        _songs,
        {'position': newIndex},
        where: 'id = ?',
        whereArgs: [moving.single['id']],
      );
      await _touch(txn, playlistId);
    });
  }

  @override
  Future<void> relink(int entryId, Song song) {
    return _write((txn) => txn.update(
          _songs,
          {..._identity(song.musicIdentity), ..._backup(song)},
          where: 'id = ?',
          whereArgs: [entryId],
        ));
  }

  Future<void> dispose() => _changes.close();

  Future<void> _write(Future<void> Function(Transaction txn) operation) {
    final result = _pendingWrite.then((_) async {
      final db = await _database();
      await db.transaction<void>((txn) async {
        await operation(txn);
      });
      if (!_changes.isClosed) _changes.add(null);
    });
    _pendingWrite = result.catchError((Object _) {});
    return result;
  }

  int _now() => _clock().millisecondsSinceEpoch;

  Future<void> _touch(Transaction txn, int playlistId) => txn.update(
        _playlists,
        {'updated_at': _now()},
        where: 'id = ?',
        whereArgs: [playlistId],
      );

  static Future<int> _count(Transaction txn, int playlistId) async {
    final rows = await txn.rawQuery(
      'SELECT COUNT(*) AS n FROM $_songs WHERE playlist_id = ?',
      [playlistId],
    );
    return rows.single['n']! as int;
  }

  Future<List<Playlist>> _queryPlaylists() async {
    final db = await _database();
    final rows = await db.rawQuery('''
      SELECT p.id, p.name, p.created_at, p.updated_at,
        COUNT(s.id) AS song_count,
        COALESCE(SUM(s.duration_ms), 0) AS total_ms
      FROM $_playlists p
      LEFT JOIN $_songs s ON s.playlist_id = p.id
      GROUP BY p.id
      ORDER BY p.updated_at DESC, p.id DESC
    ''');

    // Las posiciones son contiguas desde 0: "position < 4" son las primeras 4.
    // Se piden aparte, una fila por entrada y ordenadas: los ids externos son
    // texto opaco y no pueden concatenarse con separadores sin riesgo.
    final coverRows = await db.query(
      _songs,
      columns: ['playlist_id', 'source', 'external_id'],
      where: 'position < ?',
      whereArgs: [_coverSize],
      orderBy: 'playlist_id, position',
    );
    final covers = <int, List<MusicIdentity>>{};
    for (final row in coverRows) {
      covers
          .putIfAbsent(row['playlist_id']! as int, () => [])
          .add(_toIdentity(row));
    }

    return [
      for (final row in rows)
        _toPlaylist(row, covers[row['id']! as int] ?? const []),
    ];
  }

  static Playlist _toPlaylist(
    Map<String, Object?> row,
    List<MusicIdentity> cover,
  ) {
    return Playlist(
      id: row['id']! as int,
      name: row['name']! as String,
      songCount: row['song_count']! as int,
      totalDurationMs: row['total_ms']! as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at']! as int),
      coverIdentities: List.unmodifiable(cover),
    );
  }

  static Map<String, Object?> _identity(MusicIdentity identity) => {
        'source': identity.source,
        'external_id': identity.externalId,
      };

  static MusicIdentity _toIdentity(Map<String, Object?> row) =>
      MusicIdentity(row['source']! as String, row['external_id']! as String);

  static Map<String, Object?> _backup(Song song) => {
        'title': song.title,
        'artist': song.artist,
        'album': song.album,
        'duration_ms': song.durationMs,
        'path': localPathOf(song),
      };

  static PlaylistEntry _toEntry(Map<String, Object?> row) {
    return PlaylistEntry(
      id: row['id']! as int,
      playlistId: row['playlist_id']! as int,
      position: row['position']! as int,
      musicIdentity: _toIdentity(row),
      title: row['title'] as String?,
      artist: row['artist'] as String?,
      album: row['album'] as String?,
      durationMs: row['duration_ms'] as int?,
      path: row['path'] as String?,
    );
  }
}
