import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/artwork/http_remote_artwork_loader.dart';
import 'package:taki/core/artwork/io_artwork_http_client.dart';
import 'package:taki/core/domain/entities/artwork_exception.dart';
import 'package:taki/core/domain/entities/artwork_reference.dart';
import 'package:taki/core/domain/ports/artwork_http_client.dart';

final _png = Uint8List.fromList(
    [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3]);
final _jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1]);
final _gif = Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]);
final _webp = Uint8List.fromList(
    [0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50, 1]);

class _FakeClient implements ArtworkHttpClient {
  _FakeClient(this.handler);

  final FutureOr<ArtworkHttpResponse> Function(Uri uri) handler;
  final uris = <Uri>[];
  Duration? lastTimeout;
  int? lastMaxBytes;

  @override
  Future<ArtworkHttpResponse> get(
    Uri uri, {
    required Duration timeout,
    required int maxBytes,
  }) async {
    uris.add(uri);
    lastTimeout = timeout;
    lastMaxBytes = maxBytes;
    return handler(uri);
  }
}

HttpRemoteArtworkLoader loaderWith(
  FutureOr<ArtworkHttpResponse> Function(Uri) handler, {
  Duration timeout = const Duration(seconds: 10),
  int maxBytes = 1000,
}) =>
    HttpRemoteArtworkLoader(
      _FakeClient(handler),
      timeout: timeout,
      maxBytes: maxBytes,
    );

Future<Object?> errorOf(Future<Object?> future) async {
  try {
    await future;
  } catch (e) {
    return e;
  }
  return null;
}

