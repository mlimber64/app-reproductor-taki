import '../../../../core/domain/entities/local_music_identity.dart';
import '../../../../core/domain/entities/local_song.dart';
import '../../../../core/domain/entities/music_identity.dart';
import '../../../../core/domain/entities/song_lookup_failure.dart';
import '../../../../core/domain/entities/song_lookup_result.dart';
import '../../../../core/domain/ports/song_lookup.dart';

/// Lookup de la fuente **local**: `MusicIdentity("local", id) → LocalSong`.
///
/// No conoce MediaStore ni duplica `MediaStoreSongRepository`: recibe un
/// [LibraryLoader] que entrega la biblioteca ya cargada y **filtrada** (la misma
/// lista que muestra la app: sin audios cortos ni carpetas excluidas). Así
/// resolver una identidad da exactamente las canciones que la biblioteca
/// considera suyas y no se hace una segunda lectura del sistema.
///
/// - Solo compara **identidad exacta** (`source` y `externalId` carácter a
///   carácter). No busca por ruta, título ni duración: eso es la política de
///   reencuentro `SongMatcher`, que aplican los casos de uso a las entradas
///   `missing` y que no pertenece a una resolución de identidad.
/// - Identidad de otra fuente → `unsupported`.
/// - Identidad local que no está en la biblioteca → `missing`.
/// - Si la biblioteca no se puede leer → `SongLookupFailure` (no se convierte
///   en «ausente»).
class LocalSongLookup implements SongLookup {
  const LocalSongLookup(this._library);

  final LibraryLoader _library;

  @override
  Future<SongLookupResult> findAll(Iterable<MusicIdentity> identities) async {
    final wanted = identities.toSet();
    final local = {
      for (final identity in wanted)
        if (identity.source == localMusicSource) identity,
    };
    final unsupported = wanted.difference(local);
    if (local.isEmpty) return SongLookupResult(unsupported: unsupported);

    final List<LocalSong> library;
    try {
      library = await _library();
    } catch (error) {
      throw SongLookupFailure(
        'no se pudo leer la biblioteca local',
        source: localMusicSource,
        cause: error,
      );
    }

    final byIdentity = {for (final song in library) song.musicIdentity: song};
    final found = {
      for (final identity in local) identity: ?byIdentity[identity],
    };
    return SongLookupResult(
      found: found,
      missing: local.difference(found.keys.toSet()),
      unsupported: unsupported,
    );
  }
}

/// Entrega la biblioteca local ya cargada y filtrada.
typedef LibraryLoader = Future<List<LocalSong>> Function();
