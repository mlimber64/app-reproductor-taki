import 'dart:typed_data';

import '../entities/artwork_reference.dart';

/// Carga la imagen a la que apunta una [RemoteArtworkReference].
///
/// Es solo el contrato: hoy **no hay ningún adaptador** (ni HTTP). Cuando exista
/// uno, se inyecta en `ArtworkCache`; sin él, las referencias remotas se tratan
/// como carátula ausente.
///
/// Contrato: devuelve la imagen codificada (JPEG/PNG) de lado aproximado
/// [size] px, o `null` si no hay imagen. Los errores del transporte pueden
/// lanzarse; `ArtworkCache` los trata como carátula ausente.
abstract interface class RemoteArtworkLoader {
  Future<Uint8List?> load(RemoteArtworkReference reference, {required int size});
}
