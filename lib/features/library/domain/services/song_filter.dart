import '../../../../core/constants/library_constants.dart';
import '../../../../core/domain/entities/local_song.dart';

/// Decide qué audios son canciones de la biblioteca.
///
/// - Descarta los de menos de [minDuration].
/// - Descarta los que están dentro de una carpeta excluida. Se compara cada
///   segmento de la ruta completo y sin distinguir mayúsculas: "Recordings"
///   excluye `Music/Recordings/` y `Media/Recordings/2026`, pero no
///   `Live Recordings Vol1`.
class SongFilter {
  SongFilter({
    this.minDuration = LibraryConstants.minSongDuration,
    Iterable<String> excludedFolders = LibraryConstants.excludedFolders,
  }) : _excludedFolders = {
          for (final folder in excludedFolders) _normalize(folder),
        };

  final Duration minDuration;
  final Set<String> _excludedFolders;

  static final RegExp _separator = RegExp(r'[/\\]');

  bool accepts(LocalSong song) =>
      song.durationMs >= minDuration.inMilliseconds &&
      !_isInExcludedFolder(song);

  List<LocalSong> apply(Iterable<LocalSong> songs) => songs.where(accepts).toList();

  bool _isInExcludedFolder(LocalSong song) {
    // Si la fuente no dio la carpeta, se usa la de la ruta del archivo.
    final folder = song.folder.isNotEmpty ? song.folder : _parentOf(song.path);
    return folder
        .split(_separator)
        .any((segment) => _excludedFolders.contains(_normalize(segment)));
  }

  static String _parentOf(String path) {
    final slash = path.lastIndexOf(_separator);
    return slash > 0 ? path.substring(0, slash) : '';
  }

  static String _normalize(String name) => name.trim().toLowerCase();
}
