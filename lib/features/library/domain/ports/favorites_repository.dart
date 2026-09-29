import '../entities/favorite_entry.dart';
import '../entities/song.dart';

/// Canciones favoritas guardadas.
abstract interface class FavoritesRepository {
  /// Ids favoritos. Emite el conjunto actual al suscribirse y otra vez tras
  /// cada cambio.
  Stream<Set<int>> watchFavoriteIds();

  /// Favoritos guardados, los más recientes primero.
  Future<List<FavoriteEntry>> getFavorites();

  /// Marca [song] como favorita. Si ya lo era, no hace nada.
  Future<void> add(Song song);

  Future<void> remove(int songId);

  /// El favorito guardado como [oldSongId] es ahora [song] (su id cambió):
  /// actualiza el id y los datos de respaldo, conservando la fecha.
  Future<void> relink(int oldSongId, Song song);
}
