import 'dart:collection';

/// Caché en memoria que descarta la entrada usada hace más tiempo al llenarse.
///
/// Admite valores `null` (útil para recordar "no hay dato" y no volver a pedirlo).
class LruCache<K, V> {
  LruCache(this.capacity) : assert(capacity > 0);

  final int capacity;
  final LinkedHashMap<K, V> _entries = LinkedHashMap<K, V>();

  int get length => _entries.length;

  bool containsKey(K key) => _entries.containsKey(key);

  /// Devuelve el valor y lo marca como usado recientemente.
  V? get(K key) {
    if (!_entries.containsKey(key)) return null;
    final value = _entries.remove(key) as V;
    _entries[key] = value;
    return value;
  }

  void put(K key, V value) {
    _entries.remove(key);
    _entries[key] = value;
    if (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
  }

  void clear() => _entries.clear();
}
