import '../../../../core/domain/entities/catalog_search.dart';
import '../../../../core/domain/entities/catalog_section.dart';
import '../../../../core/domain/ports/catalog_browse.dart';
import '../entities/catalog_result_item.dart';

/// The songs of one discovery section of a single [CatalogBrowse] source.
///
/// One call is one logical request: no retries and no sleeping (the
/// intermittency of a source is its infrastructure's concern). Failures always
/// come out as [CatalogSearchFailure], without technology details.
class GetFeaturedSongs {
  const GetFeaturedSongs(this._browse, {this.limit = defaultLimit});

  /// Enough to fill a carousel without paging.
  static const int defaultLimit = 20;

  final CatalogBrowse _browse;
  final int limit;

  Future<List<CatalogResultItem>> call(CatalogSection section) async {
    final CatalogSearchPage page;
    try {
      page = await _browse.section(section, limit: limit);
    } on CatalogSearchFailure {
      rethrow;
    } catch (error) {
      throw CatalogSearchFailure(
        'unexpected failure loading the featured songs',
        cause: error.runtimeType,
      );
    }

    // A source may repeat a song; keep the first (best ranked) occurrence.
    final seen = <Object>{};
    return [
      for (final song in page.songs)
        if (seen.add(song.musicIdentity))
          CatalogResultItem(song, attribution: page.attributionOf(song)),
    ];
  }
}
