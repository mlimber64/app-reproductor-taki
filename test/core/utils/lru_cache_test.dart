import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/utils/lru_cache.dart';

void main() {
  test('descarta la entrada usada hace más tiempo', () {
    final cache = LruCache<String, int>(2)
      ..put('a', 1)
      ..put('b', 2);

    cache.get('a'); // "a" pasa a ser la más reciente.
    cache.put('c', 3);

    expect(cache.containsKey('a'), isTrue);
    expect(cache.containsKey('b'), isFalse);
    expect(cache.containsKey('c'), isTrue);
    expect(cache.length, 2);
  });

  test('distingue un valor null guardado de una clave ausente', () {
    final cache = LruCache<int, String?>(2)..put(1, null);

    expect(cache.containsKey(1), isTrue);
    expect(cache.get(1), isNull);
    expect(cache.containsKey(2), isFalse);
  });
}
