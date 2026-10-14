import '../../../../core/domain/entities/local_song.dart';

/// Fuente de canciones. Hoy: MediaStore de Android. Mañana: Navidrome, etc.
abstract interface class SongRepository {
  Future<List<LocalSong>> getSongs();
}
