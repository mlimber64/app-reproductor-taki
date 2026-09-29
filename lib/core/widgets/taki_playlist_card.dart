import 'package:flutter/material.dart';

import '../theme/taki_colors.dart';
import '../theme/taki_icon_size.dart';
import '../theme/taki_motion.dart';
import '../theme/taki_radius.dart';
import '../theme/taki_spacing.dart';
import '../theme/taki_typography.dart';
import 'taki_artwork.dart';
import 'taki_interaction.dart';
import 'taki_playing_indicator.dart';

export 'taki_playing_indicator.dart' show TakiNowPlaying;

/// Playlist (u otra colección de canciones) en una fila
/// (docs/DESIGN_SYSTEM.md §12). Solo presentación: recibe los datos y
/// callbacks, sirve igual para playlists locales y futuras online.
///
/// - Portada: [TakiArtwork.mosaic] con [artwork]; lista vacía = colección
///   vacía (placeholder con borde).
/// - Metadata: "12 canciones · [subtitle]"; "Vacía" si [songCount] es 0.
/// - Pulsada: capa sobre la fila y carátula a 0.98. Seleccionada: anillo
///   `primary` alrededor de la carátula y marca. Sonando: indicador de barras
///   en la esquina de la carátula.
class TakiPlaylistCard extends StatelessWidget {
  const TakiPlaylistCard({
    super.key,
    required this.title,
    this.artwork = const [],
    this.songCount,
    this.subtitle,
    this.onTap,
    this.onLongPress,
    this.showChevron = true,
    this.selected = false,
    this.nowPlaying = TakiNowPlaying.none,
  });

  final String title;

  /// Carátulas de las primeras canciones, ya elegidas (p. ej. álbumes
  /// distintos). Ver [TakiArtwork.mosaic].
  final List<ImageProvider?> artwork;
  final int? songCount;

  /// Resto de la metadata, tras el número de canciones (duración, origen).
  final String? subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Chevron al final cuando la fila navega; sin él en una elección (sheet).
  final bool showChevron;
  final bool selected;
  final TakiNowPlaying nowPlaying;

  /// Alto mínimo de la fila (§12).
  static const double minHeight = 72;

  /// Lado de la portada (`artworkCard`, §7.3).
  static const double artworkSize = 56;

  static const String emptyLabel = 'Vacía';
  static const String playingLabel = 'Reproduciendo';
  static const String pausedLabel = 'En pausa';

  static String songCountLabel(int count) => switch (count) {
        0 => emptyLabel,
        1 => '1 canción',
        _ => '$count canciones',
      };

  String? get _metadata {
    final parts = [
      if (songCount case final count?) songCountLabel(count),
      ?subtitle,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final metadata = _metadata;

    return Semantics(
      container: true,
      button: onTap != null,
      selected: selected,
      label: [title, ?metadata].join(', '),
      value: switch (nowPlaying) {
        TakiNowPlaying.playing => playingLabel,
        TakiNowPlaying.paused => pausedLabel,
        TakiNowPlaying.none => null,
      },
      child: TakiPressable(
        onPressed: onTap,
        onLongPress: onLongPress,
        builder: (context, states) {
          final pressed = states.contains(WidgetState.pressed);

          return TakiFocusRing(
            visible: states.contains(WidgetState.focused),
            shape: const RoundedRectangleBorder(),
            inset: true,
            child: Container(
              constraints: const BoxConstraints(minHeight: minHeight),
              padding: const EdgeInsets.symmetric(
                horizontal: TakiSpacing.lg,
                vertical: TakiSpacing.sm,
              ),
              foregroundDecoration: BoxDecoration(
                color: pressed ? TakiColors.pressedOverlay : null,
              ),
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    AnimatedScale(
                      scale: pressed ? TakiMotion.pressedScale : 1,
                      duration: TakiMotion.instant,
                      curve: TakiMotion.change,
                      child: _cover(),
                    ),
                    const SizedBox(width: TakiSpacing.md),
                    Expanded(child: _texts(metadata)),
                    if (showChevron && onTap != null)
                      Icon(
                        Icons.chevron_right_rounded,
                        size: TakiIconSize.md.value,
                        color: TakiColors.iconSecondary,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _cover() {
    final cover = TakiArtwork.mosaic(size: artworkSize, images: artwork);

    return TakiFocusRing(
      // El anillo de seleccionada reutiliza la forma y medidas del de foco.
      visible: selected,
      shape: const RoundedRectangleBorder(borderRadius: TakiRadius.smAll),
      color: TakiColors.primary,
      child: Stack(
        children: [
          cover,
          if (selected)
            Positioned(
              top: TakiSpacing.xs,
              right: TakiSpacing.xs,
              child: DecoratedBox(
                decoration: const ShapeDecoration(
                  shape: CircleBorder(),
                  color: TakiColors.background,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: TakiIconSize.sm.value,
                  color: TakiColors.primary,
                ),
              ),
            ),
          if (nowPlaying.isCurrent)
            Positioned(
              right: TakiSpacing.xs,
              bottom: TakiSpacing.xs,
              child: Container(
                padding: const EdgeInsets.all(TakiSpacing.xs),
                decoration: ShapeDecoration(
                  shape: const StadiumBorder(),
                  color: TakiColors.artworkScrim,
                ),
                child: TakiPlayingIndicator(
                  animate: nowPlaying == TakiNowPlaying.playing,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _texts(String? metadata) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TakiTypography.trackTitle.copyWith(
            color: nowPlaying.isCurrent
                ? TakiColors.active
                : TakiColors.textPrimary,
          ),
        ),
        if (metadata != null) ...[
          const SizedBox(height: TakiSpacing.xxs),
          Text(
            metadata,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TakiTypography.trackSubtitle
                .copyWith(color: TakiColors.textSecondary),
          ),
        ],
      ],
    );
  }
}
