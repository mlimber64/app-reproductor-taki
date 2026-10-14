import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/lookup/song_lookup_providers.dart';
import '../../../../core/database/taki_database_provider.dart';
import '../../../../core/domain/entities/music_identity.dart';
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

/// Identidades favoritas; se actualiza al instante tras cada cambio.
final favoriteIdentitiesProvider = StreamProvider<Set<MusicIdentity>>(
  (ref) => ref.watch(favoritesRepositoryProvider).watchFavoriteIdentities(),
);

/// Si la canción con esa [identity] es favorita. Solo reconstruye a quien la
/// observa cuando cambia esa canción.
final isFavoriteProvider = Provider.family<bool, MusicIdentity>(
  (ref, identity) => ref.watch(
    favoriteIdentitiesProvider.select(
      (identities) => identities.valueOrNull?.contains(identity) ?? false,
    ),
  ),
);

final toggleFavoriteProvider = Provider<ToggleFavorite>(
  (ref) => ToggleFavorite(ref.watch(favoritesRepositoryProvider)),
);

final getFavoriteSongsProvider = Provider<GetFavoriteSongs>(
  (ref) => GetFavoriteSongs(
    ref.watch(favoritesRepositoryProvider),
    ref.watch(songLookupProvider),
  ),
);

/// Canciones favoritas presentes en la biblioteca, las más recientes primero.
/// Se recalcula cuando cambian los favoritos o la biblioteca.
final favoriteSongsProvider = FutureProvider<List<Song>>((ref) async {
  await ref.watch(favoriteIdentitiesProvider.future);
  // La biblioteca local solo sirve al reencuentro de canciones locales: su
  // estado (sin permiso, error) no bloquea la resolución de otras fuentes.
  final songs = await localLibrarySongs(ref);
  return ref.read(getFavoriteSongsProvider).call(songs);
});

/// "Reintentar" tras un error de favoritos: reabre la base si hizo falta y,
/// si la biblioteca también falló, la vuelve a escanear.
void retryFavorites(WidgetRef ref) {
  ref.invalidate(takiDatabaseProvider);
  ref.invalidate(favoriteIdentitiesProvider);
  if (ref.read(songsProvider).hasError) {
    ref.read(songsProvider.notifier).retry();
  }
}
