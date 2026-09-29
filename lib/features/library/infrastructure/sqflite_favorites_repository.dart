import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../../../core/database/taki_database.dart';
import '../../../core/domain/entities/song.dart';
import '../domain/entities/favorite_entry.dart';
import '../domain/ports/favorites_repository.dart';

/// [FavoritesRepository] sobre la tabla `favorites` de `taki.db`.
///
/// - Las escrituras se serializan (una detrás de otra).
/// - [watchFavoriteIds] vuelve a consultar tras cada escritura, avisado por un
///   StreamController interno: sin polling.
/// - La base se pide con [_database] en cada operación; si no se pudo abrir,
///   cada operación falla con ese error y la UI lo muestra.
class SqfliteFavoritesRepository implements FavoritesRepository {
  SqfliteFavoritesRepository(
    this._database, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const String _table = TakiDatabase.favoritesTable;

  final Future<Database> Function() _database;
  final DateTime Function() _clock;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  Future<void> _pendingWrite = Future.value();

  @override
  Stream<Set<int>> watchFavoriteIds() {
    StreamSubscription<void>? subscription;
    late final StreamController<Set<int>> controller;

    Future<void> emit() async {
      try {
        final ids = await _favoriteIds();
        if (!controller.isClosed) controller.add(ids);
      } catch (error, stackTrace) {
        if (!controller.isClosed) controller.addError(error, stackTrace);
      }
    }

    controller = StreamController<Set<int>>(
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
  Future<List<FavoriteEntry>> getFavorites() async {
    final db = await _database();
    final rows = await db.query(_table, orderBy: 'added_at DESC, rowid DESC');
    return [for (final row in rows) _toEntry(row)];
  }

  @override
  Future<void> add(Song song) {
    return _write((db) => db.insert(
          _table,
          {
            'song_id': song.id,
            'added_at': _clock().millisecondsSinceEpoch,
            ..._backup(song),
          },
          // Si ya era favorita se conserva la fecha original.
          conflictAlgorithm: ConflictAlgorithm.ignore,
        ));
  }

  @override
  Future<void> remove(int songId) {
    return _write(
      (db) => db.delete(_table, where: 'song_id = ?', whereArgs: [songId]),
    );
  }

  @override
  Future<void> relink(int oldSongId, Song song) {
    if (oldSongId == song.id) return Future.value();
    return _write((db) => db.transaction<void>((txn) async {
          final existing = await txn.query(
            _table,
            columns: ['song_id'],
            where: 'song_id = ?',
            whereArgs: [song.id],
          );
          if (existing.isNotEmpty) {
            // El id nuevo ya es favorito: sobra el registro viejo.
            await txn.delete(
              _table,
              where: 'song_id = ?',
              whereArgs: [oldSongId],
            );
            return;
          }
          await txn.update(
            _table,
            {'song_id': song.id, ..._backup(song)},
            where: 'song_id = ?',
            whereArgs: [oldSongId],
          );
        }));
  }

  Future<void> dispose() => _changes.close();

  Future<void> _write(Future<Object?> Function(Database db) operation) {
    final result = _pendingWrite.then((_) async {
      await operation(await _database());
      if (!_changes.isClosed) _changes.add(null);
    });
    _pendingWrite = result.catchError((Object _) {});
    return result;
  }

  Future<Set<int>> _favoriteIds() async {
    final db = await _database();
    final rows = await db.query(_table, columns: ['song_id']);
    return {for (final row in rows) row['song_id']! as int};
  }

  static Map<String, Object?> _backup(Song song) => {
        'title': song.title,
        'artist': song.artist,
        'album': song.album,
        'duration_ms': song.durationMs,
        'path': song.path,
      };

  static FavoriteEntry _toEntry(Map<String, Object?> row) {
    return FavoriteEntry(
      songId: row['song_id']! as int,
      addedAt: DateTime.fromMillisecondsSinceEpoch(row['added_at']! as int),
      title: row['title'] as String?,
      artist: row['artist'] as String?,
      album: row['album'] as String?,
      durationMs: row['duration_ms'] as int?,
      path: row['path'] as String?,
    );
  }
}
