import '../../../../core/domain/entities/music_identity.dart';

/// Caché **solo en memoria** (por sesión) de URLs de audio, por identidad.
///
/// La URL es temporal: caduca por TTL (más corto que lo observado, ≥20 min) y
/// nunca se escribe en disco ni en SQLite. Evita pedir a la API la misma pista
/// que una búsqueda o un lookup acaban de traer.
class JamendoAudioCache {
  JamendoAudioCache({
    this.ttl = const Duration(minutes: 10),
    this.capacity = 500,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration ttl;
  final int capacity;
  final DateTime Function() _clock;
  final Map<MusicIdentity, ({String url, DateTime at})> _entries = {};

  String? get(MusicIdentity identity) {
    final entry = _entries[identity];
    if (entry == null) return null;
    if (_clock().difference(entry.at) >= ttl) {
      _entries.remove(identity);
      return null;
    }
    return entry.url;
  }

  void put(MusicIdentity identity, String url) {
    _entries.remove(identity);
    _entries[identity] = (url: url, at: _clock());
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
  }

  void clear() => _entries.clear();
}
