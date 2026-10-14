import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../../../core/database/taki_database.dart';
import '../../../core/domain/entities/music_identity.dart';
import '../domain/ports/play_history_repository.dart';

/// [PlayHistoryRepository] over the `play_history` table of `taki.db`.
///
/// - One row per identity: a repeat updates the row (`last_played_at`,
///   `play_count`) instead of adding another.
/// - The table is capped at [maxEntries]; the oldest rows go first.
/// - Writes are serialized, and [watchRecent] queries again after each one.
class SqflitePlayHistoryRepository implements PlayHistoryRepository {
  SqflitePlayHistoryRepository(
    this._database, {
    DateTime Function()? clock,
    this.maxEntries = 200,
  }) : _clock = clock ?? DateTime.now;

  static const String _table = TakiDatabase.playHistoryTable;
  static const String _byIdentity = 'source = ? AND external_id = ?';

  final Future<Database> Function() _database;
  final DateTime Function() _clock;
  final int maxEntries;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  Future<void> _pendingWrite = Future.value();

  @override
  Future<void> record(MusicIdentity identity) =>
      _write((db) => db.transaction<void>((txn) async {
            final now = _clock().millisecondsSinceEpoch;
            final updated = await txn.rawUpdate(
              'UPDATE $_table SET last_played_at = ?, '
              'play_count = play_count + 1 WHERE $_byIdentity',
              [now, identity.source, identity.externalId],
            );
            if (updated == 0) {
              await txn.insert(_table, {
                'source': identity.source,
                'external_id': identity.externalId,
                'last_played_at': now,
                'play_count': 1,
              });
            }
            await txn.rawDelete(
              'DELETE FROM $_table WHERE rowid NOT IN ('
              'SELECT rowid FROM $_table '
              'ORDER BY last_played_at DESC, rowid DESC LIMIT ?)',
              [maxEntries],
            );
          }));

  @override
  Future<List<MusicIdentity>> recent({int limit = 20}) async {
    final db = await _database();
    final rows = await db.query(
      _table,
      columns: ['source', 'external_id'],
      orderBy: 'last_played_at DESC, rowid DESC',
      limit: limit,
    );
    return [
      for (final row in rows)
        MusicIdentity(row['source']! as String, row['external_id']! as String),
    ];
  }

  @override
  Stream<List<MusicIdentity>> watchRecent({int limit = 20}) {
    StreamSubscription<void>? subscription;
    late final StreamController<List<MusicIdentity>> controller;

    Future<void> emit() async {
      try {
        final identities = await recent(limit: limit);
        if (!controller.isClosed) controller.add(identities);
      } catch (error, stackTrace) {
        if (!controller.isClosed) controller.addError(error, stackTrace);
      }
    }

    controller = StreamController<List<MusicIdentity>>(
      onListen: () {
        subscription = _changes.stream.listen((_) => emit());
        emit();
      },
      onCancel: () {
        subscription?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<void> clear() => _write((db) => db.delete(_table));

  Future<void> dispose() => _changes.close();

  Future<void> _write(Future<Object?> Function(Database db) operation) {
    final result = _pendingWrite.then((_) async {
      await operation(await _database());
      if (!_changes.isClosed) _changes.add(null);
    });
    _pendingWrite = result.catchError((Object _) {});
    return result;
  }
}
