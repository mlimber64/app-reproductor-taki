import '../../../../core/domain/entities/catalog_search.dart';
import '../../../../core/domain/entities/music_identity.dart';
import '../../../../core/domain/ports/catalog_search.dart';
import '../entities/audius_exception.dart';
import '../entities/audius_track.dart';
import '../ports/audius_api.dart';
import 'audius_song_mapper.dart';

/// Catalog search over Audius (read-only).
///
/// Audius searches free text only: an artist or tag filter of the query is
/// folded into the text, which Audius matches against titles, artists and tags.
class AudiusCatalogSearch implements CatalogSearch {
  const AudiusCatalogSearch(this._api);

  final AudiusApi _api;

  @override
  Future<CatalogSearchPage> search(CatalogSearchQuery query) async {
    final text = [query.text, query.artist, query.tag]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(' ');

    final AudiusTrackPage page;
    try {
      page = await _api.searchTracks(
        query: text,
        limit: query.limit,
        offset: query.offset,
      );
    } on AudiusException catch (error) {
      throw CatalogSearchFailure(
        'could not search Audius',
        source: audiusSource,
        cause: error,
      );
    }
    return audiusPageToCatalog(page);
  }
}

/// Shared by search and browse: songs plus the attribution of each one.
CatalogSearchPage audiusPageToCatalog(AudiusTrackPage page) =>
    CatalogSearchPage(
      [for (final track in page.tracks) songFromAudiusTrack(track)],
      hasMore: page.hasMore,
      attributions: {
        for (final track in page.tracks)
          MusicIdentity(audiusSource, track.id): track.attribution,
      },
    );
