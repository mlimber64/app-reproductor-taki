import '../entities/local_music_identity.dart';
import '../entities/local_song.dart';
import '../entities/playback_resolution_exception.dart';
import '../entities/playback_resource.dart';
import '../entities/song.dart';
import '../ports/playback_resolver.dart';

/// Resolvedor de la fuente local: la canción se reproduce desde la URI que la
/// propia fuente ya entregó (`LocalSong.contentUri`).
///
/// Es Dart puro y no duplica datos ni hace E/S: no conoce MediaStore ni
/// reconstruye URI (la URI depende del volumen y la arma el adaptador nativo),
/// solo lee lo que la canción local ya trae.
///
/// - Identidad de otra fuente → [IdentityNotFound].
/// - Identidad local pero sin datos locales (no es una [LocalSong]) o con URI
///   vacía → [UnavailableResource] (la canción existe, sin recurso).
/// - Si no, [LocalUriResource].
class LocalPlaybackResolver implements PlaybackResolver {
  const LocalPlaybackResolver();

  @override
  Future<PlaybackResource> resolve(Song song) async {
    final identity = song.musicIdentity;
    if (identity.source != localMusicSource) throw IdentityNotFound(identity);

    // El contrato universal recibe `Song`; los datos locales solo existen en
    // `LocalSong`. Esta comprobación es el límite entre ambos y no se repite
    // fuera de los resolvedores locales.
    if (song is! LocalSong) {
      return const UnavailableResource(
        reason: 'la canción local no trae datos de reproducción',
      );
    }

    final uri = song.contentUri;
    if (uri.trim().isEmpty) {
      return const UnavailableResource(reason: 'la canción local no tiene URI');
    }
    return LocalUriResource(uri);
  }
}
