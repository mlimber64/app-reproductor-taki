import '../../../../core/domain/entities/song.dart';
import '../../../../core/domain/services/song_matcher.dart';
import '../entities/playlist_entry.dart';
import '../entities/playlist_name.dart';
import '../ports/playlists_repository.dart';

/// Crea una playlist. Lanza [InvalidPlaylistNameException] si el nombre no es
/// válido. Devuelve el id.
class CreatePlaylist {
  const CreatePlaylist(this._playlists);

  final PlaylistsRepository _playlists;

  Future<int> call(String name) async {
    final error = PlaylistName.validate(name);
    if (error != null) throw InvalidPlaylistNameException(error);
    return _playlists.create(PlaylistName.normalize(name));
  }
}

class RenamePlaylist {
  const RenamePlaylist(this._playlists);

  final PlaylistsRepository _playlists;

  Future<void> call(int playlistId, String name) async {
    final error = PlaylistName.validate(name);
    if (error != null) throw InvalidPlaylistNameException(error);
    return _playlists.rename(playlistId, PlaylistName.normalize(name));
  }
}

class DeletePlaylist {
  const DeletePlaylist(this._playlists);

  final PlaylistsRepository _playlists;

  Future<void> call(int playlistId) => _playlists.delete(playlistId);
}

/// Añade al final. Devuelve `true` si alguna ya estaba en la playlist (se
/// añade igual; la UI solo avisa).
class AddSongsToPlaylist {
  const AddSongsToPlaylist(this._playlists);

  final PlaylistsRepository _playlists;

  Future<bool> call(int playlistId, List<Song> songs) async {
    if (songs.isEmpty) return false;
    final existing = {
      for (final entry in await _playlists.getEntries(playlistId)) entry.songId,
    };
    await _playlists.addSongs(playlistId, songs);
    return songs.any((song) => existing.contains(song.id));
  }
}

/// Quita una entrada; [undo] la vuelve a poner en su sitio.
class RemoveFromPlaylist {
  const RemoveFromPlaylist(this._playlists);

  final PlaylistsRepository _playlists;

  Future<void> call(PlaylistEntry entry) => _playlists.removeEntry(entry.id);

  Future<void> undo(PlaylistEntry entry) => _playlists.reinsertEntry(entry);
}

/// Reordena. Los índices son posiciones de la playlist (no de la lista
/// visible, que oculta las canciones que no están en la biblioteca).
class MovePlaylistSong {
  const MovePlaylistSong(this._playlists);

  final PlaylistsRepository _playlists;

  Future<void> call(int playlistId, int oldIndex, int newIndex) async {
    if (oldIndex == newIndex || oldIndex < 0 || newIndex < 0) return;
    await _playlists.move(playlistId, oldIndex, newIndex);
  }
}

/// Entradas de la playlist resueltas contra la biblioteca, en orden.
///
/// Usa el mismo [SongMatcher] que favoritos; si reencuentra una canción por un
/// criterio distinto al id, guarda el id nuevo. Las entradas que no están en
/// la biblioteca se ocultan pero no se borran.
class GetPlaylistSongs {
  const GetPlaylistSongs(this._playlists);

  final PlaylistsRepository _playlists;

  Future<List<PlaylistItem>> call(int playlistId, List<Song> library) async {
    final entries = await _playlists.getEntries(playlistId);
    if (entries.isEmpty) return const [];

    final matcher = SongMatcher(library);
    final items = <PlaylistItem>[];
    for (final entry in entries) {
      final song = matcher.match(entry);
      if (song == null) continue;
      if (song.id == entry.songId) {
        items.add(PlaylistItem(entry: entry, song: song));
        continue;
      }
      await _playlists.relink(entry.id, song);
      // La entrada que se muestra ya lleva el id y el respaldo nuevos (así un
      // Deshacer la reinserta bien).
      items.add(PlaylistItem(
        entry: PlaylistEntry(
          id: entry.id,
          playlistId: entry.playlistId,
          position: entry.position,
          songId: song.id,
          title: song.title,
          artist: song.artist,
          album: song.album,
          durationMs: song.durationMs,
          path: song.path,
        ),
        song: song,
      ));
    }
    return items;
  }
}
