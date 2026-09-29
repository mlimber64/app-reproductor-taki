import 'package:equatable/equatable.dart';

/// Canción de la biblioteca, independiente de la fuente que la provee.
class Song extends Equatable {
  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.albumId,
    required this.durationMs,
    required this.path,
    required this.contentUri,
    required this.dateAdded,
    this.folder = '',
  });

  final int id;
  final String title;

  /// `null` cuando la fuente no conoce el artista.
  final String? artist;

  /// `null` cuando la fuente no conoce el álbum.
  final String? album;
  final int? albumId;
  final int durationMs;

  /// Ruta del archivo. Solo informativa: en Android 10+ no se garantiza
  /// acceso directo; para reproducir usa [contentUri].
  final String path;

  /// URI con la que se abre el audio (p. ej. `content://media/...`).
  final String contentUri;
  final DateTime? dateAdded;

  /// Carpeta que contiene el archivo (p. ej. `Music/Rock/` o
  /// `/storage/emulated/0/Music/Rock`). Vacía si la fuente no la conoce.
  final String folder;

  Duration get duration => Duration(milliseconds: durationMs);

  @override
  List<Object?> get props => [
        id,
        title,
        artist,
        album,
        albumId,
        durationMs,
        path,
        contentUri,
        dateAdded,
        folder,
      ];
}
