import 'package:flutter/material.dart';

import '../domain/entities/song.dart';
import '../theme/taki_colors.dart';
import '../theme/taki_radius.dart';
import '../theme/taki_spacing.dart';
import '../theme/taki_typography.dart';
import 'taki_artwork.dart';
import 'taki_icon_button.dart';
import 'taki_interaction.dart';

/// Reproductor compacto de Taki (docs/DESIGN_SYSTEM.md §10). Solo
/// presentación: recibe la canción, el estado y callbacks; no conoce el motor
/// de audio ni ningún provider.
///
/// - Alto 64, fondo `surfaceElevated`, radio `radiusLg`, sin borde ni sombra.
///   Los márgenes respecto a la pantalla y a la navegación los pone quien lo
///   coloca.
/// - Play/pausa **blanco** (círculo `textPrimary`), no naranja: el mini player
///   está en todas las pantallas y no debe competir con su acción principal.
///   El naranja es el [progress].
/// - Favorito solo si se pasa [onToggleFavorite]; siguiente solo si se pasa
///   [onNext] y el ancho es ≥ 400.
/// - Tocar o deslizar hacia arriba llama a [onOpen].
class TakiMiniPlayer extends StatelessWidget {
  const TakiMiniPlayer({
    super.key,
    required this.song,
    required this.isPlaying,
    required this.onPlayPause,
    required this.onOpen,
    this.artwork,
    this.progress = 0,
    this.onNext,
    this.isFavorite = false,
    this.onToggleFavorite,
  });

  final Song song;
  final ImageProvider? artwork;
  final bool isPlaying;
  final VoidCallback? onPlayPause;
  final VoidCallback? onOpen;

  /// Fracción reproducida, de 0 a 1.
  final double progress;
  final VoidCallback? onNext;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  /// Alto del mini player (§10).
  static const double height = 64;

  /// Lado de la carátula (`artworkRow`, §7.3).
  static const double artworkSize = 48;

  /// Grosor de la barra de progreso (§10).
  static const double progressHeight = 2;

  /// Ancho a partir del cual cabe el botón "siguiente" (§10).
  static const double nextButtonMinWidth = 400;

  /// Velocidad (px/s) del deslizamiento hacia arriba que abre Reproduciendo.
  static const double openFlingVelocity = 300;

  static const String unknownArtist = 'Artista desconocido';
  static const String openHint = 'Abrir Reproduciendo';
  static const String playingLabel = 'Reproduciendo';
  static const String pausedLabel = 'En pausa';
  static const String playLabel = 'Reproducir';
  static const String pauseLabel = 'Pausar';
  static const String nextLabel = 'Siguiente';
  static const String favoriteLabel = 'Favorita';

  String get _artist => song.artist ?? unknownArtist;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: onOpen != null,
      label: '${song.title}, $_artist',
      value: isPlaying ? playingLabel : pausedLabel,
      onTapHint: openHint,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showNext =
              onNext != null && constraints.maxWidth >= nextButtonMinWidth;

          return GestureDetector(
            onVerticalDragEnd: onOpen == null
                ? null
                : (details) {
                    if ((details.primaryVelocity ?? 0) < -openFlingVelocity) {
                      onOpen!();
                    }
                  },
            child: TakiPressable(
              onPressed: onOpen,
              builder: (context, states) => TakiFocusRing(
                visible: states.contains(WidgetState.focused),
                shape: const RoundedRectangleBorder(
                  borderRadius: TakiRadius.lgAll,
                ),
                child: ClipRRect(
                  borderRadius: TakiRadius.lgAll,
                  child: Container(
                    height: height,
                    color: TakiColors.surfaceElevated,
                    foregroundDecoration: BoxDecoration(
                      color: states.contains(WidgetState.pressed)
                          ? TakiColors.pressedOverlay
                          : null,
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            left: TakiSpacing.sm,
                            right: TakiSpacing.xs,
                          ),
                          child: Row(
                            children: [
                              TakiArtwork(size: artworkSize, image: artwork),
                              const SizedBox(width: TakiSpacing.md),
                              Expanded(child: _texts()),
                              if (onToggleFavorite case final toggle?)
                                TakiIconButton(
                                  icon: Icons.favorite_border_rounded,
                                  selectedIcon: Icons.favorite_rounded,
                                  semanticLabel: favoriteLabel,
                                  selected: isFavorite,
                                  variant: TakiIconButtonVariant.subtle,
                                  onPressed: toggle,
                                ),
                              if (showNext)
                                TakiIconButton(
                                  icon: Icons.skip_next_rounded,
                                  semanticLabel: nextLabel,
                                  onPressed: onNext,
                                ),
                              TakiIconButton(
                                icon: isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                semanticLabel: isPlaying
                                    ? pauseLabel
                                    : playLabel,
                                variant: TakiIconButtonVariant.inverse,
                                onPressed: onPlayPause,
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _ProgressBar(progress: progress),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _texts() {
    return ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TakiTypography.trackTitle.copyWith(
              color: TakiColors.textPrimary,
            ),
          ),
          const SizedBox(height: TakiSpacing.xxs),
          Text(
            _artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TakiTypography.trackSubtitle.copyWith(
              color: TakiColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: TakiMiniPlayer.progressHeight,
        child: ColoredBox(
          color: TakiColors.divider,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              heightFactor: 1,
              child: const ColoredBox(color: TakiColors.primary),
            ),
          ),
        ),
      ),
    );
  }
}
