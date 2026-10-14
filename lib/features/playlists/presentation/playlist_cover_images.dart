import 'package:flutter/widgets.dart';

import '../../../core/artwork/album_artwork_builder.dart';
import '../../../core/domain/entities/artwork_reference.dart';
import '../../../core/widgets/taki_artwork.dart';

/// Imágenes de la portada de una playlist, como las espera `TakiArtwork.mosaic`
/// (y `TakiPlaylistCard.artwork`).
///
/// [artwork] es la selección de `playlistCoverArtwork`; [size] es el lado
/// **lógico de la portada completa**. `TakiArtwork.mosaic` dibuja el 2×2 solo
/// con 4 imágenes; con menos muestra la primera a lado completo. Por eso:
/// - **4 carátulas:** [AlbumArtworkMosaicBuilder]; cada tesela se pide a la
///   mitad del lado (la de 2×2 se ve a esa mitad).
/// - **Menos:** solo se pide la primera carátula y a lado completo (con
///   [AlbumArtworkMosaicBuilder] saldría a la mitad y se estiraría). `[]` (sin
///   canciones) no pide nada y `[Unavailable]` (sin carátulas) es una pieza
///   vacía.
///
/// Solo resuelve imágenes: no decide qué carátulas forman la portada ni la
/// dibuja, y no sabe si son locales o remotas.
class PlaylistCoverImages extends StatelessWidget {
  const PlaylistCoverImages({
    super.key,
    required this.artwork,
    required this.size,
    required this.builder,
  });

  final List<ArtworkReference> artwork;
  final double size;
  final Widget Function(List<ImageProvider?> images) builder;

  @override
  Widget build(BuildContext context) {
    if (artwork.length >= TakiArtwork.mosaicCount) {
      return AlbumArtworkMosaicBuilder(
        references: artwork,
        size: size,
        builder: (_, images) => builder(images),
      );
    }
    if (artwork.isEmpty) return builder(const []);

    return AlbumArtworkBuilder.reference(
      reference: artwork.first,
      size: size,
      builder: (_, image) => builder([image]),
    );
  }
}
