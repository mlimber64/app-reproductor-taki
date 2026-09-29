import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/song_reference.dart';

/// Canción marcada como favorita, tal como se guardó.
///
/// Además del id guarda una copia de respaldo de sus datos, para reconocerla
/// si el id cambia (reescaneo de MediaStore, reinstalación…).
class FavoriteEntry extends Equatable implements SongReference {
  const FavoriteEntry({
    required this.songId,
    required this.addedAt,
    this.title,
    this.artist,
    this.album,
    this.durationMs,
    this.path,
  });

  @override
  final int songId;
  final DateTime addedAt;
  @override
  final String? title;
  @override
  final String? artist;
  final String? album;
  @override
  final int? durationMs;
  @override
  final String? path;

  @override
  List<Object?> get props =>
      [songId, addedAt, title, artist, album, durationMs, path];
}
