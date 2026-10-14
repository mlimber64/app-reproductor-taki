import 'dart:async';

import '../../../core/domain/entities/local_song.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/taki_database.dart';
import '../../../core/domain/entities/music_identity.dart';
import '../../../core/domain/entities/song.dart';
import '../domain/entities/favorite_entry.dart';
import '../domain/ports/favorites_repository.dart';

/// [FavoritesRepository] sobre la tabla `favorites` de `taki.db`.
///
/// - Cada favorito se identifica por `source` + `external_id` (la
///   [MusicIdentity], tal cual, sin normalizar).
/// - Las escrituras se serializan (una detrás de otra).
/// - [watchFavoriteIdentities] vuelve a consultar tras cada escritura, avisado
///   por un StreamController interno: sin polling.
/// - La base se pide con [_database] en cada operación; si no se pudo abrir,
///   cada operación falla con ese error y la UI lo muestra.
class SqfliteFavoritesRepository implements FavoritesRepository {
  SqfliteFavoritesRepository(
    this._database, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const String _table = TakiDatabase.favoritesTable;
  static const String _byIdentity = 'source = ? AND external_id = ?';

  final Future<Database> Function() _database;
  final DateTime Function() _clock;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  Future<void> _pendingWrite = Future.value();

  @override
  Stream<Set<MusicIdentity>> watchFavoriteIdentities() {
    StreamSubscription<void>? subscription;
    late final StreamController<Set<MusicIdentity>> controller;

    Future<void> emit() async {
      try {
        final identities = await _favoriteIdentities();
        if (!controller.isClosed) controller.add(identities);
      } catch (error, stackTrace) {
        if (!controller.isClosed) controller.addError(error, stackTrace);
      }
    }

    controller = StreamController<Set<MusicIdentity>>(
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
            ..._identity(song.musicIdentity),
            'added_at': _clock().millisecondsSinceEpoch,
            ..._backup(song),
          },
          // Si ya era favorita se conserva la fecha original.
          conflictAlgorithm: ConflictAlgorithm.ignore,
        ));
  }

  @override
  Future<void> remove(MusicIdentity identity) {
    return _write(
      (db) => db.delete(
        _table,
        where: _byIdentity,
        whereArgs: [identity.source, identity.externalId],
      ),
    );
  }

  @override
  Future<void> relink(MusicIdentity oldIdentity, Song song) {
    final identity = song.musicIdentity;
    if (oldIdentity == identity) return Future.value();
    return _write((db) => db.transaction<void>((txn) async {
          final existing = await txn.query(
            _table,
            columns: ['source'],
            where: _byIdentity,
            whereArgs: [identity.source, identity.externalId],
          );
          if (existing.isNotEmpty) {
            // La identidad nueva ya es favorita: sobra el registro viejo.
            await txn.delete(
              _table,
              where: _byIdentity,
              whereArgs: [oldIdentity.source, oldIdentity.externalId],
            );
            return;
          }
          await txn.update(
            _table,
            {..._identity(identity), ..._backup(song)},
            where: _byIdentity,
            whereArgs: [oldIdentity.source, oldIdentity.externalId],
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

  Future<Set<MusicIdentity>> _favoriteIdentities() async {
    final db = await _database();
    final rows = await db.query(_table, columns: ['source', 'external_id']);
    return {for (final row in rows) _toIdentity(row)};
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

  static FavoriteEntry _toEntry(Map<String, Object?> row) {
    return FavoriteEntry(
      musicIdentity: _toIdentity(row),
      addedAt: DateTime.fromMillisecondsSinceEpoch(row['added_at']! as int),
      title: row['title'] as String?,
      artist: row['artist'] as String?,
      album: row['album'] as String?,
      durationMs: row['duration_ms'] as int?,
      path: row['path'] as String?,
    );
  }
}
