import 'package:equatable/equatable.dart';

/// Playlist propia, con su resumen.
class Playlist extends Equatable {
  const Playlist({
    required this.id,
    required this.name,
    required this.songCount,
    required this.totalDurationMs,
    required this.createdAt,
    required this.updatedAt,
    this.coverSongIds = const [],
  });

  final int id;
  final String name;

  /// Entradas guardadas (incluye las que ahora no están en la biblioteca).
  final int songCount;
  final int totalDurationMs;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Ids de las primeras canciones (hasta 4), para el mosaico de carátulas.
  final List<int> coverSongIds;

  Duration get totalDuration => Duration(milliseconds: totalDurationMs);

  @override
  List<Object?> get props => [
        id,
        name,
        songCount,
        totalDurationMs,
        createdAt,
        updatedAt,
        coverSongIds,
      ];
}
