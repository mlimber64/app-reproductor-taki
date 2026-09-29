import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/taki_database_provider.dart';
import '../../../library/domain/entities/song.dart';
import '../../../library/presentation/providers/songs_notifier.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/playlist_entry.dart';
import '../../domain/ports/playlists_repository.dart';
import '../../domain/usecases/playlist_usecases.dart';
import '../../infrastructure/sqflite_playlists_repository.dart';

final playlistsRepositoryProvider = Provider<PlaylistsRepository>((ref) {
  final repository = SqflitePlaylistsRepository(
    () => ref.read(takiDatabaseProvider.future),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

/// Playlists, la modificada más recientemente primero.
final playlistsProvider = StreamProvider<List<Playlist>>(
  (ref) => ref.watch(playlistsRepositoryProvider).watchPlaylists(),
);

/// La playlist [playlistId], o `null` si no existe (p. ej. se borró).
final playlistProvider = Provider.family<AsyncValue<Playlist?>, int>(
  (ref, playlistId) => ref.watch(playlistsProvider).whenData(
        (playlists) =>
            playlists.where((p) => p.id == playlistId).firstOrNull,
      ),
);

/// Canciones visibles de la playlist (las que están en la biblioteca), en
/// orden. Se recalcula cuando cambian las playlists o la biblioteca.
final playlistItemsProvider =
    FutureProvider.family<List<PlaylistItem>, int>((ref, playlistId) async {
  await ref.watch(playlistsProvider.future);
  final library = await ref.watch(songsProvider.future);
  final songs = library is LibraryLoaded ? library.songs : const <Song>[];
  return ref.read(getPlaylistSongsProvider).call(playlistId, songs);
});

/// Carátula (albumId) de cada canción de la biblioteca, para los mosaicos.
final libraryAlbumIdsProvider = Provider<Map<int, int?>>((ref) {
  final library = ref.watch(songsProvider).valueOrNull;
  if (library is! LibraryLoaded) return const {};
  return {for (final song in library.songs) song.id: song.albumId};
});

final createPlaylistProvider = Provider<CreatePlaylist>(
  (ref) => CreatePlaylist(ref.watch(playlistsRepositoryProvider)),
);

final renamePlaylistProvider = Provider<RenamePlaylist>(
  (ref) => RenamePlaylist(ref.watch(playlistsRepositoryProvider)),
);

final deletePlaylistProvider = Provider<DeletePlaylist>(
  (ref) => DeletePlaylist(ref.watch(playlistsRepositoryProvider)),
);

final addSongsToPlaylistProvider = Provider<AddSongsToPlaylist>(
  (ref) => AddSongsToPlaylist(ref.watch(playlistsRepositoryProvider)),
);

final removeFromPlaylistProvider = Provider<RemoveFromPlaylist>(
  (ref) => RemoveFromPlaylist(ref.watch(playlistsRepositoryProvider)),
);

final movePlaylistSongProvider = Provider<MovePlaylistSong>(
  (ref) => MovePlaylistSong(ref.watch(playlistsRepositoryProvider)),
);

final getPlaylistSongsProvider = Provider<GetPlaylistSongs>(
  (ref) => GetPlaylistSongs(ref.watch(playlistsRepositoryProvider)),
);

/// "Reintentar" tras un error: reabre la base si hizo falta y, si la
/// biblioteca también falló, la vuelve a escanear.
void retryPlaylists(WidgetRef ref) {
  ref.invalidate(takiDatabaseProvider);
  ref.invalidate(playlistsProvider);
  if (ref.read(songsProvider).hasError) {
    ref.read(songsProvider.notifier).retry();
  }
}
