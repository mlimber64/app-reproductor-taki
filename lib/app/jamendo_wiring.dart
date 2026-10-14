import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/domain/entities/catalog_provider_info.dart';
import '../core/domain/entities/local_music_identity.dart';
import '../core/domain/ports/artwork_http_client.dart';
import '../core/domain/ports/artwork_resolver.dart';
import '../core/domain/ports/attribution_lookup.dart';
import '../core/domain/ports/catalog_search.dart';
import '../core/domain/ports/catalog_sources.dart';
import '../core/domain/ports/playback_resolver.dart';
import '../core/domain/ports/song_lookup.dart';
import '../core/domain/services/artwork_resolvers.dart';
import '../core/domain/services/local_playback_resolver.dart';
import '../core/domain/services/source_attribution_lookup.dart';
import '../core/domain/services/source_catalog_sources.dart';
import '../core/domain/services/source_playback_resolver.dart';
import '../features/jamendo/domain/entities/jamendo_track.dart';
import '../features/jamendo/domain/ports/jamendo_api.dart';
import '../features/jamendo/domain/services/caching_jamendo_api.dart';
import '../features/jamendo/domain/services/jamendo_attribution_lookup.dart';
import '../features/jamendo/domain/services/jamendo_audio_cache.dart';
import '../features/jamendo/domain/services/jamendo_catalog_search.dart';
import '../features/jamendo/domain/services/jamendo_playback_resolver.dart';
import '../features/jamendo/domain/services/jamendo_song_lookup.dart';
import '../features/jamendo/infrastructure/http_jamendo_api.dart';
import '../features/jamendo/infrastructure/jamendo_credentials.dart';

/// Piezas del proveedor Jamendo ya cableadas.
class JamendoServices {
  JamendoServices._({
    required this.lookup,
    required this.playback,
    required this.search,
    required this.attribution,
  });

  final SongLookup lookup;
  final PlaybackResolver playback;
  final CatalogSearch search;
  final AttributionLookup attribution;
}

/// Construye Jamendo sobre [api] (inyectable para tests). Búsqueda y lookup
/// comparten una caché en memoria de URLs de audio con el resolver.
JamendoServices buildJamendoServicesFor(
  JamendoApi api, {
  JamendoAudioCache? cache,
}) {
  final audioCache = cache ?? JamendoAudioCache();
  final cached = CachingJamendoApi(api, audioCache);
  return JamendoServices._(
    lookup: JamendoSongLookup(cached),
    playback: JamendoPlaybackResolver(cached, audioCache),
    search: JamendoCatalogSearch(cached),
    attribution: JamendoAttributionLookup(cached),
  );
}

/// Jamendo solo existe si hay `client_id` configurado; si no, `null` y la app
/// sigue funcionando solo con la biblioteca local.
JamendoServices? buildJamendoServices(
  ArtworkHttpClient http, {
  JamendoCredentials credentials = const EnvironmentJamendoCredentials(),
}) {
  final clientId = credentials.clientId;
  if (clientId == null || clientId.trim().isEmpty) return null;
  return buildJamendoServicesFor(HttpJamendoApi(http, credentials));
}

PlaybackResolver buildPlaybackResolver(JamendoServices? jamendo) =>
    SourcePlaybackResolver({
      localMusicSource: const LocalPlaybackResolver(),
      if (jamendo != null) jamendoSource: jamendo.playback,
    });

/// Atribuciones por identidad: Jamendo solo si está cableado; sin él, toda
/// identidad es `absent`.
AttributionLookup buildAttributionLookup(JamendoServices? jamendo) =>
    SourceAttributionLookup({
      if (jamendo != null) jamendoSource: jamendo.attribution,
    });

/// Catálogos disponibles: Jamendo solo si está cableado; sin él, ninguno.
CatalogSources buildCatalogSources(JamendoServices? jamendo) =>
    SourceCatalogSources([
      if (jamendo != null)
        CatalogSourceRegistration(
          CatalogProviderInfo(source: jamendoSource, label: jamendoProviderName),
          jamendo.search,
        ),
    ]);

ArtworkResolver buildArtworkResolver(JamendoServices? jamendo) =>
    SourceArtworkResolver({
      localMusicSource: const LocalArtworkResolver(),
      if (jamendo != null) jamendoSource: const SongArtworkResolver(),
    });

final jamendoServicesProvider = Provider<JamendoServices?>((ref) => null);
