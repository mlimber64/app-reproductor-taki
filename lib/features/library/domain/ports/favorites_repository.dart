import '../../../../core/domain/entities/music_identity.dart';
import '../../../../core/domain/entities/song.dart';
import '../entities/favorite_entry.dart';

/// Canciones favoritas guardadas. Se identifican por [MusicIdentity].
abstract interface class FavoritesRepository {
  /// Identidades favoritas. Emite el conjunto actual al suscribirse y otra vez
  /// tras cada cambio.
  Stream<Set<MusicIdentity>> watchFavoriteIdentities();

  /// Favoritos guardados, los más recientes primero.
  Future<List<FavoriteEntry>> getFavorites();

  /// Marca [song] como favorita. Si ya lo era, no hace nada.
  Future<void> add(Song song);

  Future<void> remove(MusicIdentity identity);

  /// El favorito guardado como [oldIdentity] es ahora [song] (su identidad
  /// cambió, p. ej. el id local tras un reescaneo): actualiza la identidad y los
  /// datos de respaldo, conservando la fecha.
  Future<void> relink(MusicIdentity oldIdentity, Song song);
}
