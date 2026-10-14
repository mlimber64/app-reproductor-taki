import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/music_identity.dart';
import '../../../../core/domain/entities/song_reference.dart';

/// Canción marcada como favorita, tal como se guardó.
///
/// Se identifica por [musicIdentity] (fuente + id externo). Además guarda una
/// copia de respaldo de sus datos, para reconocerla si hiciera falta (p. ej.
/// si el id de MediaStore cambia tras un reescaneo o una reinstalación).
class FavoriteEntry extends Equatable implements SongReference {
  const FavoriteEntry({
    required this.musicIdentity,
    required this.addedAt,
    this.title,
    this.artist,
    this.album,
    this.durationMs,
    this.path,
  });

  @override
  final MusicIdentity musicIdentity;
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
      [musicIdentity, addedAt, title, artist, album, durationMs, path];
}
