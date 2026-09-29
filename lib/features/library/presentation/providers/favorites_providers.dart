import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/taki_database_provider.dart';
import '../../../../core/domain/entities/song.dart';
import '../../domain/ports/favorites_repository.dart';
import '../../domain/usecases/favorites_usecases.dart';
import '../../infrastructure/sqflite_favorites_repository.dart';
import 'songs_notifier.dart';

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  final repository = SqfliteFavoritesRepository(
    () => ref.read(takiDatabaseProvider.future),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

/// Ids favoritos; se actualiza al instante tras cada cambio.
final favoriteIdsProvider = StreamProvider<Set<int>>(
  (ref) => ref.watch(favoritesRepositoryProvider).watchFavoriteIds(),
);

/// Si la canción [songId] es favorita. Solo reconstruye a quien la observa
/// cuando cambia esa canción.
final isFavoriteProvider = Provider.family<bool, int>(
  (ref, songId) => ref.watch(
    favoriteIdsProvider.select(
      (ids) => ids.valueOrNull?.contains(songId) ?? false,
    ),
  ),
);

final toggleFavoriteProvider = Provider<ToggleFavorite>(
  (ref) => ToggleFavorite(ref.watch(favoritesRepositoryProvider)),
);

final getFavoriteSongsProvider = Provider<GetFavoriteSongs>(
  (ref) => GetFavoriteSongs(ref.watch(favoritesRepositoryProvider)),
);

/// Canciones favoritas presentes en la biblioteca, las más recientes primero.
/// Se recalcula cuando cambian los favoritos o la biblioteca.
final favoriteSongsProvider = FutureProvider<List<Song>>((ref) async {
  await ref.watch(favoriteIdsProvider.future);
  final library = await ref.watch(songsProvider.future);
  final songs = library is LibraryLoaded ? library.songs : const <Song>[];
  return ref.read(getFavoriteSongsProvider).call(songs);
});

/// "Reintentar" tras un error de favoritos: reabre la base si hizo falta y,
/// si la biblioteca también falló, la vuelve a escanear.
void retryFavorites(WidgetRef ref) {
  ref.invalidate(takiDatabaseProvider);
  ref.invalidate(favoriteIdsProvider);
  if (ref.read(songsProvider).hasError) {
    ref.read(songsProvider.notifier).retry();
  }
}
