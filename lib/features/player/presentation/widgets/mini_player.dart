import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/artwork_image.dart';
import '../providers/player_providers.dart';

/// Reproductor compacto sobre la barra inferior. Sin canción actual no ocupa
/// espacio. Tocarlo o deslizarlo hacia arriba llama a [onOpen] (abre
/// Reproduciendo).
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key, required this.onOpen});

  static const double height = 64;
  static const double _openVelocity = 300;

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(currentSongProvider).valueOrNull;
    if (song == null) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) < -_openVelocity) onOpen();
        },
        child: Semantics(
          button: true,
          label: 'Abrir Reproduciendo',
          child: Material(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onOpen,
              child: SizedBox(
                height: height,
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 10, right: 4),
                      child: Row(
                        children: [
                          ArtworkImage(albumId: song.albumId, size: 44),
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
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  song.artist ?? 'Artista desconocido',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodySmall?.copyWith(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const _PlayPauseButton(),
                        ],
                      ),
                    ),
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _MiniProgressBar(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayPauseButton extends ConsumerWidget {
  const _PlayPauseButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(
      playbackStateProvider.select((state) => state.valueOrNull?.isPlaying),
    );
    final playing = isPlaying ?? false;

    return IconButton(
      tooltip: playing ? 'Pausar' : 'Reproducir',
      onPressed: () => ref.read(togglePlayPauseProvider).call(),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.textPrimary,
        foregroundColor: AppColors.onTextPrimary,
        fixedSize: const Size.square(44),
        minimumSize: const Size.square(44),
        // Área táctil de 48 aunque el círculo mida 44.
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
    );
  }
}

/// Única parte del mini player que escucha la posición (se redibuja sola).
class _MiniProgressBar extends ConsumerWidget {
  const _MiniProgressBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final duration = ref.watch(
          playbackStateProvider.select((state) => state.valueOrNull?.duration),
        ) ??
        ref.watch(
          currentSongProvider.select((song) => song.valueOrNull?.duration),
        );

    final total = duration?.inMilliseconds ?? 0;
    final fraction =
        total > 0 ? (position.inMilliseconds / total).clamp(0.0, 1.0) : 0.0;

    return SizedBox(
      height: 3,
      child: ColoredBox(
        color: AppColors.miniProgressTrack,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: fraction,
            heightFactor: 1,
            child: ColoredBox(color: Theme.of(context).colorScheme.primary),
          ),
        ),
      ),
    );
  }
}
