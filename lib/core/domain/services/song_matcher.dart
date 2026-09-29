import '../entities/song.dart';
import '../entities/song_reference.dart';

/// Reencuentra canciones guardadas (favoritos, playlists…) en la biblioteca
/// escaneada.
///
/// Orden de búsqueda: id → ruta → título + artista (sin distinguir mayúsculas
/// ni espacios) con duración a ±[durationTolerance].
class SongMatcher {
  SongMatcher(
    List<Song> library, {
    this.durationTolerance = const Duration(seconds: 1),
  }) {
    for (final song in library) {
      _byId[song.id] = song;
      if (song.path.isNotEmpty) _byPath[song.path] = song;
      _byTitleArtist
          .putIfAbsent(_titleArtistKey(song.title, song.artist), () => [])
          .add(song);
    }
  }

  final Duration durationTolerance;
  final Map<int, Song> _byId = {};
  final Map<String, Song> _byPath = {};
  final Map<(String, String), List<Song>> _byTitleArtist = {};

  /// La canción de la biblioteca que corresponde a [reference], o `null` si
  /// no está (p. ej. el archivo se borró o la SD está desmontada).
  Song? match(SongReference reference) =>
      _byId[reference.songId] ??
      _matchByPath(reference) ??
      _matchByTitleArtistDuration(reference);

  Song? _matchByPath(SongReference reference) {
    final path = reference.path;
    return path == null || path.isEmpty ? null : _byPath[path];
  }

  Song? _matchByTitleArtistDuration(SongReference reference) {
    final title = reference.title;
    final durationMs = reference.durationMs;
    if (title == null || title.trim().isEmpty || durationMs == null) {
      return null;
    }
    final candidates =
        _byTitleArtist[_titleArtistKey(title, reference.artist)];
    if (candidates == null) return null;
    for (final song in candidates) {
      if ((song.durationMs - durationMs).abs() <=
          durationTolerance.inMilliseconds) {
        return song;
      }
    }
    return null;
  }

  static (String, String) _titleArtistKey(String title, String? artist) =>
      (title.trim().toLowerCase(), (artist ?? '').trim().toLowerCase());
}
