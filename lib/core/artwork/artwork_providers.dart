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

/// Resolvedor de carátulas por canción: enruta por fuente. Hoy solo la local;
/// un proveedor futuro se añade al mapa. Aún no lo consume la UI (que sigue
/// pasando `song.artwork` a `AlbumArtworkBuilder.reference`).
final artworkResolverProvider = Provider<ArtworkResolver>(
  (ref) => SourceArtworkResolver({
    localMusicSource: const LocalArtworkResolver(),
  }),
);

/// Cargador de carátulas remotas. Hoy no hay ninguno (`null`): las referencias
/// remotas se tratan como ausentes. Una fase posterior lo sobrescribirá, p. ej.
/// con `HttpRemoteArtworkLoader(const IoArtworkHttpClient())`.
final remoteArtworkLoaderProvider = Provider<RemoteArtworkLoader?>((ref) => null);

final artworkCacheProvider = Provider<ArtworkCache>(
  (ref) => ArtworkCache(
    ref.watch(artworkRepositoryProvider),
    remoteLoader: ref.watch(remoteArtworkLoaderProvider),
  ),
);
