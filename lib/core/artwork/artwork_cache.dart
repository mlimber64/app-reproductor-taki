import 'dart:typed_data';

import '../domain/entities/artwork_reference.dart';
import '../domain/ports/artwork_repository.dart';
import '../domain/ports/remote_artwork_loader.dart';
import '../utils/lru_cache.dart';

/// Clave de la caché: **qué carátula** ([reference], con igualdad por valor) y a
/// qué tamaño. Una local y una remota nunca coinciden (son tipos distintos), y
/// dos URL distintas tampoco.
typedef ArtworkKey = ({ArtworkReference reference, int size});

/// Caché LRU en memoria de carátulas, con deduplicación de peticiones.
///
/// También recuerda las carátulas ausentes (`null`) para no volver a pedirlas
/// en cada scroll.
///
/// Según la referencia: la local se lee del [ArtworkRepository]; la remota, del
/// [RemoteArtworkLoader] si lo hay (hoy ninguno: se trata como ausente); la
/// no disponible no consulta a nadie.
class ArtworkCache {
  ArtworkCache(
    this._repository, {
    RemoteArtworkLoader? remoteLoader,
    int capacity = 200,
  })  : _remoteLoader = remoteLoader,
        _cache = LruCache<ArtworkKey, Uint8List?>(capacity);

  final ArtworkRepository _repository;
  final RemoteArtworkLoader? _remoteLoader;
  final LruCache<ArtworkKey, Uint8List?> _cache;
  final Map<ArtworkKey, Future<Uint8List?>> _inFlight = {};

  bool contains(ArtworkKey key) => _cache.containsKey(key);

  Uint8List? peek(ArtworkKey key) => _cache.get(key);

  Future<Uint8List?> _fetch(ArtworkKey key) {
    final size = key.size;
    return switch (key.reference) {
      LocalArtworkReference(:final albumId) =>
        _repository.getAlbumArtwork(albumId, size: size),
      final RemoteArtworkReference remote =>
        _remoteLoader?.load(remote, size: size) ?? Future.value(null),
      UnavailableArtworkReference() => Future.value(null),
    };
  }

  Future<Uint8List?> load(ArtworkKey key) {
    if (_cache.containsKey(key)) return Future.value(_cache.get(key));

    var failed = false;
    return _inFlight[key] ??= Future.sync(() => _fetch(key))
        .then<Uint8List?>((bytes) => bytes, onError: (Object _) {
      failed = true;
      return null;
    }).then((bytes) {
      // Un fallo local se recuerda como ausencia (como siempre). Uno remoto
      // suele ser transitorio (red, 5xx): se entrega `null` a quien lo pidió,
      // pero no se memoiza, para poder reintentarlo.
      if (!(failed && key.reference is RemoteArtworkReference)) {
        _cache.put(key, bytes);
      }
      return bytes;
    }).whenComplete(() {
      // Bloque sin valor: `remove` devuelve este mismo futuro y, si el
      // callback lo devolviera, whenComplete lo esperaría (nunca completaría).
      _inFlight.remove(key);
    });
  }

  void clear() => _cache.clear();
}
