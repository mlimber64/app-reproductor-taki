import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/database/taki_database.dart';
import 'core/database/taki_database_provider.dart';
import 'features/library/infrastructure/media_store_artwork_repository.dart';
import 'features/player/infrastructure/player_bootstrap.dart';
import 'features/player/presentation/providers/player_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final playback = await initPlayer(artwork: MediaStoreArtworkRepository());
  // Si la base no abre, la app arranca igual: los favoritos se muestran como
  // no disponibles y "Reintentar" vuelve a intentarlo.
  final database = await TakiDatabase.tryOpen();

  runApp(
    ProviderScope(
      overrides: [
        audioPlayerPortProvider.overrideWithValue(playback.player),
        audioHandlerProvider.overrideWithValue(playback.handler),
        if (database != null)
          takiDatabaseProvider.overrideWith((ref) => database),
      ],
      child: const TakiApp(),
    ),
  );
}
