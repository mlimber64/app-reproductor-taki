import 'dart:math' as math;

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/artwork/album_artwork_builder.dart';
import '../../../../core/catalog/catalog_sources_providers.dart';
import '../../../../core/domain/entities/artwork_reference.dart';
import '../../../../core/domain/entities/local_music_identity.dart';
import '../../../../core/domain/entities/song.dart';
import '../../../../core/theme/taki_colors.dart';
import '../../../../core/theme/taki_icon_size.dart';
import '../../../../core/theme/taki_spacing.dart';
import '../../../../core/theme/taki_typography.dart';
import '../../../../core/widgets/taki_artwork.dart';
import '../../../../core/widgets/taki_button.dart';
import '../../../../core/widgets/taki_icon_button.dart';
import '../../../../core/widgets/taki_playback_controls.dart';
import '../../../../core/widgets/taki_progress_bar.dart';
import '../../../library/presentation/providers/favorites_providers.dart';
import '../../domain/entities/playback_state.dart';
import '../providers/player_providers.dart';
import '../widgets/attribution_section.dart';

/// Pantalla completa de la canción que suena.
///
/// Se cierra con la flecha, deslizando hacia abajo, con el botón atrás o sola
/// si deja de haber canción actual.
class NowPlayingPage extends ConsumerStatefulWidget {
  const NowPlayingPage({super.key, required this.onOpenQueue});

  /// Abre la pantalla Cola (la navegación la decide el router).
  final VoidCallback onOpenQueue;

