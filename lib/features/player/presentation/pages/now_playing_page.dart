import 'dart:math' as math;

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/song.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/duration_format.dart';
import '../../../../core/widgets/artwork_image.dart';
import '../../../library/presentation/providers/favorites_providers.dart';
import '../../domain/entities/playback_state.dart';
import '../providers/player_providers.dart';

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
      backgroundColor: AppColors.background,
      body: GestureDetector(
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd: _onDragEnd,
        child: ValueListenableBuilder<double>(
          valueListenable: _dragOffset,
          builder: (context, offset, child) => Transform.translate(
            offset: Offset(0, offset),
            child: child,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
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
    final bottom = [
      const SizedBox(height: 24),
      _SongInfo(song: song, maxTitleLines: 2),
      const SizedBox(height: 16),
      const _SeekBar(),
      const SizedBox(height: 8),
      const _Controls(),
      const SizedBox(height: 16),
      _BottomActions(onOpenQueue: onOpenQueue),
      const SizedBox(height: 16),
    ];

    if (constraints.maxHeight < _minHeightWithoutScroll) {
      return SingleChildScrollView(
        child: Column(
          children: [
            _TopBar(onClose: onClose),
            const SizedBox(height: 16),
            _Artwork(
              albumId: song.albumId,
              size: math.min(constraints.maxWidth, _scrollArtworkSize),
            ),
            ...bottom,
          ],
        ),
      );
    }

    return Column(
      children: [
        _TopBar(onClose: onClose),
        const SizedBox(height: 16),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => Center(
              child: _Artwork(
                albumId: song.albumId,
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
        _TopBar(onClose: onClose),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: LayoutBuilder(
                  builder: (context, box) => Center(
                    child: _Artwork(
                      albumId: song.albumId,
                      size: math.min(box.maxWidth, box.maxHeight),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                flex: 3,
                child: LayoutBuilder(
                  builder: (context, box) {
                    final details = Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _SongInfo(song: song, maxTitleLines: 1),
                        const SizedBox(height: 8),
                        const _SeekBar(),
                        const _Controls(),
                        const SizedBox(height: 8),
                        _BottomActions(onOpenQueue: onOpenQueue),
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
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Fila inferior de accesos. Por ahora solo "Cola".
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
          child: TextButton.icon(
            onPressed: onOpenQueue,
            icon: const Icon(Icons.queue_music_rounded, size: 20),
            label: const Text('Cola'),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.textPrimary,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: const StadiumBorder(),
              // Área táctil de 48 aunque la píldora mida 44.
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      height: 56,
      child: Row(
        children: [
          _CircleButton(
            icon: Icons.keyboard_arrow_down_rounded,
            tooltip: 'Cerrar',
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
                  style: textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Biblioteca',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          _CircleButton(
            icon: Icons.more_horiz_rounded,
            tooltip: 'Más opciones',
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.surfaceElevated,
        foregroundColor: AppColors.textPrimary,
        fixedSize: const Size.square(44),
        minimumSize: const Size.square(44),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.albumId, required this.size});

  static const double _radius = 24;

  final int? albumId;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Tamaño entero: evita pedir la carátula de nuevo por fracciones de píxel.
    final side = math.max(0.0, size.floorToDouble());

    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(_radius)),
        boxShadow: [
          BoxShadow(
            color: AppColors.artworkShadow,
            blurRadius: 32,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ArtworkImage(albumId: albumId, size: side, borderRadius: _radius),
    );
  }
}

class _SongInfo extends StatelessWidget {
  const _SongInfo({required this.song, required this.maxTitleLines});

  final Song song;
  final int maxTitleLines;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

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
                style: textTheme.headlineSmall?.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                song.artist ?? 'Artista desconocido',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyLarge?.copyWith(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
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
    final isFavorite = ref.watch(isFavoriteProvider(song.id));
    final label = isFavorite ? 'Quitar de favoritos' : 'Añadir a favoritos';

    return Semantics(
      toggled: isFavorite,
      child: IconButton(
        tooltip: label,
        onPressed: () => _toggle(context, ref),
        iconSize: 28,
        style: IconButton.styleFrom(minimumSize: const Size.square(48)),
        icon: Icon(
          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: isFavorite
              ? Theme.of(context).colorScheme.primary
              : AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// Barra de progreso arrastrable. Durante el arrastre muestra la posición del
/// dedo; el seek se hace solo al soltar.
class _SeekBar extends ConsumerStatefulWidget {
  const _SeekBar();

  @override
  ConsumerState<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends ConsumerState<_SeekBar> {
  static const double _thumbRadius = 8;

  double? _dragMs;

  Future<void> _commit(double valueMs) async {
    setState(() => _dragMs = valueMs);
    await ref.read(seekProvider).call(Duration(milliseconds: valueMs.round()));
    if (mounted) setState(() => _dragMs = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final duration = ref.watch(
          playbackStateProvider.select((state) => state.valueOrNull?.duration),
        ) ??
        ref.watch(
          currentSongProvider.select((song) => song.valueOrNull?.duration),
        ) ??
        Duration.zero;

    final maxMs = math.max(duration.inMilliseconds, 1).toDouble();
    final valueMs =
        (_dragMs ?? position.inMilliseconds.toDouble()).clamp(0.0, maxMs);
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: 12,
      color: AppColors.textSecondary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 48,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: accent,
              inactiveTrackColor: AppColors.seekTrack,
              thumbColor: AppColors.textPrimary,
              overlayColor: accent.withValues(alpha: 0.12),
              trackShape: const RoundedRectSliderTrackShape(),
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: _thumbRadius,
                elevation: 0,
                pressedElevation: 0,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
              padding: const EdgeInsets.symmetric(horizontal: _thumbRadius),
            ),
            child: Slider(
              value: valueMs,
              max: maxMs,
              semanticFormatterCallback: (value) =>
                  formatTrackDuration(Duration(milliseconds: value.round())),
              onChangeStart: (value) => setState(() => _dragMs = value),
              onChanged: (value) => setState(() => _dragMs = value),
              onChangeEnd: _commit,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _thumbRadius),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatTrackDuration(Duration(milliseconds: valueMs.round())),
                style: labelStyle,
              ),
              Text(formatTrackDuration(duration), style: labelStyle),
            ],
          ),
        ),
      ],
    );
  }
}

class _Controls extends ConsumerWidget {
  const _Controls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state =
        ref.watch(playbackStateProvider).valueOrNull ?? PlaybackState.empty;
    final accent = Theme.of(context).colorScheme.primary;

    Color toggleColor(bool active) =>
        active ? accent : AppColors.textSecondary;

    return SizedBox(
      height: 76,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Semantics(
            toggled: state.shuffleEnabled,
            child: _ControlButton(
              size: 44,
              icon: Icons.shuffle_rounded,
              color: toggleColor(state.shuffleEnabled),
              tooltip: 'Aleatorio',
              onPressed: () => ref.read(toggleShuffleProvider).call(),
            ),
          ),
          _ControlButton(
            size: 56,
            icon: Icons.skip_previous_rounded,
            color: AppColors.textPrimary,
            tooltip: 'Anterior',
            onPressed: () => ref.read(skipPreviousProvider).call(),
          ),
          _PlayPauseButton(
            isPlaying: state.isPlaying,
            isBuffering: state.isBuffering,
            onPressed: () => ref.read(togglePlayPauseProvider).call(),
          ),
          _ControlButton(
            size: 56,
            icon: Icons.skip_next_rounded,
            color: AppColors.textPrimary,
            tooltip: 'Siguiente',
            onPressed: () => ref.read(skipNextProvider).call(),
          ),
          Semantics(
            value: switch (state.repeatMode) {
              RepeatMode.off => 'desactivado',
              RepeatMode.all => 'todas',
              RepeatMode.one => 'una',
            },
            child: _ControlButton(
              size: 44,
              icon: state.repeatMode == RepeatMode.one
                  ? Icons.repeat_one_rounded
                  : Icons.repeat_rounded,
              color: toggleColor(state.repeatMode != RepeatMode.off),
              tooltip: 'Repetir',
              onPressed: () => ref.read(cycleRepeatModeProvider).call(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.size,
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  final double size;
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: size * 0.6,
      icon: Icon(icon, color: color),
      style: IconButton.styleFrom(
        fixedSize: Size.square(size),
        minimumSize: Size.square(size),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.isPlaying,
    required this.isBuffering,
    required this.onPressed,
  });

  static const double _size = 76;

  final bool isPlaying;
  final bool isBuffering;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return IconButton(
      tooltip: isPlaying ? 'Pausar' : 'Reproducir',
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: AppColors.onAccent,
        fixedSize: const Size.square(_size),
        minimumSize: const Size.square(_size),
      ),
      iconSize: 40,
      icon: isBuffering
          ? const SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.onAccent,
              ),
            )
          : Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
    );
  }
}
