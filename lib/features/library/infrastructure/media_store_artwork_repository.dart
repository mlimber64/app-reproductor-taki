import 'package:flutter/services.dart';

import '../domain/ports/artwork_repository.dart';
import 'media_store_channel.dart';

/// Carátulas desde MediaStore (miniaturas del sistema, incluidas las
/// incrustadas en los archivos).
class MediaStoreArtworkRepository implements ArtworkRepository {
  MediaStoreArtworkRepository({MethodChannel channel = mediaStoreChannel})
      : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<Uint8List?> getAlbumArtwork(int albumId, {required int size}) {
    return _channel.invokeMethod<Uint8List>('getArtwork', {
      'albumId': albumId,
      'size': size,
    });
  }
}
