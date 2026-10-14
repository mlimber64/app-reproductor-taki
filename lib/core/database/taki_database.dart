import 'package:sqflite/sqflite.dart';

/// Base de datos local de Taki (`taki.db`). Se abre una sola vez al iniciar
/// la app (ver `main.dart`) y queda abierta durante toda su vida.
///
/// Versiones:
/// - v1: `favorites` (`song_id INTEGER PRIMARY KEY`).
/// - v2: `playlists` y `playlist_songs` (`song_id INTEGER NOT NULL`).
/// - v3: la canción se identifica por **fuente + id externo** (`source TEXT`,
///   `external_id TEXT`) en `favorites` y `playlist_songs`, en lugar de un id
///   entero. Es la persistencia de `MusicIdentity`; el id externo es un texto
///   opaco que no se normaliza ni se convierte a número. Los datos de v1/v2 se
///   migran como `source = 'local'`, `external_id = <id anterior en decimal>`.
abstract final class TakiDatabase {
  static const String fileName = 'taki.db';
  static const int version = 3;

  static const String favoritesTable = 'favorites';
  static const String playlistsTable = 'playlists';
  static const String playlistSongsTable = 'playlist_songs';

  /// Fuente con la que la migración v2 → v3 etiqueta los ids enteros
  /// existentes. **Congelada**: una migración debe escribir siempre el mismo
  /// valor aunque la constante de dominio cambie algún día.
  static const String _migratedLocalSource = 'local';

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
    await _createFavorites(db, favoritesTable);
    await _createFavoritesIndex(db);
    await _createPlaylists(db);
    await _createPlaylistSongs(db, playlistSongsTable);
    await _createPlaylistSongsIndex(db);
  }

  /// sqflite ejecuta la actualización dentro de una transacción: si algo lanza,
  /// se deshace entera y la base sigue en la versión anterior.
  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Un bloque por versión, en orden. Los de v1 → v2 solo añaden; el de
    // v2 → v3 reconstruye las tablas con copia verificada.
    if (oldVersion < 2) await _createPlaylistsV2(db);
    if (oldVersion < 3) await _migrateToIdentity(db);
  }

  // ---------------------------------------------------------------------------
  // Esquema actual (v3).

  /// `source + external_id` es la identidad y la clave. Los `CHECK` repiten la
  /// invariante de `MusicIdentity` (ni vacío ni solo espacios). Las columnas de
  /// texto son una copia de respaldo de los datos de la canción.
  static Future<void> _createFavorites(Database db, String table) async {
    await db.execute('''
      CREATE TABLE $table (
        source TEXT NOT NULL CHECK (length(trim(source)) > 0),
        external_id TEXT NOT NULL CHECK (length(trim(external_id)) > 0),
        added_at INTEGER NOT NULL,
        title TEXT,
        artist TEXT,
        album TEXT,
        duration_ms INTEGER,
        path TEXT,
        PRIMARY KEY (source, external_id)
      )
    ''');
  }

  static Future<void> _createFavoritesIndex(Database db) => db.execute(
        'CREATE INDEX idx_favorites_added_at ON $favoritesTable (added_at)',
      );

  static Future<void> _createPlaylists(Database db) async {
    await db.execute('''
      CREATE TABLE $playlistsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  /// Una canción puede repetirse: cada fila es una entrada (`id` propio) con su
  /// posición. No hay `UNIQUE` sobre la identidad a propósito.
  static Future<void> _createPlaylistSongs(Database db, String table) async {
    await db.execute('''
      CREATE TABLE $table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playlist_id INTEGER NOT NULL
          REFERENCES $playlistsTable (id) ON DELETE CASCADE,
        position INTEGER NOT NULL,
        source TEXT NOT NULL CHECK (length(trim(source)) > 0),
        external_id TEXT NOT NULL CHECK (length(trim(external_id)) > 0),
        title TEXT,
        artist TEXT,
        album TEXT,
        duration_ms INTEGER,
        path TEXT
      )
    ''');
  }

  static Future<void> _createPlaylistSongsIndex(Database db) => db.execute(
        'CREATE INDEX idx_playlist_songs_position '
        'ON $playlistSongsTable (playlist_id, position)',
      );

  // ---------------------------------------------------------------------------
  // Migración v1 → v2 (esquema congelado de las playlists de la v2).

  static Future<void> _createPlaylistsV2(Database db) async {
    await _createPlaylists(db);
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

  // ---------------------------------------------------------------------------
  // Migración v2 → v3.

  /// Pasa `favorites` y `playlist_songs` de `song_id INTEGER` a
  /// `source` + `external_id`:
  ///
  /// 1. crea la tabla nueva con un nombre temporal;
  /// 2. copia todas las filas (`source = 'local'`,
  ///    `external_id = CAST(song_id AS TEXT)`), en el mismo orden;
  /// 3. comprueba que no se perdió ninguna fila;
  /// 4. borra la tabla vieja, renombra la nueva y recrea sus índices.
  ///
  /// `playlist_songs` conserva el `id` de cada entrada, la `position` y la
  /// playlist, y la secuencia de ids. Todo ocurre en la transacción de
  /// `onUpgrade`: un fallo en cualquier paso deja la base como estaba (v2).
  static Future<void> _migrateToIdentity(Database db) async {
    await _migrateFavorites(db);
    await _migratePlaylistSongs(db);

    final violations = await db.rawQuery('PRAGMA foreign_key_check');
    if (violations.isNotEmpty) {
      throw StateError(
        'La migración v3 dejó ${violations.length} filas con clave foránea '
        'inválida',
      );
    }
  }

  static const String _favoritesNext = 'favorites_v3';
  static const String _playlistSongsNext = 'playlist_songs_v3';

  static Future<void> _migrateFavorites(Database db) async {
    final before = await _count(db, favoritesTable);
    await _createFavorites(db, _favoritesNext);
    await db.execute('''
      INSERT INTO $_favoritesNext
        (source, external_id, added_at, title, artist, album, duration_ms, path)
      SELECT '$_migratedLocalSource', CAST(song_id AS TEXT), added_at,
        title, artist, album, duration_ms, path
      FROM $favoritesTable
      ORDER BY rowid
    ''');
    await _expectSameCount(db, _favoritesNext, before, favoritesTable);

    await db.execute('DROP TABLE $favoritesTable');
    await db.execute('ALTER TABLE $_favoritesNext RENAME TO $favoritesTable');
    await _createFavoritesIndex(db);
  }

  static Future<void> _migratePlaylistSongs(Database db) async {
    final before = await _count(db, playlistSongsTable);
    final sequence = await db.rawQuery(
      'SELECT seq FROM sqlite_sequence WHERE name = ?',
      [playlistSongsTable],
    );
    final oldSequence =
        sequence.isEmpty ? null : sequence.single['seq']! as int;

    await _createPlaylistSongs(db, _playlistSongsNext);
    await db.execute('''
      INSERT INTO $_playlistSongsNext
        (id, playlist_id, position, source, external_id,
         title, artist, album, duration_ms, path)
      SELECT id, playlist_id, position, '$_migratedLocalSource',
        CAST(song_id AS TEXT), title, artist, album, duration_ms, path
      FROM $playlistSongsTable
      ORDER BY id
    ''');
    await _expectSameCount(db, _playlistSongsNext, before, playlistSongsTable);

    await db.execute('DROP TABLE $playlistSongsTable');
    await db.execute(
      'ALTER TABLE $_playlistSongsNext RENAME TO $playlistSongsTable',
    );
    await _createPlaylistSongsIndex(db);

    // Los ids de entrada no se reutilizan: la secuencia sigue donde estaba.
    if (oldSequence != null) {
      final updated = await db.rawUpdate(
        'UPDATE sqlite_sequence SET seq = MAX(seq, ?) WHERE name = ?',
        [oldSequence, playlistSongsTable],
      );
      if (updated == 0) {
        // Tabla vacía tras la migración: aún no tiene fila de secuencia.
        await db.rawInsert(
          'INSERT INTO sqlite_sequence (name, seq) VALUES (?, ?)',
          [playlistSongsTable, oldSequence],
        );
      }
    }
  }

  static Future<int> _count(Database db, String table) async {
    final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM $table');
    return rows.single['n']! as int;
  }

  static Future<void> _expectSameCount(
    Database db,
    String table,
    int expected,
    String original,
  ) async {
    final actual = await _count(db, table);
    if (actual != expected) {
      throw StateError(
        'La migración v3 copió $actual de $expected filas de $original',
      );
    }
  }
}
