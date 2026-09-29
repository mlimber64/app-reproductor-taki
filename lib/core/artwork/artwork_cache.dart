import 'dart:typed_data';

import '../domain/ports/artwork_repository.dart';
import '../utils/lru_cache.dart';

typedef ArtworkKey = ({int albumId, int size});

/// Caché LRU en memoria de carátulas, con deduplicación de peticiones.
///
/// También recuerda los álbumes sin carátula (`null`) para no volver a
/// pedirlos en cada scroll.
class ArtworkCache {
  ArtworkCache(this._repository, {int capacity = 200})
      : _cache = LruCache<ArtworkKey, Uint8List?>(capacity);

  final ArtworkRepository _repository;
  final LruCache<ArtworkKey, Uint8List?> _cache;
  final Map<ArtworkKey, Future<Uint8List?>> _inFlight = {};

  bool contains(ArtworkKey key) => _cache.containsKey(key);

  Uint8List? peek(ArtworkKey key) => _cache.get(key);

  Future<Uint8List?> load(ArtworkKey key) {
    if (_cache.containsKey(key)) return Future.value(_cache.get(key));

    return _inFlight[key] ??= _repository
        .getAlbumArtwork(key.albumId, size: key.size)
        .then<Uint8List?>((bytes) => bytes, onError: (Object _) => null)
        .then((bytes) {
      _cache.put(key, bytes);
      return bytes;
    }).whenComplete(() {
      // Bloque sin valor: `remove` devuelve este mismo futuro y, si el
      // callback lo devolviera, whenComplete lo esperaría (nunca completaría).
      _inFlight.remove(key);
    });
  }

  void clear() => _cache.clear();
}
