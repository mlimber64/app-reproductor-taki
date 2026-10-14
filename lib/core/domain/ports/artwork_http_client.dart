import 'dart:typed_data';

/// Respuesta HTTP mínima: estado y cuerpo.
final class ArtworkHttpResponse {
  const ArtworkHttpResponse(this.statusCode, this.bodyBytes);

  final int statusCode;
  final Uint8List bodyBytes;
}

/// Cliente HTTP mínimo (solo `GET`) tras el que se esconde la red.
///
/// Genérico: no conoce proveedores, ni cabeceras, ni autenticación. Existe para
/// poder probar `HttpRemoteArtworkLoader` con un falso, sin Internet.
///
/// Contrato:
/// - Devuelve la respuesta **sea cual sea el estado** (interpretarlo es del
///   llamador).
/// - Lanza `ArtworkNetworkException` ante cualquier fallo de transporte o al
///   agotarse [timeout].
/// - Si el cuerpo supera [maxBytes], lanza `ArtworkInvalidDataException`.
abstract interface class ArtworkHttpClient {
  Future<ArtworkHttpResponse> get(
    Uri uri, {
    required Duration timeout,
    required int maxBytes,
  });
}
