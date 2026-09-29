import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'taki_database.dart';

/// Conexión a `taki.db`.
///
/// `main.dart` la abre antes de `runApp` y la inyecta con un override. Si la
/// apertura falló no hay override: este provider vuelve a intentarlo al
/// usarse, y `ref.invalidate` sirve para "Reintentar".
final takiDatabaseProvider = FutureProvider<Database>(
  (ref) => TakiDatabase.open(),
);
