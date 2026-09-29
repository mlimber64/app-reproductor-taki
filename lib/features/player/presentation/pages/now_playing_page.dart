import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/artwork/artwork_cache.dart';
import '../../../../core/artwork/artwork_providers.dart';
import '../../../../core/domain/entities/song.dart';
import '../../../../core/theme/taki_colors.dart';
import '../../../../core/theme/taki_icon_size.dart';
import '../../../../core/theme/taki_motion.dart';
import '../../../../core/theme/taki_spacing.dart';
import '../../../../core/theme/taki_typography.dart';
import '../../../../core/utils/duration_format.dart';
import '../../../../core/widgets/taki_artwork.dart';
import '../../../../core/widgets/taki_button.dart';
import '../../../../core/widgets/taki_icon_button.dart';
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
      const SizedBox(height: TakiSpacing.lg),
    ];

    if (constraints.maxHeight < _minHeightWithoutScroll) {
      return SingleChildScrollView(
        child: Column(
          children: [
            _TopBar(onClose: onClose),
            const SizedBox(height: TakiSpacing.lg),
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
        const SizedBox(height: TakiSpacing.lg),
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
        const SizedBox(height: TakiSpacing.sm),
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

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose});

  static const double _height = 56;

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
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
                  // Origen fijo (I14): pendiente de conocer el real.
                  'Biblioteca',
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

/// Carátula grande (§11): `TakiArtwork` hero, con la misma fuente que el
/// resto de la app (bytes de [ArtworkCache]).
class _Artwork extends ConsumerStatefulWidget {
  const _Artwork({required this.albumId, required this.size});

  final int? albumId;
  final double size;

  @override
  ConsumerState<_Artwork> createState() => _ArtworkState();
}

class _ArtworkState extends ConsumerState<_Artwork> {
  ArtworkKey? _key;
  Uint8List? _bytes;

  /// Tamaño entero: evita pedir la carátula de nuevo por fracciones de píxel.
  double get _side => math.max(0.0, widget.size.floorToDouble());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(_Artwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.albumId != widget.albumId || oldWidget.size != widget.size) {
      _resolve();
    }
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
      size: (_side * MediaQuery.devicePixelRatioOf(context)).round(),
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
    return TakiArtwork(
      size: _side,
      hero: true,
      // Los bytes son la clave del MemoryImage: tras un reescaneo llegan
      // bytes nuevos y la imagen se actualiza.
      image: bytes == null || bytes.isEmpty ? null : MemoryImage(bytes),
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
    final isFavorite = ref.watch(isFavoriteProvider(song.id));

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

/// Barra de progreso arrastrable. Durante el arrastre muestra la posición del
/// dedo; el seek se hace solo al soltar.
///
/// §11: pista de 4 px (`divider` → `primary`), pulgar de 16 en `textPrimary`
/// que crece a 20 al arrastrar; tiempos en `caption` tabular.
class _SeekBar extends ConsumerStatefulWidget {
  const _SeekBar();

  @override
  ConsumerState<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends ConsumerState<_SeekBar> {
  static const double _trackHeight = 4;
  static const double _thumbRadius = 8;
  static const double _draggingThumbRadius = 10;

  /// Alto de la zona arrastrable (área táctil, §19).
  static const double _touchHeight = 48;

  double? _dragMs;

  Future<void> _commit(double valueMs) async {
    setState(() => _dragMs = valueMs);
    await ref.read(seekProvider).call(Duration(milliseconds: valueMs.round()));
    if (mounted) setState(() => _dragMs = null);
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

    final maxMs = math.max(duration.inMilliseconds, 1).toDouble();
    final valueMs = (_dragMs ?? position.inMilliseconds.toDouble()).clamp(
      0.0,
      maxMs,
    );
    final labelStyle = TakiTypography.caption.copyWith(
      color: TakiColors.textSecondary,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _touchHeight,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: _trackHeight,
              activeTrackColor: TakiColors.primary,
              inactiveTrackColor: TakiColors.divider,
              thumbColor: TakiColors.textPrimary,
              overlayColor: TakiColors.pressedOverlay,
              trackShape: const RoundedRectSliderTrackShape(),
              thumbShape: RoundSliderThumbShape(
                enabledThumbRadius: _dragMs == null
                    ? _thumbRadius
                    : _draggingThumbRadius,
                elevation: 0,
                pressedElevation: 0,
              ),
              overlayShape: const RoundSliderOverlayShape(
                overlayRadius: _touchHeight / 2,
              ),
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

/// Controles de transporte (§11): aleatorio · anterior · play/pausa ·
/// siguiente · repetir. Aleatorio y repetir activos cambian de icono (`_on`)
/// además de color.
class _Controls extends ConsumerWidget {
  const _Controls();

  static String _repeatValue(RepeatMode mode) => switch (mode) {
    RepeatMode.off => 'desactivado',
    RepeatMode.all => 'todas',
    RepeatMode.one => 'una',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state =
        ref.watch(playbackStateProvider).valueOrNull ?? PlaybackState.empty;
    final repeat = state.repeatMode;

    return SizedBox(
      height: _PlayPauseButton.size,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TakiIconButton(
            icon: Icons.shuffle_rounded,
            selectedIcon: Icons.shuffle_on_rounded,
            semanticLabel: 'Aleatorio',
            selected: state.shuffleEnabled,
            variant: TakiIconButtonVariant.subtle,
            onPressed: () => ref.read(toggleShuffleProvider).call(),
          ),
          TakiIconButton(
            icon: Icons.skip_previous_rounded,
            semanticLabel: 'Anterior',
            iconSize: TakiIconSize.xl,
            onPressed: () => ref.read(skipPreviousProvider).call(),
          ),
          _PlayPauseButton(
            isPlaying: state.isPlaying,
            isBuffering: state.isBuffering,
            onPressed: () => ref.read(togglePlayPauseProvider).call(),
          ),
          TakiIconButton(
            icon: Icons.skip_next_rounded,
            semanticLabel: 'Siguiente',
            iconSize: TakiIconSize.xl,
            onPressed: () => ref.read(skipNextProvider).call(),
          ),
          TakiIconButton(
            icon: Icons.repeat_rounded,
            selectedIcon: repeat == RepeatMode.one
                ? Icons.repeat_one_on_rounded
                : Icons.repeat_on_rounded,
            // El modo va en la etiqueta: TakiIconButton no tiene valor
            // semántico propio.
            semanticLabel: 'Repetir, ${_repeatValue(repeat)}',
            tooltip: 'Repetir',
            selected: repeat != RepeatMode.off,
            variant: TakiIconButtonVariant.subtle,
            onPressed: () => ref.read(cycleRepeatModeProvider).call(),
          ),
        ],
      ),
    );
  }
}

/// Play/pausa de Reproduciendo (§11): círculo de 72 en `primary`, icono de 40
/// en `onPrimary`, `primaryPressed` al pulsar y spinner mientras carga.
///
/// Queda fuera de `TakiIconButton` (su contenedor mide 40 y no es naranja):
/// es el hueco que cubrirá `TakiPlaybackControls`.
class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.isPlaying,
    required this.isBuffering,
    required this.onPressed,
  });

  static const double size = 72;
  static const double _spinnerStroke = 3;

  final bool isPlaying;
  final bool isBuffering;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final iconSize = TakiIconSize.hero.value;

    return IconButton(
      tooltip: isPlaying ? 'Pausar' : 'Reproducir',
      onPressed: onPressed,
      style: ButtonStyle(
        fixedSize: const WidgetStatePropertyAll(Size.square(size)),
        minimumSize: const WidgetStatePropertyAll(Size.square(size)),
        shape: const WidgetStatePropertyAll(CircleBorder()),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.pressed)
              ? TakiColors.primaryPressed
              : TakiColors.primary,
        ),
        foregroundColor: const WidgetStatePropertyAll(TakiColors.onPrimary),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      iconSize: iconSize,
      icon: AnimatedSwitcher(
        duration: TakiMotion.short,
        switchInCurve: TakiMotion.change,
        switchOutCurve: TakiMotion.change,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        ),
        child: isBuffering
            ? SizedBox.square(
                key: const ValueKey('buffering'),
                dimension: iconSize,
                child: const CircularProgressIndicator(
                  strokeWidth: _spinnerStroke,
                  color: TakiColors.onPrimary,
                ),
              )
            : Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                key: ValueKey(isPlaying),
              ),
      ),
    );
  }
}
