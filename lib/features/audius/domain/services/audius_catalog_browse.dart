import '../../../../core/domain/entities/catalog_search.dart';
import '../../../../core/domain/entities/catalog_section.dart';
import '../../../../core/domain/ports/catalog_browse.dart';
import '../entities/audius_exception.dart';
import '../entities/audius_track.dart';
import '../ports/audius_api.dart';
import 'audius_catalog_search.dart';

/// Genre tags of the discovery screen → Audius genre names.
///
/// Audius has a closed list of genres. A tag that is not here has no section
/// on Audius and answers with an empty page (the port's contract).
const Map<String, String> audiusGenres = {
  'rock': 'Rock',
  'electronic': 'Electronic',
  'pop': 'Pop',
  'hiphop': 'Hip-Hop/Rap',
  'jazz': 'Jazz',
  'chillout': 'Lo-Fi',
};

/// Catalog discovery over Audius (read-only).
///
/// Weekly and monthly popularity are the trending charts, new releases are
/// the underground chart (emerging, recent tracks) and a genre is the weekly
/// chart of that genre.
class AudiusCatalogBrowse implements CatalogBrowse {
  const AudiusCatalogBrowse(this._api);

  final AudiusApi _api;

  @override
  Future<CatalogSearchPage> section(
    CatalogSection section, {
    int limit = 20,
  }) async {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'must be greater than 0');
    }

    final AudiusTrackPage page;
    try {
      page = switch (section.kind) {
        CatalogSectionKind.popularThisWeek => await _api.trending(
            window: AudiusTrendingWindow.week,
            limit: limit,
            offset: 0,
          ),
        CatalogSectionKind.popularThisMonth => await _api.trending(
            window: AudiusTrendingWindow.month,
            limit: limit,
            offset: 0,
          ),
        CatalogSectionKind.newReleases =>
          await _api.underground(limit: limit, offset: 0),
        CatalogSectionKind.genre => await _genre(section.genre, limit),
      };
    } on AudiusException catch (error) {
      throw CatalogSearchFailure(
        'could not load the section',
        source: audiusSource,
        cause: error,
      );
    }
    return audiusPageToCatalog(page);
  }

  Future<AudiusTrackPage> _genre(String? tag, int limit) async {
    final name = audiusGenres[tag];
    if (name == null) return const AudiusTrackPage([], hasMore: false);
    return _api.trending(
      window: AudiusTrendingWindow.week,
      genre: name,
      limit: limit,
      offset: 0,
    );
  }
}
