import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Botones "Reproducir" (acento) y "Aleatorio" (surface), en píldora de 48.
/// Los usan Favoritos y el detalle de playlist.
class PlayShuffleButtons extends StatelessWidget {
  const PlayShuffleButtons({
    super.key,
    required this.onPlay,
    required this.onShuffle,
  });

  final VoidCallback? onPlay;
  final VoidCallback? onShuffle;

  @override
  Widget build(BuildContext context) {
    const pill = StadiumBorder();

    return Row(
      children: [
        FilledButton.icon(
          onPressed: onPlay,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Reproducir'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 22),
            shape: pill,
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: onShuffle,
          icon: const Icon(Icons.shuffle_rounded),
          label: const Text('Aleatorio'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 22),
            shape: pill,
            side: const BorderSide(color: AppColors.border),
          ),
        ),
      ],
    );
  }
}
