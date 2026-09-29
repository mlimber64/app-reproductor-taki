import 'package:sqflite/sqflite.dart';

/// Base de datos local de Taki (`taki.db`). Se abre una sola vez al iniciar
/// la app (ver `main.dart`) y queda abierta durante toda su vida.
///
/// Versiones:
/// - v1: `favorites`.
/// - v2: `playlists` y `playlist_songs`.
abstract final class TakiDatabase {
  static const String fileName = 'taki.db';
  static const int version = 2;

  static const String favoritesTable = 'favorites';
  static const String playlistsTable = 'playlists';
  static const String playlistSongsTable = 'playlist_songs';

  /// Abre (o crea) la base. [factory] y [path] permiten usar sqflite_common_ffi
  /// y una base en memoria en los tests.
  static Future<Database> open({DatabaseFactory? factory, String? path}) async {
    final databases = factory ?? databaseFactory;
    final location =
        path ?? '${await databases.getDatabasesPath()}/$fileName';
    return databases.openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  /// Como [open], pero devuelve `null` si falla: la app arranca igual y las
  /// funciones que dependen de la base se muestran como no disponibles.
  static Future<Database?> tryOpen() async {
    try {
      return await open();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _onConfigure(Database db) async {
    // SQLite trae las claves foráneas desactivadas por conexión.
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Instalación nueva: crea el esquema completo de la versión actual.
  static Future<void> _onCreate(Database db, int version) async {
    await _createFavorites(db);
    await _createPlaylists(db);
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Un bloque por versión, en orden. Solo añaden; nunca tocan lo existente.
    // Para una v3: subir [version], añadir `if (oldVersion < 3) …` y crear lo
    // mismo en _onCreate.
    if (oldVersion < 2) await _createPlaylists(db);
  }

  static Future<void> _createFavorites(Database db) async {
    // Las columnas de texto son una copia de respaldo para reconocer la
    // canción si su id de MediaStore cambia (reescaneo, reinstalación…).
    await db.execute('''
      CREATE TABLE $favoritesTable (
        song_id INTEGER PRIMARY KEY,
        added_at INTEGER NOT NULL,
        title TEXT,
        artist TEXT,
        album TEXT,
        duration_ms INTEGER,
        path TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_favorites_added_at ON $favoritesTable (added_at)',
    );
  }

  static Future<void> _createPlaylists(Database db) async {
    await db.execute('''
      CREATE TABLE $playlistsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    // Una canción puede repetirse: cada fila es una entrada con su posición.
    await db.execute('''
      CREATE TABLE $playlistSongsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playlist_id INTEGER NOT NULL
          REFERENCES $playlistsTable (id) ON DELETE CASCADE,
        position INTEGER NOT NULL,
        song_id INTEGER NOT NULL,
        title TEXT,
        artist TEXT,
        album TEXT,
        duration_ms INTEGER,
        path TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_playlist_songs_position '
      'ON $playlistSongsTable (playlist_id, position)',
    );
  }
}
