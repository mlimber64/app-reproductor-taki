import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/artwork/artwork_cache.dart';
import 'package:taki/core/domain/entities/artwork_reference.dart';
import 'package:taki/core/domain/ports/artwork_repository.dart';
import 'package:taki/core/domain/ports/remote_artwork_loader.dart';

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
  const key = (reference: LocalArtworkReference(1), size: 144);
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

  group('referencias', () {
    final remote = RemoteArtworkReference('https://x/a.jpg');
    ArtworkKey remoteKey(RemoteArtworkReference r, [int size = 144]) =>
        (reference: r, size: size);

    test('local y remota con «el mismo número» no colisionan', () async {
      final repository = _Repository(bytes);
      final loader = _Loader(Uint8List.fromList([9]));
      final cache = ArtworkCache(repository, remoteLoader: loader);

      final local = await cache.load((
        reference: const LocalArtworkReference(7),
        size: 144,
      ));
      final other = await cache.load(remoteKey(RemoteArtworkReference('7')));

      expect(local, bytes);
      expect(other, [9]);
      expect(repository.calls, 1);
      expect(loader.calls, 1);
    });

    test('URLs distintas se cachean por separado; la misma se reutiliza',
        () async {
      final loader = _Loader(Uint8List.fromList([9]));
      final cache = ArtworkCache(_Repository(bytes), remoteLoader: loader);

      await cache.load(remoteKey(remote));
      await cache.load(remoteKey(RemoteArtworkReference('https://x/a.jpg')));
      expect(loader.calls, 1);

      await cache.load(remoteKey(RemoteArtworkReference('https://x/b.jpg')));
      expect(loader.calls, 2);
    });

    test('la misma URL con otro tamaño declarado o pedido es otra entrada',
        () async {
      final loader = _Loader(Uint8List.fromList([9]));
      final cache = ArtworkCache(_Repository(bytes), remoteLoader: loader);

      await cache.load(remoteKey(RemoteArtworkReference('u', width: 1)));
      await cache.load(remoteKey(RemoteArtworkReference('u', width: 2)));
      await cache.load(remoteKey(RemoteArtworkReference('u', width: 2), 288));
      expect(loader.calls, 3);
    });

    test('el cargador remoto recibe la referencia y el tamaño pedidos',
        () async {
      final loader = _Loader(Uint8List.fromList([9]));
      final cache = ArtworkCache(_Repository(bytes), remoteLoader: loader);

      await cache.load(remoteKey(remote, 96));
      expect(loader.requests, [(remote, 96)]);
    });

    test('remota sin cargador: ausente, sin red ni lecturas locales', () async {
      final repository = _Repository(bytes);
      final cache = ArtworkCache(repository);

      expect(await cache.load(remoteKey(remote)), isNull);
      expect(cache.contains(remoteKey(remote)), isTrue);
      expect(repository.calls, 0);
    });

    test('un fallo del cargador remoto se trata como ausente', () async {
      final cache = ArtworkCache(
        _Repository(bytes),
        remoteLoader: _Loader(null, fails: true),
      );
      expect(await cache.load(remoteKey(remote)), isNull);
    });

    test('un fallo remoto NO se memoiza: se reintenta; uno local sí', () async {
      final loader = _Loader(null, fails: true);
      final cache = ArtworkCache(_Repository(null, fails: true),
          remoteLoader: loader);

      expect(await cache.load(remoteKey(remote)), isNull);
      expect(cache.contains(remoteKey(remote)), isFalse);
      expect(await cache.load(remoteKey(remote)), isNull);
      expect(loader.calls, 2);

      // Local: sigue recordándose como ausente (comportamiento previo).
      expect(await cache.load(key), isNull);
      expect(cache.contains(key), isTrue);
    });

    test('tras un fallo remoto, un reintento con éxito se cachea', () async {
      final loader = _Loader(Uint8List.fromList([9]), failFirst: true);
      final cache = ArtworkCache(_Repository(bytes), remoteLoader: loader);

      expect(await cache.load(remoteKey(remote)), isNull);
      expect(await cache.load(remoteKey(remote)), [9]);
      expect(await cache.load(remoteKey(remote)), [9]);
      expect(loader.calls, 2);
    });

    test('una ausencia remota (null del cargador) sí se memoiza', () async {
      final loader = _Loader(null);
      final cache = ArtworkCache(_Repository(bytes), remoteLoader: loader);

      await cache.load(remoteKey(remote));
      await cache.load(remoteKey(remote));
      expect(loader.calls, 1);
    });

    test('un cargador que lanza de forma síncrona también se trata como '
        'fallo', () async {
      final cache = ArtworkCache(_Repository(bytes), remoteLoader: _SyncThrows());
      expect(await cache.load(remoteKey(remote)), isNull);
    });

    test('peticiones remotas simultáneas comparten una lectura', () async {
      final loader = _Loader(Uint8List.fromList([9]));
      final cache = ArtworkCache(_Repository(bytes), remoteLoader: loader);

      await Future.wait([
        cache.load(remoteKey(remote)),
        cache.load(remoteKey(remote)),
      ]);
      expect(loader.calls, 1);
    });

    test('una remota jamás consulta el repositorio local (éxito, fallo o '
        'sin cargador)', () async {
      final repository = _Repository(bytes);
      final withOk = ArtworkCache(repository,
          remoteLoader: _Loader(Uint8List.fromList([9])));
      final withFail =
          ArtworkCache(repository, remoteLoader: _Loader(null, fails: true));
      final without = ArtworkCache(repository);

      await withOk.load(remoteKey(remote));
      await withFail.load(remoteKey(remote));
      await without.load(remoteKey(remote));
      expect(repository.calls, 0);
    });

    test('no disponible no consulta a nadie', () async {
      final repository = _Repository(bytes);
      final loader = _Loader(bytes);
      final cache = ArtworkCache(repository, remoteLoader: loader);

      expect(
        await cache.load(
          (reference: const UnavailableArtworkReference(), size: 144),
        ),
        isNull,
      );
      expect(repository.calls + loader.calls, 0);
    });
  });
}

class _SyncThrows implements RemoteArtworkLoader {
  @override
  Future<Uint8List?> load(
    RemoteArtworkReference reference, {
    required int size,
  }) =>
      throw StateError('síncrono');
}

class _Loader implements RemoteArtworkLoader {
  _Loader(this.bytes, {this.fails = false, this.failFirst = false});

  final Uint8List? bytes;
  final bool fails;
  final bool failFirst;
  final requests = <(RemoteArtworkReference, int)>[];

  int get calls => requests.length;

  @override
  Future<Uint8List?> load(
    RemoteArtworkReference reference, {
    required int size,
  }) async {
    requests.add((reference, size));
    if (fails || (failFirst && requests.length == 1)) {
      throw Exception('sin red');
    }
    return bytes;
  }
}
