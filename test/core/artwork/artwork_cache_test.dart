import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/artwork/artwork_cache.dart';
import 'package:taki/core/domain/ports/artwork_repository.dart';

class _Repository implements ArtworkRepository {
  _Repository(this.bytes, {this.fails = false});

  final Uint8List? bytes;
  final bool fails;
  int calls = 0;
  Completer<void>? gate;

  @override
  Future<Uint8List?> getAlbumArtwork(int albumId, {required int size}) async {
    calls++;
    await gate?.future;
    if (fails) throw Exception('sin acceso');
    return bytes;
  }
}

void main() {
  const key = (albumId: 1, size: 144);
  final bytes = Uint8List.fromList([1, 2, 3]);

  test('load completa con los bytes en la primera carga', () async {
    // Regresión: el futuro se esperaba a sí mismo y no completaba nunca.
    final cache = ArtworkCache(_Repository(bytes));

    await expectLater(
      cache.load(key).timeout(const Duration(seconds: 1)),
      completion(bytes),
    );
    expect(cache.peek(key), bytes);
  });

  test('peticiones simultáneas comparten una sola lectura', () async {
    final repository = _Repository(bytes)..gate = Completer<void>();
    final cache = ArtworkCache(repository);

    final first = cache.load(key);
    final second = cache.load(key);
    repository.gate!.complete();

    expect(await Future.wait([first, second]), [bytes, bytes]);
    expect(repository.calls, 1);
  });

  test('recuerda los álbumes sin carátula y no los vuelve a pedir', () async {
    final repository = _Repository(null);
    final cache = ArtworkCache(repository);

    expect(await cache.load(key), isNull);
    expect(await cache.load(key), isNull);
    expect(repository.calls, 1);
    expect(cache.contains(key), isTrue);
  });

  test('un fallo de lectura se trata como carátula ausente', () async {
    final cache = ArtworkCache(_Repository(null, fails: true));
    expect(await cache.load(key), isNull);
  });
}
