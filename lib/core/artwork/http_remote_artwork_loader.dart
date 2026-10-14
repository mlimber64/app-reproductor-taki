import 'dart:async';
import 'dart:typed_data';

import '../domain/entities/artwork_exception.dart';
import '../domain/entities/artwork_reference.dart';
import '../domain/ports/artwork_http_client.dart';
import '../domain/ports/remote_artwork_loader.dart';

/// Cargador genérico de carátulas remotas: `GET` de la URL de la referencia y
/// validación de que lo recibido es una imagen.
///
/// No conoce proveedores, endpoints, claves ni cabeceras. La URL se trata como
/// texto opaco: aquí solo se comprueba que sirve para una petición
/// (`http`/`https` con host); no se normaliza ni se usa como identidad.
///
/// Resultado: los bytes de la imagen. Nunca `null`: «no hay imagen» no es algo
/// que este cargador pueda afirmar (un 404 de una URL es un fallo, no una
/// ausencia definitiva). Todo fallo se lanza como [ArtworkLoadException]:
/// - URL no utilizable → [ArtworkUnsupportedUrlException].
/// - Transporte / tiempo agotado → [ArtworkNetworkException].
/// - Estado no 2xx → [ArtworkHttpException].
/// - Cuerpo vacío, mayor que [maxBytes] o que no es JPEG/PNG/GIF/WebP →
///   [ArtworkInvalidDataException].
///
/// `size` es solo una pista y se ignora: se devuelve la imagen tal cual; el
/// `ResizeImage` de la UI limita la decodificación.
class HttpRemoteArtworkLoader implements RemoteArtworkLoader {
  HttpRemoteArtworkLoader(
    this._client, {
    this.timeout = const Duration(seconds: 10),
    this.maxBytes = 5 * 1024 * 1024,
  });

  final ArtworkHttpClient _client;
  final Duration timeout;
  final int maxBytes;

  @override
  Future<Uint8List?> load(
    RemoteArtworkReference reference, {
    required int size,
  }) async {
    final uri = Uri.tryParse(reference.url);
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      throw ArtworkUnsupportedUrlException(reference.url);
    }

    final ArtworkHttpResponse response;
    try {
      response = await _client
          .get(uri, timeout: timeout, maxBytes: maxBytes)
          .timeout(timeout);
    } on ArtworkException {
      rethrow;
    } on TimeoutException catch (e) {
      throw ArtworkNetworkException('tiempo agotado', cause: e);
    } catch (e) {
      throw ArtworkNetworkException('fallo de red', cause: e);
    }

    if (response.statusCode < 200 || response.statusCode > 299) {
      throw ArtworkHttpException(response.statusCode);
    }
    final bytes = response.bodyBytes;
    if (bytes.isEmpty) throw const ArtworkInvalidDataException('cuerpo vacío');
    if (bytes.length > maxBytes) {
      throw const ArtworkInvalidDataException('imagen demasiado grande');
    }
    if (!looksLikeImage(bytes)) {
      throw const ArtworkInvalidDataException('formato no reconocido');
    }
    return bytes;
  }

  /// Firma de JPEG, PNG, GIF o WebP. No decodifica: si la firma es buena pero
  /// la imagen está corrupta, `TakiArtwork` muestra el placeholder.
  static bool looksLikeImage(Uint8List b) {
    bool starts(List<int> sig, [int offset = 0]) {
      if (b.length < offset + sig.length) return false;
      for (var i = 0; i < sig.length; i++) {
        if (b[offset + i] != sig[i]) return false;
      }
      return true;
    }

    return starts(const [0xFF, 0xD8, 0xFF]) || // JPEG
        starts(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) || // PNG
        starts(const [0x47, 0x49, 0x46, 0x38]) || // GIF8
        (starts(const [0x52, 0x49, 0x46, 0x46]) &&
            starts(const [0x57, 0x45, 0x42, 0x50], 8)); // RIFF....WEBP
  }
}
