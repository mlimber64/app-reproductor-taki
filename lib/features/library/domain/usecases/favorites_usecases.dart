import '../entities/song.dart';
import '../ports/favorites_repository.dart';
import '../services/song_matcher.dart';

/// Marca o desmarca [Song] según su estado actual. Devuelve `true` si quedó
/// como favorita.
class ToggleFavorite {
  const ToggleFavorite(this._favorites);

  final FavoritesRepository _favorites;

  Future<bool> call(Song song) async {
    final ids = await _favorites.watchFavoriteIds().first;
    if (ids.contains(song.id)) {
      await _favorites.remove(song.id);
      return false;
    }
    await _favorites.add(song);
    return true;
  }
}

/// Cruza los favoritos guardados con las canciones de la biblioteca.
///
/// - Cada favorito se reencuentra con [SongMatcher] (id → ruta → título +
///   artista + duración, con [durationTolerance]).
/// - Si se encuentra por un criterio distinto al id, guarda el id nuevo.
/// - Los que no están en la biblioteca se ocultan, pero no se borran (p. ej. la
///   SD está desmontada y la canción vuelve después).
/// - Devuelve las canciones en orden de añadido, más recientes primero.
class GetFavoriteSongs {
  const GetFavoriteSongs(
    this._favorites, {
    this.durationTolerance = const Duration(seconds: 1),
  });

  final FavoritesRepository _favorites;
  final Duration durationTolerance;

  Future<List<Song>> call(List<Song> library) async {
    final entries = await _favorites.getFavorites();
    if (entries.isEmpty) return const [];

    final matcher = SongMatcher(library, durationTolerance: durationTolerance);
    final result = <Song>[];
    final seen = <int>{};
    for (final entry in entries) {
      final song = matcher.match(entry);
      if (song == null || !seen.add(song.id)) continue;

      if (song.id != entry.songId) {
        await _favorites.relink(entry.songId, song);
      }
      result.add(song);
    }
    return result;
  }
}
