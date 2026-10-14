import '../../../../core/domain/entities/catalog_search.dart';
import '../../../../core/domain/entities/catalog_section.dart';
import '../../../../core/domain/entities/music_identity.dart';
import '../../../../core/domain/ports/catalog_browse.dart';
import '../entities/jamendo_exception.dart';
import '../entities/jamendo_track.dart';
import '../ports/jamendo_api.dart';
import 'jamendo_song_mapper.dart';

/// Catalog discovery over Jamendo (read-only).
///
/// Every [CatalogSection] maps to one listing of the API: weekly or monthly
/// popularity, newest releases, or the weekly popularity of a genre tag.
class JamendoCatalogBrowse implements CatalogBrowse {
  const JamendoCatalogBrowse(this._api);

  final JamendoApi _api;

  @override
  Future<CatalogSearchPage> section(
    CatalogSection section, {
    int limit = 20,
  }) async {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'must be greater than 0');
    }

    final (order, tag) = switch (section.kind) {
      CatalogSectionKind.popularThisWeek => (
          JamendoTrackOrder.popularityWeek,
          null,
        ),
      CatalogSectionKind.popularThisMonth => (
          JamendoTrackOrder.popularityMonth,
          null,
        ),
      CatalogSectionKind.newReleases => (
          JamendoTrackOrder.releaseDateDesc,
          null,
        ),
      CatalogSectionKind.genre => (
          JamendoTrackOrder.popularityWeek,
          section.genre,
        ),
    };

    final JamendoTrackPage page;
    try {
      page = await _api.listTracks(
        order: order,
        tag: tag,
        limit: limit,
        offset: 0,
      );
    } on JamendoException catch (error) {
      throw CatalogSearchFailure(
        'could not load the section',
        source: jamendoSource,
        cause: error,
      );
    }

    return CatalogSearchPage(
      [for (final track in page.tracks) songFromJamendoTrack(track)],
      hasMore: page.hasMore,
      attributions: {
        for (final track in page.tracks)
          MusicIdentity(jamendoSource, track.id): track.attribution,
      },
    );
  }
}
