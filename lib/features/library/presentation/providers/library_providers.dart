import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/ports/media_permission_port.dart';
import '../../domain/ports/song_repository.dart';
import '../../domain/usecases/get_songs.dart';
import '../../infrastructure/media_store_song_repository.dart';
import '../../infrastructure/permission_handler_media_permission.dart';

// Cableado de ports → adapters. Es el único lugar de la feature que conoce la
// infraestructura; en los tests se sobrescriben con fakes. Las carátulas son
// compartidas: sus providers viven en `core/artwork` y el adapter
// (`MediaStoreArtworkRepository`) se inyecta desde `main.dart`.

final songRepositoryProvider = Provider<SongRepository>(
  (ref) => MediaStoreSongRepository(),
);

final mediaPermissionProvider = Provider<MediaPermissionPort>(
  (ref) => PermissionHandlerMediaPermission(),
);

final getSongsProvider = Provider<GetSongs>(
  (ref) => GetSongs(ref.watch(songRepositoryProvider)),
);
