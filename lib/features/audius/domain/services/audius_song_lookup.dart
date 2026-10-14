import '../../../../core/domain/entities/music_identity.dart';
import '../../../../core/domain/entities/song.dart';
import '../../../../core/domain/entities/song_lookup_failure.dart';
import '../../../../core/domain/entities/song_lookup_result.dart';
import '../../../../core/domain/ports/song_lookup.dart';
import '../entities/audius_exception.dart';
import '../entities/audius_track.dart';
import '../ports/audius_api.dart';
import 'audius_song_mapper.dart';

/// Resolves `audius` identities in one batch.
///
/// - Identities of other sources are `unsupported`.
/// - An id the API does not return is `missing`.
/// - Any API error is a [SongLookupFailure], never `missing`.
class AudiusSongLookup implements SongLookup {
  const AudiusSongLookup(this._api);

  final AudiusApi _api;

  @override
  Future<SongLookupResult> findAll(Iterable<MusicIdentity> identities) async {
    final wanted = identities.toSet();
    final mine = {
      for (final identity in wanted)
        if (identity.source == audiusSource) identity,
    };
    final unsupported = wanted.difference(mine);
    if (mine.isEmpty) return SongLookupResult(unsupported: unsupported);

    final List<AudiusTrack> tracks;
    try {
      tracks = await _api.tracksByIds([for (final i in mine) i.externalId]);
    } on AudiusException catch (error) {
      throw SongLookupFailure(
        'could not query Audius',
        source: audiusSource,
        cause: error,
      );
    } catch (error) {
      throw SongLookupFailure(
        'unexpected failure querying Audius',
        source: audiusSource,
        cause: error.runtimeType,
      );
    }

    final found = <MusicIdentity, Song>{};
    for (final track in tracks) {
      final identity = MusicIdentity(audiusSource, track.id);
      if (!mine.contains(identity)) continue;
      found[identity] = songFromAudiusTrack(track);
    }
    return SongLookupResult(
      found: found,
      missing: mine.difference(found.keys.toSet()),
      unsupported: unsupported,
    );
  }
}
