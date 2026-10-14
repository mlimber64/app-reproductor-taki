import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/local_music_identity.dart';
import '../domain/ports/artwork_repository.dart';
import '../domain/ports/artwork_resolver.dart';
import '../domain/services/artwork_resolvers.dart';
import '../domain/ports/remote_artwork_loader.dart';
import 'artwork_cache.dart';

// Carátulas compartidas por todas las features. El adapter concreto se crea en
// `main.dart` (lo usa también el reproductor para la notificación) y se
// inyecta con un override; en los tests se sobrescribe con un fake.

final artworkRepositoryProvider = Provider<ArtworkRepository>(
  (ref) => throw UnimplementedError(
    'artworkRepositoryProvider se sobrescribe en main.dart',
  ),
);

/// Per-song artwork resolver: routes by source. Only the local source is
/// registered here; remote sources are wired in `lib/app`.
final artworkResolverProvider = Provider<ArtworkResolver>(
  (ref) => SourceArtworkResolver({
    localMusicSource: const LocalArtworkResolver(),
  }),
);

/// Remote artwork loader. `null` by default, in which case remote references
/// are treated as absent; the app overrides it with an `HttpRemoteArtworkLoader`.
final remoteArtworkLoaderProvider = Provider<RemoteArtworkLoader?>((ref) => null);

final artworkCacheProvider = Provider<ArtworkCache>(
  (ref) => ArtworkCache(
    ref.watch(artworkRepositoryProvider),
    remoteLoader: ref.watch(remoteArtworkLoaderProvider),
  ),
);
