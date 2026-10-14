import '../../../../core/domain/entities/catalog_search.dart';
import '../../../../core/domain/entities/music_identity.dart';
import '../../../../core/domain/ports/catalog_search.dart';
import '../entities/jamendo_exception.dart';
import '../entities/jamendo_track.dart';
import '../ports/jamendo_api.dart';
import 'jamendo_song_mapper.dart';

/// Búsqueda de catálogo sobre Jamendo (solo lectura).
///
/// Los límites de Jamendo (`limit` 1…200) se validan en la API; un `limit`
/// fuera de rango llega como [CatalogSearchFailure].
class JamendoCatalogSearch implements CatalogSearch {
  const JamendoCatalogSearch(this._api);

  final JamendoApi _api;

  @override
  Future<CatalogSearchPage> search(CatalogSearchQuery query) async {
    final JamendoTrackPage page;
    try {
      page = await _api.searchTracks(
        name: query.text,
        artistName: query.artist,
        tag: query.tag,
        limit: query.limit,
        offset: query.offset,
      );
    } on JamendoException catch (error) {
      throw CatalogSearchFailure(
        'no se pudo buscar en Jamendo',
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
