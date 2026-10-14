import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/services/isolated_song_lookup.dart';
import '../../../../core/lookup/song_lookup_providers.dart';
import '../../../../core/database/taki_database_provider.dart';
import '../../../../core/domain/entities/artwork_reference.dart';
import '../../../../core/domain/entities/music_identity.dart';
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
  // El estado de la biblioteca local no bloquea la resolución de otras fuentes.
  final songs = await localLibrarySongs(ref);
  return ref.read(getPlaylistSongsProvider).call(playlistId, songs);
});

/// Carátula de cada canción de la biblioteca, para los mosaicos.
final libraryArtworkProvider =
    Provider<Map<MusicIdentity, ArtworkReference>>((ref) {
  final library = ref.watch(songsProvider).valueOrNull;
  if (library is! LibraryLoaded) return const {};
  return {for (final song in library.songs) song.musicIdentity: song.artwork};
});

/// Identidades de portada (hasta 4 por playlist) que **no** están en la
/// biblioteca local y hay que resolver. Con igualdad por valor: solo cambia (y
/// solo vuelve a consultar) cuando cambia el conjunto, no con cada edición de
/// una playlist.
final class CoverIdentitiesToResolve {
  const CoverIdentitiesToResolve(this.identities);

  final Set<MusicIdentity> identities;

  @override
  bool operator ==(Object other) =>
      other is CoverIdentitiesToResolve &&
      other.identities.length == identities.length &&
      other.identities.containsAll(identities);

  @override
  int get hashCode => Object.hashAllUnordered(identities);
}

final coverIdentitiesToResolveProvider = Provider<CoverIdentitiesToResolve>((
  ref,
) {
  final playlists = ref.watch(playlistsProvider).valueOrNull ?? const [];
  final inLibrary = ref.watch(libraryArtworkProvider);
  return CoverIdentitiesToResolve({
    for (final playlist in playlists)
      for (final identity in playlist.coverIdentities)
        if (!inLibrary.containsKey(identity)) identity,
  });
});

/// Carátula de las canciones de portada que no son de la biblioteca local (p. ej.
/// remotas), sacada de la **`Song` resuelta** por el `SongLookup` (`Song.artwork`).
/// Una consulta en lote por cambio del conjunto; las imágenes las carga la
/// `ArtworkCache` de siempre. Un fallo o una canción no resuelta no rompe nada:
/// esa pieza queda sin carátula (fallback existente).
final remoteCoverArtworkProvider =
    FutureProvider<Map<MusicIdentity, ArtworkReference>>((ref) async {
  final identities = ref.watch(coverIdentitiesToResolveProvider).identities;
  if (identities.isEmpty) return const {};
  try {
    final resolved =
        await findAllIsolatingSources(ref.watch(songLookupProvider), identities);
    return {
      for (final entry in resolved.result.found.entries)
        entry.key: entry.value.artwork,
    };
  } catch (_) {
    return const {};
  }
});

/// Carátula por identidad para los mosaicos de la lista de playlists y del
/// selector: la de la biblioteca local (como siempre, y con prioridad) y, para
/// el resto, la de la canción resuelta. Mientras se resuelve, solo la local.
final playlistCoverArtworkProvider =
    Provider<Map<MusicIdentity, ArtworkReference>>((ref) {
  final local = ref.watch(libraryArtworkProvider);
  final others = ref.watch(remoteCoverArtworkProvider).valueOrNull;
  if (others == null || others.isEmpty) return local;
  return {...others, ...local};
});

final createPlaylistProvider =Provider<CreatePlaylist>(
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
  (ref) => GetPlaylistSongs(
    ref.watch(playlistsRepositoryProvider),
    ref.watch(songLookupProvider),
  ),
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
