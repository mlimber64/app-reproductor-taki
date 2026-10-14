import '../entities/playback_resolution_exception.dart';
import '../entities/playback_resource.dart';
import '../entities/song.dart';
import '../ports/playback_resolver.dart';

/// Enruta [PlaybackResolver.resolve] según `MusicIdentity.source`.
///
/// Una fuente sin resolver registrado lanza [IdentityNotFound]: nadie sabe
/// reproducir esa canción.
class SourcePlaybackResolver implements PlaybackResolver {
  SourcePlaybackResolver(Map<String, PlaybackResolver> bySource)
      : _bySource = Map.unmodifiable(bySource);

  final Map<String, PlaybackResolver> _bySource;

  @override
  Future<PlaybackResource> resolve(Song song) async {
    final resolver = _bySource[song.musicIdentity.source];
    if (resolver == null) throw IdentityNotFound(song.musicIdentity);
    return resolver.resolve(song);
  }
}
