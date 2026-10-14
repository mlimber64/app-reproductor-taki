import 'package:sqflite/sqflite.dart';

import '../domain/ports/preferences_store.dart';
import 'taki_database.dart';

/// [PreferencesStore] over the `preferences` table of `taki.db`.
class SqflitePreferencesStore implements PreferencesStore {
  SqflitePreferencesStore(this._database);

  static const String _table = TakiDatabase.preferencesTable;

  final Future<Database> Function() _database;

  @override
  Future<String?> read(String key) async {
    final db = await _database();
    final rows = await db.query(
      _table,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['value']! as String;
  }

  @override
  Future<void> write(String key, String value) async {
    final db = await _database();
    await db.insert(
      _table,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
