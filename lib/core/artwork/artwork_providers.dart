import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ports/artwork_repository.dart';
import 'artwork_cache.dart';

// Carátulas compartidas por todas las features. El adapter concreto se crea en
// `main.dart` (lo usa también el reproductor para la notificación) y se
// inyecta con un override; en los tests se sobrescribe con un fake.

final artworkRepositoryProvider = Provider<ArtworkRepository>(
  (ref) => throw UnimplementedError(
    'artworkRepositoryProvider se sobrescribe en main.dart',
  ),
);

final artworkCacheProvider = Provider<ArtworkCache>(
  (ref) => ArtworkCache(ref.watch(artworkRepositoryProvider)),
);
