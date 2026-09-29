import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../core/domain/entities/song.dart';
import '../../../core/domain/ports/artwork_repository.dart';

/// Guarda carátulas como archivos en la caché de la app para la notificación
/// y la pantalla de bloqueo, que necesitan una URI (`file://…`), no bytes.
class ArtworkFileCache {
  ArtworkFileCache(
    this._artwork, {
    Future<Directory> Function()? cacheDirectory,
    this.size = 512,
  }) : _cacheDirectory = cacheDirectory ?? getTemporaryDirectory;

  final ArtworkRepository _artwork;
  final Future<Directory> Function() _cacheDirectory;

  /// Lado en px de la imagen guardada.
  final int size;

  /// Álbumes que sabemos que no tienen carátula (durante esta sesión).
  final Set<int> _withoutArtwork = {};

  /// URI del archivo de carátula de [song], o `null` si no tiene.
  Future<Uri?> artUriFor(Song song) async {
    final albumId = song.albumId;
    if (albumId == null || _withoutArtwork.contains(albumId)) return null;

    try {
      final directory = Directory('${(await _cacheDirectory()).path}/artwork');
      final file = File('${directory.path}/album_${albumId}_$size.jpg');
      if (await file.exists()) return file.uri;

      final bytes = await _artwork.getAlbumArtwork(albumId, size: size);
      if (bytes == null || bytes.isEmpty) {
        _withoutArtwork.add(albumId);
        return null;
      }

      await directory.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      return file.uri;
    } catch (_) {
      return null; // Sin carátula antes que sin notificación.
    }
  }
}
