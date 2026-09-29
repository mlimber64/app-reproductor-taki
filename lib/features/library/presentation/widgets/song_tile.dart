import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/duration_format.dart';
import '../../domain/entities/song.dart';
import 'artwork_image.dart';

/// Fila de canción: carátula, título, artista y duración. Alto fijo de 64.
///
/// Con [isCurrent] el título usa el color de acento (canción que suena).
class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.song,
    this.isCurrent = false,
    this.onTap,
    this.onLongPress,
    this.trailing,
  });

  static const double height = 64;

  final Song song;
  final bool isCurrent;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Controles extra a la derecha de la duración (p. ej. menú y asa).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: EdgeInsets.only(left: 16, right: trailing == null ? 16 : 4),
          child: Row(
            children: [
              ArtworkImage(albumId: song.albumId),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyLarge?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isCurrent
                            ? theme.colorScheme.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      song.artist ?? 'Artista desconocido',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                formatTrackDuration(song.duration),
                style: textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (trailing case final trailing?) ...[
                const SizedBox(width: 4),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
