import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../library/presentation/widgets/artwork_image.dart';

/// Portada de playlist: mosaico 2×2 si sus primeras canciones tienen 4
/// carátulas distintas; si no, la carátula de la primera. Sin canciones, un
/// ícono de lista sobre surface.
class PlaylistCover extends StatelessWidget {
  const PlaylistCover({
    super.key,
    required this.albumIds,
    required this.isEmpty,
    this.size = 52,
    this.borderRadius = 10,
  });

  /// Álbumes de las primeras canciones, en orden (pueden repetirse o faltar).
  final List<int?> albumIds;
  final bool isEmpty;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    if (isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(
          Icons.queue_music_rounded,
          size: size * 0.45,
          color: AppColors.textSecondary,
        ),
      );
    }

    final distinct = <int>{for (final id in albumIds) ?id}.toList();

    if (distinct.length < 4) {
      return ArtworkImage(
        albumId: distinct.firstOrNull,
        size: size,
        borderRadius: borderRadius,
      );
    }

    final tile = (size / 2).floorToDouble();
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox.square(
        dimension: tile * 2,
        child: Wrap(
          children: [
            for (final albumId in distinct.take(4))
              ArtworkImage(albumId: albumId, size: tile, borderRadius: 0),
          ],
        ),
      ),
    );
  }
}
