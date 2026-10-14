import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../domain/entities/artwork_exception.dart';
import '../domain/ports/artwork_http_client.dart';

/// [ArtworkHttpClient] sobre `dart:io` (`HttpClient`): sin dependencias nuevas.
///
/// Un `GET` por petición, sin cabeceras propias ni autenticación; sigue
/// redirecciones. Lee el cuerpo como mucho hasta [ArtworkHttpClient.get]'s
/// `maxBytes`.
class IoArtworkHttpClient implements ArtworkHttpClient {
  const IoArtworkHttpClient();

  @override
  Future<ArtworkHttpResponse> get(
    Uri uri, {
    required Duration timeout,
    required int maxBytes,
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(uri).timeout(timeout);
      final response = await request.close().timeout(timeout);

      final body = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(timeout)) {
        body.add(chunk);
        if (body.length > maxBytes) {
          throw const ArtworkInvalidDataException('imagen demasiado grande');
        }
      }
      return ArtworkHttpResponse(response.statusCode, body.takeBytes());
    } on ArtworkException {
      rethrow;
    } on TimeoutException catch (e) {
      throw ArtworkNetworkException('tiempo agotado', cause: e);
    } on Exception catch (e) {
      // SocketException, HttpException, HandshakeException…
      throw ArtworkNetworkException('fallo de red', cause: e);
    } finally {
      client.close(force: true);
    }
  }
}
