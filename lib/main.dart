import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/audius_wiring.dart';
import 'app/jamendo_wiring.dart';
import 'app/song_lookup_wiring.dart';
import 'core/artwork/artwork_providers.dart';
import 'core/artwork/http_remote_artwork_loader.dart';
import 'core/artwork/io_artwork_http_client.dart';
import 'core/catalog/catalog_sources_providers.dart';
import 'core/database/taki_database.dart';
import 'core/database/taki_database_provider.dart';
import 'core/lookup/attribution_lookup_providers.dart';
import 'features/library/infrastructure/media_store_artwork_repository.dart';
import 'features/player/infrastructure/player_bootstrap.dart';
import 'features/player/presentation/providers/player_providers.dart';
import 'features/settings/infrastructure/font_licenses.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerFontLicenses();

  // Carátulas de MediaStore: las usan la UI y la notificación del reproductor.
  final artwork = MediaStoreArtworkRepository();
  // Jamendo is only wired when JAMENDO_CLIENT_ID is set (--dart-define).
  const http = IoArtworkHttpClient();
  final jamendo = buildJamendoServices(http);
  // Audius needs no key: it is always available.
  final audius = buildAudiusServices(http);
  // Una sola instancia: la usan la UI (override de abajo) y la notificación /
  // pantalla de bloqueo (ArtworkFileCache) para las carátulas remotas.
  final remoteArtworkLoader = HttpRemoteArtworkLoader(http);
  final playback = await initPlayer(
    artwork: artwork,
    resolver: buildPlaybackResolver(jamendo, audius: audius),
    remoteArtworkLoader: remoteArtworkLoader,
  );
  // Si la base no abre, la app arranca igual: los favoritos se muestran como
  // no disponibles y "Reintentar" vuelve a intentarlo.
  final database = await TakiDatabase.tryOpen();

  runApp(
    ProviderScope(
      overrides: [
        artworkRepositoryProvider.overrideWithValue(artwork),
        jamendoServicesProvider.overrideWithValue(jamendo),
        audiusServicesProvider.overrideWithValue(audius),
        artworkResolverProvider
            .overrideWithValue(buildArtworkResolver(jamendo, audius: audius)),
        remoteArtworkLoaderProvider.overrideWithValue(remoteArtworkLoader),
        catalogSourcesProvider
            .overrideWithValue(buildCatalogSources(jamendo, audius: audius)),
        attributionLookupProvider
            .overrideWithValue(buildAttributionLookup(jamendo, audius: audius)),
        songLookupOverride(),
        audioPlayerPortProvider.overrideWithValue(playback.player),
        audioHandlerProvider.overrideWithValue(playback.handler),
        if (database != null)
          takiDatabaseProvider.overrideWith((ref) => database),
      ],
      child: const TakiApp(),
    ),
  );
}