  @override
  ConsumerState<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends ConsumerState<NowPlayingPage> {
  static const double _dismissDistance = 120;
  static const double _dismissVelocity = 700;

  /// Desplazamiento vertical mientras se arrastra hacia abajo para cerrar.
  final ValueNotifier<double> _dragOffset = ValueNotifier(0);
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final song = ref.read(currentSongProvider);
      if (song.hasValue && song.value == null) _close();
    });
  }

  @override
  void dispose() {
    _dragOffset.dispose();
    super.dispose();
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).maybePop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _dragOffset.value = math.max(0, _dragOffset.value + details.delta.dy);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_dragOffset.value > _dismissDistance || velocity > _dismissVelocity) {
      _close();
    } else {
      _dragOffset.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<Song?>>(currentSongProvider, (_, next) {
      if (next.hasValue && next.value == null) _close();
    });
    final song = ref.watch(currentSongProvider).valueOrNull;

    return Scaffold(
      backgroundColor: TakiColors.background,
      body: GestureDetector(
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd: _onDragEnd,
        child: ValueListenableBuilder<double>(
          valueListenable: _dragOffset,
          builder: (context, offset, child) =>
              Transform.translate(offset: Offset(0, offset), child: child),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TakiSpacing.pageGutterImmersive,
              ),
              child: song == null
                  ? const SizedBox.expand()
                  : LayoutBuilder(
                      builder: (context, constraints) =>
                          constraints.maxWidth > constraints.maxHeight
                          ? _LandscapeLayout(
                              song: song,
                              onClose: _close,
                              onOpenQueue: widget.onOpenQueue,
                            )
                          : _PortraitLayout(
                              song: song,
                              onClose: _close,
                              onOpenQueue: widget.onOpenQueue,
                              constraints: constraints,
                            ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PortraitLayout extends StatelessWidget {
  const _PortraitLayout({
    required this.song,
    required this.onClose,
    required this.onOpenQueue,
    required this.constraints,
  });

  /// Por debajo de esta altura la carátula quedaría diminuta: se desplaza.
  static const double _minHeightWithoutScroll = 520;
  static const double _scrollArtworkSize = 240;

  final Song song;
  final VoidCallback onClose;
  final VoidCallback onOpenQueue;
  final BoxConstraints constraints;

  @override
  Widget build(BuildContext context) {
    // §11: 24 entre bloques (carátula, texto, progreso, controles, acciones).
    final bottom = [
      const SizedBox(height: TakiSpacing.xl),
      _SongInfo(song: song, maxTitleLines: 2),
      const SizedBox(height: TakiSpacing.xl),
      const _SeekBar(),
      const SizedBox(height: TakiSpacing.xl),
      const _Controls(),
      const SizedBox(height: TakiSpacing.xl),
      _BottomActions(onOpenQueue: onOpenQueue),
      // Secundaria: no ocupa nada si no hay atribución.
      AttributionSection(song: song),
      const SizedBox(height: TakiSpacing.lg),
    ];

    if (constraints.maxHeight < _minHeightWithoutScroll) {
      return SingleChildScrollView(
        child: Column(
          children: [
            _TopBar(song: song, onClose: onClose),
            const SizedBox(height: TakiSpacing.lg),
            _Artwork(
              artwork: song.artwork,
              size: math.min(constraints.maxWidth, _scrollArtworkSize),
            ),
            ...bottom,
          ],
        ),
      );
    }

    return Column(
      children: [
        _TopBar(song: song, onClose: onClose),
        const SizedBox(height: TakiSpacing.lg),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => Center(
              child: _Artwork(
                artwork: song.artwork,
                size: math.min(box.maxWidth, box.maxHeight),
              ),
            ),
          ),
        ),
        ...bottom,
      ],
    );
  }
}

class _LandscapeLayout extends StatelessWidget {
  const _LandscapeLayout({
    required this.song,
    required this.onClose,
    required this.onOpenQueue,
  });

  final Song song;
  final VoidCallback onClose;
  final VoidCallback onOpenQueue;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopBar(song: song, onClose: onClose),
        const SizedBox(height: TakiSpacing.sm),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: LayoutBuilder(
                  builder: (context, box) => Center(
                    child: _Artwork(
                      artwork: song.artwork,
                      size: math.min(box.maxWidth, box.maxHeight),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: TakiSpacing.xxl),
              Expanded(
                flex: 3,
                child: LayoutBuilder(
                  builder: (context, box) {
                    // En horizontal el alto es escaso: separación dentro de
                    // bloque (8, §11) en lugar de la de 24 entre bloques.
                    final details = Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _SongInfo(song: song, maxTitleLines: 1),
                        const SizedBox(height: TakiSpacing.sm),
                        const _SeekBar(),
                        const _Controls(),
                        const SizedBox(height: TakiSpacing.sm),
                        _BottomActions(onOpenQueue: onOpenQueue),
                        AttributionSection(song: song),
                      ],
                    );
                    return Center(
                      child: SingleChildScrollView(
                        // Solo se desplaza si no cabe (pantallas muy bajas).
                        physics: const ClampingScrollPhysics(),
                        child: details,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: TakiSpacing.sm),
      ],
    );
  }
}

/// Fila inferior de accesos. Por ahora solo "Cola" (§11: botón secundario).
class _BottomActions extends StatelessWidget {
  const _BottomActions({required this.onOpenQueue});

  final VoidCallback onOpenQueue;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Tooltip(
          message: 'Abrir la cola',
          child: TakiButton(
            label: 'Cola',
            icon: Icons.queue_music_rounded,
            variant: TakiButtonVariant.secondary,
            semanticLabel: 'Abrir la cola',
            onPressed: onOpenQueue,
          ),
        ),
      ],
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.song, required this.onClose});

  static const double _height = 56;

  final Song song;
  final VoidCallback onClose;

  /// Display name of the source the song comes from. Local songs never touch
  /// the catalog registry; an unregistered source gets a neutral label.
  static String _originLabel(WidgetRef ref, Song song) {
    final source = song.musicIdentity.source;
    if (source == localMusicSource) return 'Biblioteca';
    for (final provider in ref.watch(catalogSourcesProvider).available) {
      if (provider.source == source) return provider.label;
    }
    return 'En línea';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: _height,
      child: Row(
        children: [
          TakiIconButton(
            icon: Icons.keyboard_arrow_down_rounded,
            semanticLabel: 'Cerrar',
            variant: TakiIconButtonVariant.tonal,
            onPressed: onClose,
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'REPRODUCIENDO DESDE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TakiTypography.eyebrow.copyWith(
                    color: TakiColors.textMuted,
                  ),
                ),
                const SizedBox(height: TakiSpacing.xxs),
                Text(
                  _originLabel(ref, song),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TakiTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: TakiColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          TakiIconButton(
            icon: Icons.more_horiz_rounded,
            semanticLabel: 'Más opciones',
            variant: TakiIconButtonVariant.tonal,
            // Sin acciones todavía (I14); se mantiene el comportamiento.
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

/// Carátula grande (§11): `TakiArtwork` hero. La imagen la resuelve
/// [AlbumArtworkBuilder] (caché de carátulas → `ResizeImage(MemoryImage)`).
class _Artwork extends StatelessWidget {
  const _Artwork({required this.artwork, required this.size});

  final ArtworkReference artwork;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Tamaño entero: evita pedir la carátula de nuevo por fracciones de píxel;
    // el mismo lado se pide y se dibuja.
    final side = math.max(0.0, size.floorToDouble());
    return AlbumArtworkBuilder.reference(
      reference: artwork,
      size: side,
      builder: (_, image) => TakiArtwork(size: side, hero: true, image: image),
    );
  }
}

class _SongInfo extends StatelessWidget {
  const _SongInfo({required this.song, required this.maxTitleLines});

  final Song song;
  final int maxTitleLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.title,
                maxLines: maxTitleLines,
                overflow: TextOverflow.ellipsis,
                style: TakiTypography.headline.copyWith(
                  color: TakiColors.textPrimary,
                ),
              ),
              const SizedBox(height: TakiSpacing.xxs),
              Text(
                song.artist ?? 'Artista desconocido',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TakiTypography.bodyLarge.copyWith(
                  color: TakiColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: TakiSpacing.sm),
        _FavoriteButton(song: song),
      ],
    );
  }
}

/// Corazón de favoritos. Observa solo el estado de esta canción, así que se
/// actualiza si cambia la canción o se marca desde otro lugar.
class _FavoriteButton extends ConsumerWidget {
  const _FavoriteButton({required this.song});

  final Song song;

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(toggleFavoriteProvider).call(song);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Los favoritos no están disponibles')),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(isFavoriteProvider(song.musicIdentity));

    // Marcado: corazón relleno **y** naranja; se anuncia como interruptor.
    return TakiIconButton(
      icon: Icons.favorite_border_rounded,
      selectedIcon: Icons.favorite_rounded,
      semanticLabel: isFavorite ? 'Quitar de favoritos' : 'Añadir a favoritos',
      selected: isFavorite,
      variant: TakiIconButtonVariant.subtle,
      iconSize: TakiIconSize.lg,
      onPressed: () => _toggle(context, ref),
    );
  }
}

/// Conecta [TakiProgressBar] con el reproductor. El seek se hace solo al
/// soltar; hasta que termina, la barra se queda en el punto elegido (no
/// vuelve un instante a la posición anterior).
class _SeekBar extends ConsumerStatefulWidget {
  const _SeekBar();

  @override
  ConsumerState<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends ConsumerState<_SeekBar> {
  /// Destino del seek en curso.
  Duration? _pendingSeek;

  Future<void> _commit(Duration target) async {
    setState(() => _pendingSeek = target);
    await ref.read(seekProvider).call(target);
    if (mounted) setState(() => _pendingSeek = null);
  }

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final duration =
        ref.watch(
          playbackStateProvider.select((state) => state.valueOrNull?.duration),
        ) ??
        ref.watch(
          currentSongProvider.select((song) => song.valueOrNull?.duration),
        ) ??
        Duration.zero;

    return TakiProgressBar(
      position: _pendingSeek ?? position,
      duration: duration,
      onSeek: _commit,
    );
  }
}

/// Traduce el modo de repetición del reproductor al de los controles.
TakiRepeatMode _takiRepeatMode(RepeatMode mode) => switch (mode) {
  RepeatMode.off => TakiRepeatMode.off,
  RepeatMode.all => TakiRepeatMode.all,
  RepeatMode.one => TakiRepeatMode.one,
};

/// Conecta [TakiPlaybackControls] con el estado y las acciones del
/// reproductor.
class _Controls extends ConsumerWidget {
  const _Controls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state =
        ref.watch(playbackStateProvider).valueOrNull ?? PlaybackState.empty;

    return TakiPlaybackControls(
      isPlaying: state.isPlaying,
      isLoading: state.isBuffering,
      isShuffleEnabled: state.shuffleEnabled,
      repeatMode: _takiRepeatMode(state.repeatMode),
      onPlayPause: () => ref.read(togglePlayPauseProvider).call(),
      onPrevious: () => ref.read(skipPreviousProvider).call(),
      onNext: () => ref.read(skipNextProvider).call(),
      onShuffle: () => ref.read(toggleShuffleProvider).call(),
      onRepeat: () => ref.read(cycleRepeatModeProvider).call(),
    );
  }
}
