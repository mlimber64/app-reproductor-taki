import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/sqflite_preferences_store.dart';
import '../database/taki_database_provider.dart';
import '../domain/ports/preferences_store.dart';

/// The app's settings store, on the local database.
final preferencesStoreProvider = Provider<PreferencesStore>(
  (ref) => SqflitePreferencesStore(
    () => ref.read(takiDatabaseProvider.future),
  ),
);
