import '../../../../core/domain/entities/local_music_identity.dart';
import '../../../../core/domain/entities/local_song.dart';
import '../../../../core/domain/entities/song.dart';
import '../../../../core/domain/ports/song_lookup.dart';
import '../../../../core/domain/services/isolated_song_lookup.dart';
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
      for (final entry in await _playlists.getEntries(playlistId))
        entry.musicIdentity,
    };
    await _playlists.addSongs(playlistId, songs);
    return songs.any((song) => existing.contains(song.musicIdentity));
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

/// Entradas de la playlist resueltas a canciones, de cualquier fuente, en orden.
///
/// Misma resolución que favoritos: las identidades de **todas** las entradas
/// (con sus repeticiones) se resuelven en un lote con el [SongLookup]; a las
/// entradas locales `missing` se les aplica el reencuentro local
/// ([SongMatcher]) sobre la biblioteca y, si aparece con otra identidad, se
/// guarda la nueva (`relink`).
///
/// - Conserva **orden y duplicados**: se recorre cada entrada guardada, no el
///   conjunto de identidades; la misma canción dos veces da dos elementos, cada
///   uno con su propia entrada.
/// - Las entradas que no se resuelven (ausentes, fuente sin lookup) se ocultan
///   pero no se borran.
/// - El fallo de una fuente solo oculta **sus** entradas (sin reencuentro ni
///   borrado, y sin pasar a `missing`); si fallan todas las fuentes consultadas,
///   el error llega a quien llama.
class GetPlaylistSongs {
  const GetPlaylistSongs(this._playlists, this._lookup);

  final PlaylistsRepository _playlists;
  final SongLookup _lookup;

  /// [library] es la biblioteca local, solo para el reencuentro local.
  Future<List<PlaylistItem>> call(int playlistId, List<LocalSong> library) async {
    final entries = await _playlists.getEntries(playlistId);
    if (entries.isEmpty) return const [];

    final isolated = await findAllIsolatingSources(_lookup, {
      for (final entry in entries) entry.musicIdentity,
    });
    final resolved = isolated.result;
    final matcher = SongMatcher(library);

    final items = <PlaylistItem>[];
    for (final entry in entries) {
      final identity = entry.musicIdentity;
      // Su fuente falló: se oculta; ni reencuentro, ni relink, ni borrado.
      if (isolated.failed.contains(identity)) continue;
      final song = resolved.found[identity] ??
          (resolved.missing.contains(identity) &&
                  identity.source == localMusicSource
              ? matcher.match(entry)
              : null);
      if (song == null) continue;
      if (song.musicIdentity == identity) {
        items.add(PlaylistItem(entry: entry, song: song));
        continue;
      }
      await _playlists.relink(entry.id, song);
      // La entrada que se muestra ya lleva la identidad y el respaldo nuevos (así un
      // Deshacer la reinserta bien).
      items.add(PlaylistItem(
        entry: PlaylistEntry(
          id: entry.id,
          playlistId: entry.playlistId,
          position: entry.position,
          musicIdentity: song.musicIdentity,
          title: song.title,
          artist: song.artist,
          album: song.album,
          durationMs: song.durationMs,
          path: localPathOf(song),
        ),
        song: song,
      ));
    }
    return items;
  }
}