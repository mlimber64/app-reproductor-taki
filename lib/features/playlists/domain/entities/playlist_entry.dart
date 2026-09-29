import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/song.dart';
import '../../../../core/domain/entities/song_reference.dart';

/// Una canción dentro de una playlist, tal como se guardó: id de la entrada,
/// su posición y la referencia de respaldo a la canción.
class PlaylistEntry extends Equatable implements SongReference {
  const PlaylistEntry({
    required this.id,
    required this.playlistId,
    required this.position,
    required this.songId,
    this.title,
    this.artist,
    this.album,
    this.durationMs,
    this.path,
  });

  /// Id de la entrada (no de la canción): la misma canción puede estar varias
  /// veces en una playlist.
  final int id;
  final int playlistId;

  /// Posición en la playlist, desde 0 y sin huecos.
  final int position;

  @override
  final int songId;
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
      [id, playlistId, position, songId, title, artist, album, durationMs, path];
}

/// Entrada de playlist resuelta contra la biblioteca: lo que se muestra.
class PlaylistItem extends Equatable {
  const PlaylistItem({required this.entry, required this.song});

  final PlaylistEntry entry;
  final Song song;

  @override
  List<Object?> get props => [entry, song];
}
