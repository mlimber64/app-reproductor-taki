import '../../../library/domain/entities/song.dart';
import '../entities/playlist.dart';
import '../entities/playlist_entry.dart';

/// Playlists propias guardadas.
///
/// Toda modificación hecha por el usuario actualiza `updatedAt` y deja las
/// posiciones de la playlist contiguas (0, 1, 2…).
abstract interface class PlaylistsRepository {
  /// Playlists, la modificada más recientemente primero. Emite al suscribirse
  /// y tras cada cambio.
  Stream<List<Playlist>> watchPlaylists();

  /// Entradas de la playlist, en orden.
  Future<List<PlaylistEntry>> getEntries(int playlistId);

  /// Crea una playlist vacía y devuelve su id. [name] ya viene validado.
  Future<int> create(String name);

  Future<void> rename(int playlistId, String name);

  /// Borra la playlist y sus entradas.
  Future<void> delete(int playlistId);

  /// Añade [songs] al final (aunque ya estén en la playlist).
  Future<void> addSongs(int playlistId, List<Song> songs);

  Future<void> removeEntry(int entryId);

  /// Vuelve a poner [entry] (quitada antes) en su posición original.
  Future<void> reinsertEntry(PlaylistEntry entry);

  /// Mueve la entrada en [oldIndex] para que quede en [newIndex] (posiciones
  /// de la playlist; posición final, como `List.insert` tras quitarla).
  Future<void> move(int playlistId, int oldIndex, int newIndex);

  /// La entrada [entryId] corresponde ahora a [song] (su id cambió): actualiza
  /// el id y el respaldo. Es mantenimiento: no cambia `updatedAt`.
  Future<void> relink(int entryId, Song song);
}
