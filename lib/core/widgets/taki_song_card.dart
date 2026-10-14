import 'package:flutter/material.dart';

import '../domain/entities/song.dart';
import '../theme/taki_colors.dart';
import '../theme/taki_icon_size.dart';
import '../theme/taki_radius.dart';
import '../theme/taki_spacing.dart';
import '../theme/taki_typography.dart';
import 'taki_artwork.dart';
import 'taki_interaction.dart';
import 'taki_playing_indicator.dart';

/// A song as a cover card: a square artwork with the title and the artist
/// underneath, for grids of recommended or popular music.
///
/// - The card is as wide as its parent; [artworkSize] is the side of the
///   square cover and must match that width so the text lines up with it.
/// - [playback] marks the song that is playing (indicator over the cover) and
///   is announced to screen readers.
/// - Tap plays, long press opens the song actions.
/// - The whole card is a single semantics node: `title, artist`.
class TakiSongCard extends StatelessWidget {
  const TakiSongCard({
    super.key,
    required this.song,
    required this.artworkSize,
    this.artwork,
    this.playback = TakiNowPlaying.none,
    this.onTap,
    this.onLongPress,
  });

  /// Gap between the cover and the title.
  static const double _coverGap = TakiSpacing.sm;

  final Song song;
  final double artworkSize;

  /// Cover image; `null` paints the placeholder.
  final ImageProvider? artwork;
  final TakiNowPlaying playback;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Height of everything under the cover for the current text scale, so a
  /// grid can reserve a fixed extent per card.
  static double textBlockHeight(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final title = TakiTypography.trackTitle;
    final subtitle = TakiTypography.trackSubtitle;
    return _coverGap +
        scaler.scale(title.fontSize! * title.height!) +
        scaler.scale(subtitle.fontSize! * subtitle.height!);
  }

  String get _semanticLabel {
    final artist = song.artist;
    final base = artist == null || artist.isEmpty
        ? song.title
        : '${song.title}, $artist';
    return switch (playback) {
      TakiNowPlaying.none => base,
      TakiNowPlaying.playing => '$base, reproduciendo',
      TakiNowPlaying.paused => '$base, en pausa',
    };
  }

  @override
  Widget build(BuildContext context) {
    final artist = song.artist;
    final radius = TakiRadius.forArtwork(artworkSize);

    return Semantics(
      container: true,
      button: onTap != null,
      label: _semanticLabel,
      onTap: onTap,
      onLongPress: onLongPress,
      child: ExcludeSemantics(
        child: TakiPressable(
          onPressed: onTap,
          onLongPress: onLongPress,
          builder: (context, states) {
            final pressed = states.contains(WidgetState.pressed);
            return Opacity(
              opacity: pressed ? 0.8 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TakiFocusRing(
                    visible: states.contains(WidgetState.focused),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(radius),
                    ),
                    child: SizedBox(
                      width: artworkSize,
                      height: artworkSize,
                      child: Stack(
                        children: [
                          TakiArtwork(size: artworkSize, image: artwork),
                          if (playback != TakiNowPlaying.none)
                            Positioned(
                              left: TakiSpacing.sm,
                              bottom: TakiSpacing.sm,
                              child: DecoratedBox(
                                decoration: const ShapeDecoration(
                                  color: TakiColors.surfaceElevated,
                                  shape: StadiumBorder(),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(TakiSpacing.xs),
                                  child: TakiPlayingIndicator(
                                    animate: playback == TakiNowPlaying.playing,
                                    size: TakiIconSize.xs,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: _coverGap),
                  SizedBox(
                    width: artworkSize,
                    child: Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TakiTypography.trackTitle.copyWith(
                        color: playback == TakiNowPlaying.none
                            ? TakiColors.textPrimary
                            : TakiColors.primary,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: artworkSize,
                    child: Text(
                      artist == null || artist.isEmpty
                          ? 'Artista desconocido'
                          : artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TakiTypography.trackSubtitle.copyWith(
                        color: TakiColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
