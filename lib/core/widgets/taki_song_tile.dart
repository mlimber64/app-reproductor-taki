import 'package:flutter/material.dart';

import '../domain/entities/song.dart';
import '../theme/taki_colors.dart';
import '../theme/taki_icon_size.dart';
import '../theme/taki_radius.dart';
import '../theme/taki_spacing.dart';
import '../theme/taki_typography.dart';
import '../utils/duration_format.dart';
import 'taki_artwork.dart';
import 'taki_icon_button.dart';
import 'taki_interaction.dart';
import 'taki_playing_indicator.dart';

export 'taki_playing_indicator.dart' show TakiNowPlaying;


/// Fila de una canción (docs/DESIGN_SYSTEM.md §8). Solo presentación: recibe
/// la canción, su carátula y callbacks; no reproduce ni guarda nada.
///
/// Jerarquía: título → artista (· álbum) → duración. Título y artista van en
/// una línea con elipsis; el álbum va detrás del artista, así que es lo
/// primero que se recorta. Alto mínimo 64, crece con el tamaño de texto.
///
/// Estados, cada uno con una señal además del color:
/// - [playback] sonando/en pausa: título en `primary` e indicador de barras
///   sobre la carátula; se anuncia "Reproduciendo" o "En pausa".
/// - [isFavorite]: corazón relleno delante del subtítulo; "Favorita".
/// - [selected]: fondo `primaryContainer` y marca en lugar de la carátula.
/// - [available] `false`: contenido al 38 % y subtítulo "No disponible"; se
///   puede pulsar (para explicar por qué).
class TakiSongTile extends StatelessWidget {
  const TakiSongTile({
    super.key,
    required this.song,
    this.artwork,
    this.onTap,
    this.onLongPress,
    this.onMore,
    this.showAlbum = false,
    this.showDuration = true,
    this.playback = TakiNowPlaying.none,
    this.isFavorite = false,
    this.selected = false,
    this.available = true,
    this.trailing,
  });

  final Song song;

  /// Carátula (p. ej. `AlbumArtworkImage`); sin ella, placeholder.
  final ImageProvider? artwork;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Muestra el botón ⋯ (48 táctil) y abre el menú de acciones.
  final VoidCallback? onMore;
  final bool showAlbum;
  final bool showDuration;
  final TakiNowPlaying playback;
  final bool isFavorite;
  final bool selected;
  final bool available;

  /// Control extra al final, p. ej. el asa de arrastre de una lista
  /// reordenable.
  final Widget? trailing;

  /// Alto mínimo de la fila (§8).
  static const double minHeight = 64;

  /// Lado de la carátula (`artworkRow`, §7.3).
  static const double artworkSize = 48;

  static const String unknownArtist = 'Artista desconocido';
  static const String unavailableLabel = 'No disponible';
  static const String playingLabel = 'Reproduciendo';
  static const String pausedLabel = 'En pausa';
  static const String favoriteLabel = 'Favorita';
  static const String moreLabel = 'Más opciones';

  bool get _isCurrent => playback.isCurrent;

  String get _artist => song.artist ?? unknownArtist;

  String get _subtitle {
    if (!available) return unavailableLabel;
    final album = song.album;
    return showAlbum && album != null ? '$_artist · $album' : _artist;
  }

  String get _semanticLabel => [
        song.title,
        _artist,
        if (showAlbum && song.album != null) song.album!,
        if (showDuration) formatTrackDuration(song.duration),
      ].join(', ');

  String? get _semanticValue {
    final states = [
      if (playback == TakiNowPlaying.playing) playingLabel,
      if (playback == TakiNowPlaying.paused) pausedLabel,
      if (isFavorite) favoriteLabel,
      if (!available) unavailableLabel,
    ];
    return states.isEmpty ? null : states.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final hasTrailingAction = onMore != null || trailing != null;

    return Semantics(
      container: true,
      button: onTap != null,
      selected: selected,
      label: _semanticLabel,
      value: _semanticValue,
      child: TakiPressable(
        onPressed: onTap,
        onLongPress: onLongPress,
        builder: (context, states) => TakiFocusRing(
          visible: states.contains(WidgetState.focused),
          shape: const RoundedRectangleBorder(),
          inset: true,
          child: Container(
            constraints: const BoxConstraints(minHeight: minHeight),
            padding: EdgeInsets.only(
              left: TakiSpacing.lg,
              right: hasTrailingAction ? TakiSpacing.xs : TakiSpacing.lg,
              top: TakiSpacing.sm,
              bottom: TakiSpacing.sm,
            ),
            color: selected ? TakiColors.selected : null,
            foregroundDecoration: BoxDecoration(
              color: states.contains(WidgetState.pressed)
                  ? TakiColors.pressedOverlay
                  : null,
            ),
            child: Row(
              children: [
                Opacity(
                  opacity: available ? 1 : TakiColors.disabledContentOpacity,
                  child: _leading(),
                ),
                const SizedBox(width: TakiSpacing.md),
                Expanded(
                  child: Opacity(
                    opacity: available ? 1 : TakiColors.disabledContentOpacity,
                    child: ExcludeSemantics(child: _texts()),
                  ),
                ),
                if (showDuration) ...[
                  const SizedBox(width: TakiSpacing.md),
                  ExcludeSemantics(
                    child: Text(
                      formatTrackDuration(song.duration),
                      style: TakiTypography.caption
                          .copyWith(color: TakiColors.textMuted),
                    ),
                  ),
                ],
                if (onMore case final onMore?) ...[
                  const SizedBox(width: TakiSpacing.xs),
                  TakiIconButton(
                    icon: Icons.more_horiz_rounded,
                    semanticLabel: moreLabel,
                    variant: TakiIconButtonVariant.subtle,
                    onPressed: onMore,
                  ),
                ],
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _leading() {
    if (selected) {
      return SizedBox.square(
        dimension: artworkSize,
        child: Icon(
          Icons.check_circle_rounded,
          size: TakiIconSize.md.value,
          color: TakiColors.primary,
        ),
      );
    }

    final art = TakiArtwork(size: artworkSize, image: artwork);
    if (!_isCurrent) return art;

    return Stack(
      alignment: Alignment.center,
      children: [
        art,
        SizedBox.square(
          dimension: artworkSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: TakiColors.artworkScrim,
              borderRadius: BorderRadius.all(
                Radius.circular(TakiRadius.forArtwork(artworkSize)),
              ),
            ),
          ),
        ),
        TakiPlayingIndicator(animate: playback == TakiNowPlaying.playing),
      ],
    );
  }

  Widget _texts() {
    final subtitleStyle =
        TakiTypography.trackSubtitle.copyWith(color: TakiColors.textSecondary);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TakiTypography.trackTitle.copyWith(
            color: _isCurrent ? TakiColors.active : TakiColors.textPrimary,
          ),
        ),
        const SizedBox(height: TakiSpacing.xxs),
        Row(
          children: [
            if (isFavorite && available) ...[
              Icon(
                Icons.favorite_rounded,
                size: TakiIconSize.xs.value,
                color: TakiColors.primary,
              ),
              const SizedBox(width: TakiSpacing.xs),
            ],
            Expanded(
              child: Text(
                _subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: subtitleStyle,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
