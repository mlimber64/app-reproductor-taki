import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/artwork/album_artwork_builder.dart';
import '../../../../core/theme/taki_spacing.dart';
import '../../../../core/widgets/taki_mini_player.dart';
import '../providers/player_providers.dart';

/// Conecta [TakiMiniPlayer] con el reproductor. Sin canción actual no ocupa
/// espacio. Tocarlo o deslizarlo hacia arriba llama a [onOpen] (abre
/// Reproduciendo).
///
/// Solo play/pausa, como antes: sin "siguiente" ni favorito.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key, required this.onOpen});

  static const double height = TakiMiniPlayer.height;

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(currentSongProvider).valueOrNull;
    if (song == null) return const SizedBox.shrink();

    final isPlaying = ref.watch(
          playbackStateProvider.select((state) => state.valueOrNull?.isPlaying),
        ) ??
        false;

    // §10: 8 a los lados y 8 hasta la navegación.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TakiSpacing.sm,
        0,
        TakiSpacing.sm,
        TakiSpacing.sm,
      ),
      child: AlbumArtworkBuilder.reference(
        reference: song.artwork,
        size: TakiMiniPlayer.artworkSize,
        builder: (_, artwork) => Consumer(
          // Solo esta parte escucha la posición.
          builder: (context, ref, _) => TakiMiniPlayer(
            song: song,
            artwork: artwork,
            isPlaying: isPlaying,
            progress: _progress(ref),
            onPlayPause: () => ref.read(togglePlayPauseProvider).call(),
            onOpen: onOpen,
          ),
        ),
      ),
    );
  }

  /// Fracción reproducida (0..1). Sin duración conocida, 0.
  static double _progress(WidgetRef ref) {
    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final duration = ref.watch(
          playbackStateProvider.select((state) => state.valueOrNull?.duration),
        ) ??
        ref.watch(
          currentSongProvider.select((song) => song.valueOrNull?.duration),
        );

    final total = duration?.inMilliseconds ?? 0;
    return total > 0 ? (position.inMilliseconds / total).clamp(0.0, 1.0) : 0.0;
  }
}
