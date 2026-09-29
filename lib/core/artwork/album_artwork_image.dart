import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'artwork_cache.dart';

/// Carátula de un álbum como [ImageProvider], leída a través de
/// [ArtworkCache] (la misma caché y deduplicación que `ArtworkImage`).
///
/// Permite que `TakiArtwork` muestre la carátula sin saber de dónde sale.
/// Pide la imagen al tamaño en píxeles reales de [size] y la decodifica a ese
/// ancho. Si el álbum no tiene carátula, la carga falla con
/// [ArtworkUnavailable] y quien la muestra pinta su placeholder.
@immutable
class AlbumArtworkImage extends ImageProvider<ArtworkKey> {
  const AlbumArtworkImage(this.albumId, {required this.size, required this.cache});

  final int albumId;

  /// Lado en píxeles lógicos con el que se va a mostrar.
  final double size;
  final ArtworkCache cache;

  @override
  Future<ArtworkKey> obtainKey(ImageConfiguration configuration) {
    final ratio = configuration.devicePixelRatio ?? 1;
    return SynchronousFuture((albumId: albumId, size: (size * ratio).round()));
  }

  @override
  ImageStreamCompleter loadImage(ArtworkKey key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _load(key, decode),
      scale: 1,
      debugLabel: 'AlbumArtworkImage(${key.albumId}, ${key.size}px)',
    );
  }

  Future<ui.Codec> _load(ArtworkKey key, ImageDecoderCallback decode) async {
    final bytes = await cache.load(key);
    if (bytes == null || bytes.isEmpty) {
      throw ArtworkUnavailable(key.albumId);
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(
      buffer,
      getTargetSize: (width, height) => ui.TargetImageSize(width: key.size),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AlbumArtworkImage &&
      other.albumId == albumId &&
      other.size == size &&
      identical(other.cache, cache);

  @override
  int get hashCode => Object.hash(albumId, size, identityHashCode(cache));
}

/// El álbum no tiene carátula (o no se pudo leer). No es un error para el
/// usuario: se muestra el placeholder.
class ArtworkUnavailable implements Exception {
  const ArtworkUnavailable(this.albumId);

  final int albumId;

  @override
  String toString() => 'ArtworkUnavailable(albumId: $albumId)';
}
