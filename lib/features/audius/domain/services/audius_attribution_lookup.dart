import '../../../../core/domain/entities/attribution_lookup_failure.dart';
import '../../../../core/domain/entities/attribution_lookup_result.dart';
import '../../../../core/domain/entities/music_identity.dart';
import '../../../../core/domain/entities/provider_attribution.dart';
import '../../../../core/domain/ports/attribution_lookup.dart';
import '../entities/audius_exception.dart';
import '../entities/audius_track.dart';
import '../ports/audius_api.dart';

/// Resolves the attribution of `audius` identities in one batch.
///
/// - Identities of other sources, and ids the API does not return, are
///   `absent`.
/// - Any API error is an [AttributionLookupFailure], never `absent`.
class AudiusAttributionLookup implements AttributionLookup {
  const AudiusAttributionLookup(this._api);

  final AudiusApi _api;

  @override
  Future<AttributionLookupResult> findAll(
    Iterable<MusicIdentity> identities,
  ) async {
    final wanted = identities.toSet();
    final mine = {
      for (final identity in wanted)
        if (identity.source == audiusSource) identity,
    };
    final others = wanted.difference(mine);
    if (mine.isEmpty) return AttributionLookupResult(absent: others);

    final List<AudiusTrack> tracks;
    try {
      tracks = await _api.tracksByIds([for (final i in mine) i.externalId]);
    } on AudiusException catch (error) {
      throw AttributionLookupFailure(
        'could not query Audius',
        source: audiusSource,
        cause: error,
      );
    } catch (error) {
      throw AttributionLookupFailure(
        'unexpected failure querying Audius',
        source: audiusSource,
        cause: error.runtimeType,
      );
    }

    final found = <MusicIdentity, ProviderAttribution>{};
    for (final track in tracks) {
      final identity = MusicIdentity(audiusSource, track.id);
      if (mine.contains(identity)) found[identity] = track.attribution;
    }
    return AttributionLookupResult(
      found: found,
      absent: {...others, ...mine.difference(found.keys.toSet())},
    );
  }
}
