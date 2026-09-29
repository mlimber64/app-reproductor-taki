import 'dart:typed_data';

/// Carátulas de álbum.
abstract interface class ArtworkRepository {
  /// Imagen codificada (JPEG/PNG) de lado aproximado [size] px, o `null` si el
  /// álbum no tiene carátula.
  Future<Uint8List?> getAlbumArtwork(int albumId, {required int size});
}
