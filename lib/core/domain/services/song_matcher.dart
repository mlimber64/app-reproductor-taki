import '../entities/music_identity.dart';
import '../entities/local_song.dart';
import '../entities/song_reference.dart';

/// Reencuentra canciones guardadas (favoritos, playlists…) en la biblioteca
/// escaneada.
///
/// Orden de búsqueda: identidad → ruta → título + artista (sin distinguir
/// mayúsculas ni espacios) con duración a ±[durationTolerance].
///
/// Es la política de la fuente **local**: la biblioteca solo tiene canciones
/// locales ([LocalSong]), y la ruta y el título son criterios propios de ella.
class SongMatcher {
  SongMatcher(
    List<LocalSong> library, {
    this.durationTolerance = const Duration(seconds: 1),
  }) {
    for (final song in library) {
      _byIdentity[song.musicIdentity] = song;
      if (song.path.isNotEmpty) _byPath[song.path] = song;
      _byTitleArtist
          .putIfAbsent(_titleArtistKey(song.title, song.artist), () => [])
          .add(song);
    }
  }

  final Duration durationTolerance;
  final Map<MusicIdentity, LocalSong> _byIdentity = {};
  final Map<String, LocalSong> _byPath = {};
  final Map<(String, String), List<LocalSong>> _byTitleArtist = {};

  /// La canción de la biblioteca que corresponde a [reference], o `null` si
  /// no está (p. ej. el archivo se borró o la SD está desmontada).
  LocalSong? match(SongReference reference) =>
      _byIdentity[reference.musicIdentity] ??
      _matchByPath(reference) ??
      _matchByTitleArtistDuration(reference);

  LocalSong? _matchByPath(SongReference reference) {
    final path = reference.path;
    return path == null || path.isEmpty ? null : _byPath[path];
  }

  LocalSong? _matchByTitleArtistDuration(SongReference reference) {
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
