import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/ports/artwork_repository.dart';
import '../../domain/ports/media_permission_port.dart';
import '../../domain/ports/song_repository.dart';
import '../../domain/usecases/get_songs.dart';
import '../../infrastructure/media_store_artwork_repository.dart';
import '../../infrastructure/media_store_song_repository.dart';
import '../../infrastructure/permission_handler_media_permission.dart';
import 'artwork_cache.dart';

// Cableado de ports → adapters. Es el único lugar de la feature que conoce la
// infraestructura; en los tests se sobrescriben con fakes.

final songRepositoryProvider = Provider<SongRepository>(
  (ref) => MediaStoreSongRepository(),
);

final mediaPermissionProvider = Provider<MediaPermissionPort>(
  (ref) => PermissionHandlerMediaPermission(),
);

final artworkRepositoryProvider = Provider<ArtworkRepository>(
  (ref) => MediaStoreArtworkRepository(),
);

final getSongsProvider = Provider<GetSongs>(
  (ref) => GetSongs(ref.watch(songRepositoryProvider)),
);

final artworkCacheProvider = Provider<ArtworkCache>(
  (ref) => ArtworkCache(ref.watch(artworkRepositoryProvider)),
);
