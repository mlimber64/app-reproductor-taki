import '../../../../core/domain/entities/music_identity.dart';
import '../../../../core/domain/entities/playback_resolution_exception.dart';
import '../../../../core/domain/entities/playback_resource.dart';
import '../../../../core/domain/entities/song.dart';
import '../../../../core/domain/ports/playback_resolver.dart';
import '../entities/audius_exception.dart';
import '../entities/audius_track.dart';
import '../ports/audius_api.dart';

/// Resolves the stream of an Audius song.
///
/// The track is looked up first so a removed or gated track becomes
/// `IdentityNotFound` / `UnavailableResource` instead of a player error. The
/// stream URL itself is built and never stored: the server signs a fresh
/// redirect each time it is opened, so there is nothing to expire.
///
/// Single flight per identity: the same song asked twice while the first
/// lookup is pending shares one request; a failure is never remembered.
class AudiusPlaybackResolver implements PlaybackResolver {
  AudiusPlaybackResolver(this._api);

  final AudiusApi _api;
  final Map<MusicIdentity, Future<PlaybackResource>> _inFlight = {};

  @override
  Future<PlaybackResource> resolve(Song song) async {
    final identity = song.musicIdentity;
    if (identity.source != audiusSource) throw IdentityNotFound(identity);

    return _inFlight[identity] ??= _fetch(identity).whenComplete(() {
      // A block without a value: `remove` returns this same future.
      _inFlight.remove(identity);
    });
  }

  Future<PlaybackResource> _fetch(MusicIdentity identity) async {
    final List<AudiusTrack> tracks;
    try {
      tracks = await _api.tracksByIds([identity.externalId]);
    } on AudiusException catch (error) {
      throw PlaybackResolutionError(
        'could not resolve the audio on Audius',
        cause: error,
      );
    } catch (error) {
      throw PlaybackResolutionError(
        'unexpected failure resolving the audio',
        cause: error.runtimeType,
      );
    }

    final found = tracks.any((t) => t.id == identity.externalId);
    if (!found) throw IdentityNotFound(identity);
    return RemoteUriResource(_api.streamUrl(identity.externalId));
  }
}
