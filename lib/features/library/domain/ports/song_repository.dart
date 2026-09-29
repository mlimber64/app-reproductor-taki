import '../../../../core/domain/entities/song.dart';

/// Fuente de canciones. Hoy: MediaStore de Android. Mañana: Navidrome, etc.
abstract interface class SongRepository {
  Future<List<Song>> getSongs();
}