void main() {
  final ref = RemoteArtworkReference('https://cdn.example/a.jpg');

  group('HttpRemoteArtworkLoader', () {
    test('respuesta 200 con imagen → bytes; GET a la URL de la referencia',
        () async {
      final client = _FakeClient((_) => ArtworkHttpResponse(200, _png));
      final loader = HttpRemoteArtworkLoader(client, maxBytes: 1000);

      expect(await loader.load(ref, size: 96), _png);
      expect(client.uris, [Uri.parse('https://cdn.example/a.jpg')]);
      expect(client.lastTimeout, const Duration(seconds: 10));
      expect(client.lastMaxBytes, 1000);
    });

    test('reconoce JPEG, PNG, GIF y WebP', () async {
      for (final body in [_jpeg, _png, _gif, _webp]) {
        final loader = loaderWith((_) => ArtworkHttpResponse(200, body));
        expect(await loader.load(ref, size: 1), body);
      }
    });

    test('cualquier 2xx vale, incluidos los bordes 200 y 299', () async {
      for (final status in [200, 203, 299]) {
        final loader = loaderWith((_) => ArtworkHttpResponse(status, _png));
        expect(await loader.load(ref, size: 1), _png, reason: '$status');
      }
    });

    test('estado no 2xx → ArtworkHttpException con el código', () async {
      for (final status in [199, 300, 301, 304, 404, 410, 500, 503]) {
        final loader = loaderWith((_) => ArtworkHttpResponse(status, _png));
        final error = await errorOf(loader.load(ref, size: 1));
        expect(error, isA<ArtworkHttpException>(), reason: '$status');
        expect((error! as ArtworkHttpException).statusCode, status);
      }
    });

    test('cuerpo vacío → ArtworkInvalidDataException', () async {
      final loader = loaderWith((_) => ArtworkHttpResponse(200, Uint8List(0)));
      final error = await errorOf(loader.load(ref, size: 1));
      expect(error, isA<ArtworkInvalidDataException>());
      expect((error! as ArtworkInvalidDataException).reason, 'cuerpo vacío');
    });

    test('bytes que no son una imagen → ArtworkInvalidDataException', () async {
      for (final body in [
        Uint8List.fromList([1, 2, 3]),
        Uint8List.fromList('<html></html>'.codeUnits),
        Uint8List.fromList([0xFF, 0xD8]), // JPEG truncado antes de la firma
        Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]), // PNG con firma a medias
        Uint8List.fromList([0x89, 1, 2, 3, 4, 5, 6, 7, 8]),
        Uint8List.fromList(
            [0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x41, 0x56, 0x45]), // WAV
      ]) {
        final loader = loaderWith((_) => ArtworkHttpResponse(200, body));
        expect(
          await errorOf(loader.load(ref, size: 1)),
          isA<ArtworkInvalidDataException>(),
        );
      }
    });

    test('cuerpo mayor que maxBytes → ArtworkInvalidDataException', () async {
      final big = Uint8List(11)..setAll(0, _jpeg);
      final loader = loaderWith(
        (_) => ArtworkHttpResponse(200, big),
        maxBytes: 10,
      );
      expect(
        await errorOf(loader.load(ref, size: 1)),
        isA<ArtworkInvalidDataException>(),
      );
    });

    test('excepción de red del cliente → ArtworkNetworkException', () async {
      final loader = loaderWith((_) => throw const SocketException('sin red'));
      final error = await errorOf(loader.load(ref, size: 1));
      expect(error, isA<ArtworkNetworkException>());
      expect((error! as ArtworkNetworkException).cause, isA<SocketException>());
    });

    test('ArtworkException del cliente se propaga tal cual', () async {
      final loader =
          loaderWith((_) => throw const ArtworkNetworkException('x'));
      expect(
        await errorOf(loader.load(ref, size: 1)),
        isA<ArtworkNetworkException>(),
      );
    });

    test('timeout: cliente que no responde → ArtworkNetworkException',
        () async {
      final never = Completer<ArtworkHttpResponse>();
      final loader = loaderWith(
        (_) => never.future,
        timeout: const Duration(milliseconds: 20),
      );
      expect(
        await errorOf(loader.load(ref, size: 1)),
        isA<ArtworkNetworkException>(),
      );
    });

    test('URL no utilizable → ArtworkUnsupportedUrlException sin llamar al '
        'cliente', () async {
      for (final url in [
        'no es una url',
        'ftp://x/a.jpg',
        'file:///a.jpg',
        'content://media/1',
        'https://',
        '/relativa.jpg',
        'http://:80/x',
      ]) {
        var called = false;
        final loader = loaderWith((_) {
          called = true;
          return ArtworkHttpResponse(200, _png);
        });
        expect(
          await errorOf(loader.load(RemoteArtworkReference(url), size: 1)),
          isA<ArtworkUnsupportedUrlException>(),
          reason: url,
        );
        expect(called, isFalse, reason: url);
      }
    });

    test('http (no solo https) es utilizable', () async {
      final loader = loaderWith((_) => ArtworkHttpResponse(200, _png));
      expect(
        await loader.load(RemoteArtworkReference('http://host/a.png'), size: 1),
        _png,
      );
    });
  });

  group('IoArtworkHttpClient (servidor local de prueba, sin Internet)', () {
    late HttpServer server;
    late Uri base;
    late void Function(HttpRequest) onRequest;
    const client = IoArtworkHttpClient();

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      base = Uri.parse('http://127.0.0.1:${server.port}');
      server.listen((request) => onRequest(request));
    });

    tearDown(() => server.close(force: true));

    test('devuelve estado y cuerpo', () async {
      onRequest = (r) {
        r.response
          ..statusCode = 200
          ..add(_png)
          ..close();
      };
      final response = await client.get(
        base.resolve('/a.png'),
        timeout: const Duration(seconds: 5),
        maxBytes: 100,
      );
      expect(response.statusCode, 200);
      expect(response.bodyBytes, _png);
    });

    test('devuelve estados no 2xx sin lanzar', () async {
      onRequest = (r) {
        r.response
          ..statusCode = 404
          ..close();
      };
      final response = await client.get(
        base,
        timeout: const Duration(seconds: 5),
        maxBytes: 100,
      );
      expect(response.statusCode, 404);
    });

    test('cuerpo mayor que maxBytes → ArtworkInvalidDataException', () async {
      onRequest = (r) {
        r.response
          ..add(Uint8List(500))
          ..close();
      };
      expect(
        await errorOf(client.get(
          base,
          timeout: const Duration(seconds: 5),
          maxBytes: 100,
        )),
        isA<ArtworkInvalidDataException>(),
      );
    });

    test('conexión rechazada → ArtworkNetworkException', () async {
      final port = server.port;
      await server.close(force: true);
      expect(
        await errorOf(client.get(
          Uri.parse('http://127.0.0.1:$port'),
          timeout: const Duration(seconds: 5),
          maxBytes: 100,
        )),
        isA<ArtworkNetworkException>(),
      );
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    });

    test('servidor que no responde → ArtworkNetworkException por tiempo',
        () async {
      onRequest = (_) {}; // nunca responde
      expect(
        await errorOf(client.get(
          base,
          timeout: const Duration(milliseconds: 100),
          maxBytes: 100,
        )),
        isA<ArtworkNetworkException>(),
      );
    });

    test('de punta a punta con HttpRemoteArtworkLoader', () async {
      onRequest = (r) {
        r.response
          ..add(_jpeg)
          ..close();
      };
      final loader = HttpRemoteArtworkLoader(client);
      expect(
        await loader.load(
          RemoteArtworkReference(base.resolve('/x.jpg').toString()),
          size: 1,
        ),
        _jpeg,
      );
    });
  });
}
