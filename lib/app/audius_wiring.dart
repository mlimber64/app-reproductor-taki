import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/domain/ports/artwork_http_client.dart';
import '../core/domain/ports/attribution_lookup.dart';
import '../core/domain/ports/catalog_browse.dart';
import '../core/domain/ports/catalog_search.dart';
import '../core/domain/ports/playback_resolver.dart';
import '../core/domain/ports/song_lookup.dart';
import '../features/audius/domain/ports/audius_api.dart';
import '../features/audius/domain/services/audius_attribution_lookup.dart';
import '../features/audius/domain/services/audius_catalog_browse.dart';
import '../features/audius/domain/services/audius_catalog_search.dart';
import '../features/audius/domain/services/audius_playback_resolver.dart';
import '../features/audius/domain/services/audius_song_lookup.dart';
import '../features/audius/infrastructure/http_audius_api.dart';

/// The Audius provider with its pieces already wired.
class AudiusServices {
  AudiusServices._({
    required this.lookup,
    required this.playback,
    required this.search,
    required this.browse,
    required this.attribution,
  });

  final SongLookup lookup;
  final PlaybackResolver playback;
  final CatalogSearch search;
  final CatalogBrowse browse;
  final AttributionLookup attribution;
}

/// Builds Audius over [api] (injectable for tests).
AudiusServices buildAudiusServicesFor(AudiusApi api) => AudiusServices._(
      lookup: AudiusSongLookup(api),
      playback: AudiusPlaybackResolver(api),
      search: AudiusCatalogSearch(api),
      browse: AudiusCatalogBrowse(api),
      attribution: AudiusAttributionLookup(api),
    );

/// Audius needs no key, so it is always available.
AudiusServices buildAudiusServices(ArtworkHttpClient http) =>
    buildAudiusServicesFor(HttpAudiusApi(http));

final audiusServicesProvider = Provider<AudiusServices?>((ref) => null);
