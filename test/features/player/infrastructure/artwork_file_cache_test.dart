import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/entities/artwork_reference.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/core/domain/entities/song.dart';
import 'package:taki/core/domain/ports/artwork_repository.dart';
import 'package:taki/core/domain/ports/remote_artwork_loader.dart';
import 'package:taki/features/player/infrastructure/artwork_file_cache.dart';

import '../../../helpers/library_fakes.dart';
import '../../../helpers/universal_song.dart';

class _Repository implements ArtworkRepository {
  Uint8List? bytes = Uint8List.fromList([1, 2, 3]);
  bool fails = false;
  final requests = <(int, int)>[];

  @override
  Future<Uint8List?> getAlbumArtwork(int albumId, {required int size}) async {
    requests.add((albumId, size));
    if (fails) throw StateError('sin acceso');
    return bytes;
  }
}

void main() {
  late Directory dir;
  late _Repository repository;
  late ArtworkFileCache cache;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('taki_artwork_file_cache_');
    repository = _Repository();
    cache = ArtworkFileCache(repository, cacheDirectory: () async => dir);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  File fileFor(int albumId) =>
      File('${dir.path}/artwork/album_${albumId}_512.jpg');

  test('carátula local: guarda el archivo y devuelve su URI', () async {
    final uri = await cache.artUriFor(buildSong(albumId: 7));

    expect(uri, fileFor(7).uri);
    expect(fileFor(7).readAsBytesSync(), [1, 2, 3]);
    expect(repository.requests, [(7, 512)]);
  });

  test('lee la referencia de Song.artwork, no un albumId aparte', () async {
    // albumId 9, pero la fuente entrega la carátula del álbum 5.
    final song = buildSong(albumId: 9, artwork: const LocalArtworkReference(5));

    final uri = await cache.artUriFor(song);

    expect(uri, fileFor(5).uri);
    expect(repository.requests, [(5, 512)]);
    expect(fileFor(9).existsSync(), isFalse);
  });

  test('carátula remota sin loader: null, sin archivo y sin consultar el '
      'repositorio local', () async {
    final song = remoteSong(RemoteArtworkReference('https://x/a.jpg'));

    expect(await cache.artUriFor(song), isNull);
    expect(repository.requests, isEmpty);
    expect(Directory('${dir.path}/artwork').existsSync(), isFalse);
  });

  test('carátula no disponible: null sin consultar nada', () async {
    final song = remoteSong(const UnavailableArtworkReference());

    expect(await cache.artUriFor(song), isNull);
    expect(await cache.artUriFor(buildSong(albumId: null)), isNull);
    expect(repository.requests, isEmpty);
  });

  test('un archivo ya guardado se reutiliza sin volver a leer', () async {
    await cache.artUriFor(buildSong(albumId: 7));
    repository.requests.clear();

    expect(await cache.artUriFor(buildSong(albumId: 7)), fileFor(7).uri);
    expect(repository.requests, isEmpty);
  });

  test('sin carátula (null o bytes vacíos): null y se recuerda la ausencia',
      () async {
    repository.bytes = null;
    expect(await cache.artUriFor(buildSong(albumId: 7)), isNull);
    repository.bytes = Uint8List(0);
    expect(await cache.artUriFor(buildSong(albumId: 7)), isNull);

    expect(repository.requests, [(7, 512)]); // la segunda ni se pide
    expect(fileFor(7).existsSync(), isFalse);
  });

  test('un fallo de lectura se traduce en «sin carátula»', () async {
    repository.fails = true;
    expect(await cache.artUriFor(buildSong(albumId: 7)), isNull);
  });

  group('carátula remota (Fase 3.7B)', () {
    late _Loader loader;
    late ArtworkFileCache remote;
    final ref = RemoteArtworkReference('https://img.test/a.jpg?width=300');
    final song = remoteSong(ref);

    File remoteFile(String url) =>
        File('${dir.path}/artwork/${ArtworkFileCache.remoteFileName(url)}');

    List<String> artworkFiles() => Directory('${dir.path}/artwork')
        .listSync()
        .map((e) => e.path.split(RegExp(r'[\\/]')).last)
        .toList()
      ..sort();

    setUp(() {
      loader = _Loader();
      remote = ArtworkFileCache(
        repository,
        remoteArtworkLoader: loader,
        cacheDirectory: () async => dir,
      );
    });

    test('1: con loader crea el archivo, devuelve file:// y los bytes',
        () async {
      final uri = await remote.artUriFor(song);

      expect(uri, remoteFile(ref.url).uri);
      expect(uri!.scheme, 'file');
      expect(File.fromUri(uri).readAsBytesSync(), [9, 8, 7]);
      expect(loader.loads.single.$1, ref);
      expect(repository.requests, isEmpty); // no toca el repositorio local
    });

    test('2: la segunda llamada reutiliza el archivo sin llamar al loader',
        () async {
      await remote.artUriFor(song);
      loader.loads.clear();

      expect(await remote.artUriFor(song), remoteFile(ref.url).uri);
      expect(loader.loads, isEmpty);
    });

    test('3: URLs distintas → archivos distintos', () async {
      final other = RemoteArtworkReference('https://img.test/b.jpg?width=300');
      final a = await remote.artUriFor(song);
      final b = await remote.artUriFor(remoteSong(other));

      expect(a, isNot(b));
      expect(artworkFiles(), hasLength(2));
      // La URL completa es la clave: otra query es otro archivo.
      final sameHostOtherQuery =
          RemoteArtworkReference('https://img.test/a.jpg?width=600');
      expect(await remote.artUriFor(remoteSong(sameHostOtherQuery)),
          isNot(a));
    });

    test('la clave no es la identidad de la canción', () async {
      final s1 = buildUniversalSong(MusicIdentity('x', '1'), artwork: ref);
      final s2 = buildUniversalSong(MusicIdentity('y', '2'), artwork: ref);
      expect(await remote.artUriFor(s1), await remote.artUriFor(s2));
      expect(loader.loads, hasLength(1));
    });

    test('4: misma URL concurrente → una sola carga y el mismo resultado',
        () async {
      final gate = Completer<Uint8List?>();
      loader.handler = (_) => gate.future;

      final calls = [for (var i = 0; i < 4; i++) remote.artUriFor(song)];
      await pumpEventQueue();
      expect(loader.loads, hasLength(1));

      gate.complete(Uint8List.fromList([1, 2]));
      final results = await Future.wait(calls);

      expect(loader.loads, hasLength(1));
      expect(results.toSet(), {remoteFile(ref.url).uri});
    });

    test('4b: URLs distintas concurrentes no se fusionan', () async {
      final other = RemoteArtworkReference('https://img.test/b.jpg');
      await Future.wait([
        remote.artUriFor(song),
        remote.artUriFor(remoteSong(other)),
      ]);
      expect(loader.loads, hasLength(2));
    });

    test('5: el loader lanza → null y la siguiente llamada reintenta',
        () async {
      loader.handler = (_) async => throw StateError('red');
      expect(await remote.artUriFor(song), isNull);
      expect(remoteFile(ref.url).existsSync(), isFalse);

      loader.handler = null;
      expect(await remote.artUriFor(song), remoteFile(ref.url).uri);
      expect(loader.loads, hasLength(2));
    });

    test('un fallo en vuelo no deja la entrada: nuevas llamadas vuelven a '
        'intentarlo', () async {
      final gate = Completer<Uint8List?>();
      loader.handler = (_) => gate.future;
      final first = remote.artUriFor(song);
      await pumpEventQueue();
      gate.completeError(StateError('red'));
      expect(await first, isNull);

      loader.handler = null;
      expect(await remote.artUriFor(song), isNotNull);
      expect(loader.loads, hasLength(2));
    });

    test('6: el loader devuelve null → null, sin archivo', () async {
      loader.handler = (_) async => null;
      expect(await remote.artUriFor(song), isNull);
      expect(Directory('${dir.path}/artwork').existsSync(), isFalse);
    });

    test('7: el loader devuelve bytes vacíos → null, sin archivo', () async {
      loader.handler = (_) async => Uint8List(0);
      expect(await remote.artUriFor(song), isNull);
      expect(Directory('${dir.path}/artwork').existsSync(), isFalse);
    });

    test('8: Unavailable → null sin llamar al loader', () async {
      final unavailable = remoteSong(const UnavailableArtworkReference());
      expect(await remote.artUriFor(unavailable), isNull);
      expect(loader.loads, isEmpty);
    });

    test('9: remota sin loader → null', () async {
      expect(await cache.artUriFor(song), isNull);
    });

    test('10: archivo borrado → se vuelve a descargar y regenerar', () async {
      final uri = await remote.artUriFor(song);
      File.fromUri(uri!).deleteSync();
      loader.loads.clear();

      expect(await remote.artUriFor(song), uri);
      expect(loader.loads, hasLength(1));
      expect(File.fromUri(uri).existsSync(), isTrue);
    });

    test('11: nombre estable: misma URL, mismo archivo entre instancias '
        '(persiste entre reinicios)', () async {
      final first = await remote.artUriFor(song);

      final second = _Loader();
      final restarted = ArtworkFileCache(
        repository,
        remoteArtworkLoader: second,
        cacheDirectory: () async => dir,
      );
      expect(await restarted.artUriFor(song), first);
      expect(second.loads, isEmpty); // se reutiliza el archivo
    });

    test('el nombre es remote_<fnv1a64>.img con vectores conocidos', () {
      expect(ArtworkFileCache.fnv1a64(''), 'cbf29ce484222325');
      expect(ArtworkFileCache.fnv1a64('a'), 'af63dc4c8601ec8c');
      expect(ArtworkFileCache.fnv1a64('foobar'), '85944171f73967e8');
      expect(ArtworkFileCache.remoteFileName('a'),
          'remote_af63dc4c8601ec8c.img');
      // Sobre UTF-8 (2 bytes para «é»), no sobre code units.
      expect(ArtworkFileCache.fnv1a64('é'), '0ac21707b7181e01');
      // Siempre 16 cifras, también con ceros a la izquierda.
      expect(ArtworkFileCache.fnv1a64('u0'), '08c47a07b5674640');
      expect(ArtworkFileCache.remoteFileName('u0'),
          'remote_08c47a07b5674640.img');
    });

    test('12: escritura atómica — el archivo final nunca se ve parcial',
        () async {
      final big = Uint8List(24 * 1024 * 1024)..fillRange(0, 24 * 1024 * 1024, 5);
      loader.handler = (_) async => big;
      final target = remoteFile(ref.url);
      final observed = <int>[];
      final timer = Timer.periodic(const Duration(milliseconds: 1), (_) {
        if (target.existsSync()) observed.add(target.lengthSync());
      });

      final uri = await remote.artUriFor(song);
      timer.cancel();

      expect(uri, target.uri);
      expect(target.lengthSync(), big.length);
      expect(observed.where((n) => n != big.length), isEmpty);
    });

    test('la escritura no deja temporales', () async {
      await remote.artUriFor(song);
      expect(artworkFiles(), [ArtworkFileCache.remoteFileName(ref.url)]);
    });

    test('si no se puede escribir: null, sin temporales y sin propagar el '
        'error; la siguiente llamada reintenta', () async {
      // Un directorio ocupa el nombre del archivo final: el rename falla.
      final target = remoteFile(ref.url)..createSync(recursive: true);
      target.deleteSync();
      Directory(target.path).createSync(recursive: true);

      expect(await remote.artUriFor(song), isNull);
      expect(artworkFiles(), [ArtworkFileCache.remoteFileName(ref.url)]);

      Directory(target.path).deleteSync();
      expect(await remote.artUriFor(song), target.uri);
      expect(loader.loads, hasLength(2));
    });

    test('13: la rama local sigue igual aunque haya loader', () async {
      final uri = await remote.artUriFor(buildSong(albumId: 7));
      expect(uri, fileFor(7).uri);
      expect(repository.requests, [(7, 512)]);
      expect(loader.loads, isEmpty);
    });

    test('el loader recibe la referencia y el tamaño', () async {
      await remote.artUriFor(song);
      expect(loader.loads.single, (ref, 512));
    });
  });
}

/// Loader falso: bytes `[9, 8, 7]` por defecto, o lo que diga [handler].
class _Loader implements RemoteArtworkLoader {
  final loads = <(RemoteArtworkReference, int)>[];
  Future<Uint8List?> Function(RemoteArtworkReference)? handler;

  @override
  Future<Uint8List?> load(RemoteArtworkReference reference,
      {required int size}) {
    loads.add((reference, size));
    final h = handler;
    if (h != null) return h(reference);
    return Future.value(Uint8List.fromList([9, 8, 7]));
  }
}

/// Canción universal (otra fuente) con la carátula dada.
Song remoteSong(ArtworkReference artwork) =>
    buildUniversalSong(MusicIdentity('otra', 'x'), artwork: artwork);
