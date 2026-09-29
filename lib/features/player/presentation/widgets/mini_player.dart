import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/artwork/artwork_cache.dart';
import '../../../../core/artwork/artwork_providers.dart';
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
      child: _MiniArtwork(
        albumId: song.albumId,
        builder: (artwork) => Consumer(
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

/// Resuelve la carátula con [ArtworkCache] (bytes → `MemoryImage`), la misma
/// fuente que usaba el mini player y que usan Reproduciendo y la Cola.
class _MiniArtwork extends ConsumerStatefulWidget {
  const _MiniArtwork({required this.albumId, required this.builder});

  final int? albumId;
  final Widget Function(ImageProvider? artwork) builder;

  @override
  ConsumerState<_MiniArtwork> createState() => _MiniArtworkState();
}

class _MiniArtworkState extends ConsumerState<_MiniArtwork> {
  ArtworkKey? _key;
  Uint8List? _bytes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(_MiniArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.albumId != widget.albumId) _resolve();
  }

  void _resolve() {
    final albumId = widget.albumId;
    if (albumId == null) {
      _key = null;
      _bytes = null;
      return;
    }

    final key = (
      albumId: albumId,
      size:
          (TakiMiniPlayer.artworkSize * MediaQuery.devicePixelRatioOf(context))
              .round(),
    );
    if (key == _key) return;
    _key = key;

    final cache = ref.read(artworkCacheProvider);
    if (cache.contains(key)) {
      _bytes = cache.peek(key);
      return;
    }

    _bytes = null;
    cache.load(key).then((bytes) {
      if (mounted && _key == key) setState(() => _bytes = bytes);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    // Los bytes son la clave del MemoryImage: tras un reescaneo llegan bytes
    // nuevos y la imagen se actualiza.
    return widget.builder(
      bytes == null || bytes.isEmpty ? null : MemoryImage(bytes),
    );
  }
}
