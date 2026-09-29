import '../../../../core/domain/entities/song.dart';
import '../ports/song_repository.dart';
import '../services/song_filter.dart';

/// Canciones de la biblioteca: solo lo que [SongFilter] acepta (sin audios
/// cortos ni carpetas de notas de voz, grabaciones, tonos…), ordenadas por
/// título.
class GetSongs {
  GetSongs(this._repository, {SongFilter? filter})
      : _filter = filter ?? SongFilter();

  final SongRepository _repository;
  final SongFilter _filter;

  Future<List<Song>> call() async {
    final songs = await _repository.getSongs();

    return _filter.apply(songs)
      ..sort((a, b) {
        final byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());
        return byTitle != 0 ? byTitle : a.id.compareTo(b.id);
      });
  }
}
