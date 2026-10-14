import 'dart:typed_data';

import '../entities/artwork_reference.dart';

/// Carga la imagen a la que apunta una [RemoteArtworkReference].
///
/// This is only the contract; `HttpRemoteArtworkLoader` is the HTTP adapter. It
/// is injected into `ArtworkCache`; without one, remote references are treated
/// as missing artwork.
///
/// Contrato: devuelve la imagen codificada (JPEG/PNG) de lado aproximado
/// [size] px, o `null` si no hay imagen. Los errores del transporte pueden
/// lanzarse; `ArtworkCache` los trata como carátula ausente.
abstract interface class RemoteArtworkLoader {
  Future<Uint8List?> load(RemoteArtworkReference reference, {required int size});
}
