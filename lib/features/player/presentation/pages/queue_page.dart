import 'dart:typed_data';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/artwork/artwork_cache.dart';
import '../../../../core/artwork/artwork_providers.dart';
import '../../../../core/domain/entities/song.dart';
import '../../../../core/theme/taki_colors.dart';
import '../../../../core/theme/taki_elevation.dart';
import '../../../../core/theme/taki_icon_size.dart';
import '../../../../core/theme/taki_radius.dart';
import '../../../../core/theme/taki_spacing.dart';
import '../../../../core/theme/taki_typography.dart';
import '../../../../core/utils/duration_format.dart';
import '../../../../core/widgets/taki_button.dart';
import '../../../../core/widgets/taki_icon_button.dart';
import '../../../../core/widgets/taki_interaction.dart';
import '../../../../core/widgets/taki_section_header.dart';
import '../../../../core/widgets/taki_song_tile.dart';
import '../../domain/entities/playback_state.dart';
import '../providers/player_providers.dart';

/// Cola de reproducción: la canción actual y lo que viene, en el orden real
/// de reproducción (con aleatorio, el orden mezclado).
///
/// La lista "A continuación" empieza en `upcomingStart` de la cola real: la
/// fila `i` es el índice `upcomingStart + i` del port.
class QueuePage extends ConsumerStatefulWidget {
  const QueuePage({super.key});

  @override
  ConsumerState<QueuePage> createState() => _QueuePageState();
}

class _QueuePageState extends ConsumerState<QueuePage> {
  List<Song>? _keyedQueue;
  List<Key> _keys = const [];

  /// Claves estables aunque una canción esté repetida en la cola: id +
  /// número de aparición. Se recalculan solo cuando cambia la cola.
  List<Key> _keysFor(List<Song> queue) {
    if (identical(queue, _keyedQueue)) return _keys;
    final seen = <int, int>{};
    _keys = [
      for (final song in queue)
        ValueKey((song.id, seen[song.id] = (seen[song.id] ?? 0) + 1)),
    ];
    _keyedQueue = queue;
    return _keys;
  }

  void _close() => Navigator.of(context).maybePop();

  Future<void> _remove(PlaybackState state, int index) async {
    final song = state.queue[index];
    await ref.read(removeFromQueueProvider).call(index);
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Quitada de la cola'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () => _undoRemove(song, index),
        ),
      ),
    );
  }

  /// Vuelve a insertar [song] en [index] (o lo más cerca posible si la cola
  /// cambió mientras tanto): se añade al final y se mueve a su sitio.
  Future<void> _undoRemove(Song song, int index) async {
    await ref.read(addToQueueProvider).call([song]);
    final state = ref.read(audioPlayerPortProvider).state;
    final last = state.queue.length - 1;
    final target = index.clamp(state.upcomingStart, last);
    await ref.read(moveInQueueProvider).call(last, target);
  }

  Future<void> _confirmClear(int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Limpiar la cola?'),
        content: Text(
          count == 1
              ? 'Se quitará la canción que viene a continuación. '
                  'La actual seguirá sonando.'
              : 'Se quitarán las $count canciones que vienen a continuación. '
                  'La actual seguirá sonando.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await ref.read(clearUpcomingProvider).call();
  }

  @override
  Widget build(BuildContext context) {
    // Solo cola, canción actual y reproducción: no reconstruir con la posición.
    final (queue, currentIndex, isPlaying) = ref.watch(
      playbackStateProvider.select((value) {
        final state = value.valueOrNull ?? PlaybackState.empty;
        return (state.queue, state.currentIndex, state.isPlaying);
      }),
    );
    final state = PlaybackState(
      queue: queue,
      currentIndex: currentIndex,
      isPlaying: isPlaying,
    );
    final current = state.currentSong;
    final start = state.upcomingStart;
    final upcomingCount = state.upcomingCount;
    final keys = _keysFor(queue);

    // Sin margen de página: las filas (TakiSongTile) y las cabeceras
    // (TakiSectionHeader) ya llevan los 16 laterales (§3).
    return Scaffold(
      backgroundColor: TakiColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TopBar(
              onClose: _close,
              onClear: upcomingCount == 0
                  ? null
                  : () => _confirmClear(upcomingCount),
            ),
            const TakiSectionHeader(
              title: 'Sonando ahora',
              variant: TakiSectionHeaderVariant.group,
              isFirst: true,
            ),
            if (current != null)
              _NowPlayingCard(song: current, isPlaying: isPlaying)
            else
              const _EmptyMessage('No está sonando nada'),
            _UpcomingHeader(
              summary: upcomingCount > 0 ? _summary(queue.sublist(start)) : null,
            ),
            Expanded(
              child: upcomingCount == 0
                  ? const _EmptyMessage('No hay más canciones en la cola')
                  : ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      // Alto medido con una fila real: crece con el tamaño
                      // de texto (TakiSongTile, §8) y mantiene la lista
                      // perezosa con miles de canciones.
                      prototypeItem: _QueueRow.prototype(queue[start]),
                      itemCount: upcomingCount,
                      onReorder: (oldIndex, newIndex) {
                        // Flutter da el destino antes de quitar el elemento.
                        final target =
                            newIndex > oldIndex ? newIndex - 1 : newIndex;
                        ref
                            .read(moveInQueueProvider)
                            .call(start + oldIndex, start + target);
                      },
                      // La fila arrastrada flota (nivel 2, §5), sin sombra.
                      proxyDecorator: (child, index, animation) => Material(
                        color: TakiElevation.floating.surface,
                        borderRadius: TakiRadius.mdAll,
                        clipBehavior: Clip.antiAlias,
                        child: child,
                      ),
                      itemBuilder: (context, i) {
                        final index = start + i;
                        return _QueueRow(
                          key: keys[index],
                          song: queue[index],
                          listIndex: i,
                          onTap: () =>
                              ref.read(skipToQueueItemProvider).call(index),
                          onRemove: () => _remove(state, index),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static String _summary(List<Song> songs) {
    final total = songs.fold(Duration.zero, (sum, song) => sum + song.duration);
    final count = songs.length == 1 ? '1 canción' : '${songs.length} canciones';
    return '$count · ${formatTotalDuration(total)}';
  }
}

/// Barra superior (misma altura y botón de cierre que Reproduciendo):
/// cerrar · "Cola" · Limpiar.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose, required this.onClear});

  static const double _height = 56;

  final VoidCallback onClose;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    // 12 + el margen interno del botón (4) = el círculo en la línea de 16 de
    // las filas.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TakiSpacing.md),
      child: SizedBox(
        height: _height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Cola',
                style: TakiTypography.titleLarge.copyWith(
                  color: TakiColors.textPrimary,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TakiIconButton(
                icon: Icons.keyboard_arrow_down_rounded,
                semanticLabel: 'Cerrar',
                variant: TakiIconButtonVariant.tonal,
                onPressed: onClose,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TakiButton(
                label: 'Limpiar',
                variant: TakiButtonVariant.tertiary,
                onPressed: onClear,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "A CONTINUACIÓN" con el resumen (número de canciones y duración) a la
/// derecha, en la línea base del título. `TakiSectionHeader` no tiene
/// metadata en la variante grupo: se compone al lado.
class _UpcomingHeader extends StatelessWidget {
  const _UpcomingHeader({required this.summary});

  final String? summary;

  @override
  Widget build(BuildContext context) {
    final summary = this.summary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        const Expanded(
          child: TakiSectionHeader(
            title: 'A continuación',
            variant: TakiSectionHeaderVariant.group,
          ),
        ),
        if (summary != null)
          Padding(
            padding: const EdgeInsets.only(right: TakiSpacing.pageGutter),
            child: Text(
              summary,
              style: TakiTypography.caption.copyWith(
                color: TakiColors.textMuted,
              ),
            ),
          ),
      ],
    );
  }
}

/// La canción actual (§4: fila actual de la Cola, radio `md`): una
/// `TakiSongTile` en estado sonando/en pausa sobre una zona agrupada
/// (nivel 1, §5).
class _NowPlayingCard extends StatelessWidget {
  const _NowPlayingCard({required this.song, required this.isPlaying});

  final Song song;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TakiSpacing.sm),
      child: ClipRRect(
        borderRadius: TakiRadius.mdAll,
        child: ColoredBox(
          color: TakiElevation.raised.surface,
          child: _SongArtwork(
            albumId: song.albumId,
            builder: (artwork) => TakiSongTile(
              song: song,
              artwork: artwork,
              showDuration: false,
              playback:
                  isPlaying ? TakiNowPlaying.playing : TakiNowPlaying.paused,
            ),
          ),
        ),
      ),
    );
  }
}

/// Fila de "A continuación": `TakiSongTile` con quitar y el asa de arrastre.
class _QueueRow extends StatelessWidget {
  const _QueueRow({
    super.key,
    required this.song,
    required this.listIndex,
    required this.onTap,
    required this.onRemove,
  }) : _isPrototype = false;

  /// Fila de referencia para medir el alto (no se muestra ni reacciona).
  const _QueueRow.prototype(this.song)
      : listIndex = 0,
        onTap = null,
        onRemove = null,
        _isPrototype = true;

  static const String removeLabel = 'Quitar de la cola';
  static const String reorderLabel = 'Arrastrar para reordenar';

  final Song song;

  /// Posición dentro de "A continuación" (la que usa ReorderableListView).
  final int listIndex;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final bool _isPrototype;

  @override
  Widget build(BuildContext context) {
    final trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TakiIconButton(
          icon: Icons.close_rounded,
          semanticLabel: removeLabel,
          variant: TakiIconButtonVariant.subtle,
          onPressed: onRemove,
        ),
        ReorderableDragStartListener(
          index: listIndex,
          enabled: !_isPrototype,
          child: Tooltip(
            message: reorderLabel,
            child: SizedBox.square(
              dimension: TakiInteraction.minTouchTarget,
              child: Icon(
                Icons.drag_handle_rounded,
                size: TakiIconSize.md.value,
                color: TakiColors.iconSecondary,
              ),
            ),
          ),
        ),
      ],
    );

    if (_isPrototype) {
      return TakiSongTile(song: song, showDuration: false, trailing: trailing);
    }

    return _SongArtwork(
      albumId: song.albumId,
      builder: (artwork) => TakiSongTile(
        song: song,
        artwork: artwork,
        showDuration: false,
        onTap: onTap,
        trailing: trailing,
      ),
    );
  }
}

/// Resuelve la carátula de una fila con [ArtworkCache] (bytes →
/// `MemoryImage`), la misma fuente que Reproduciendo y el resto de la app.
class _SongArtwork extends ConsumerStatefulWidget {
  const _SongArtwork({required this.albumId, required this.builder});

  final int? albumId;
  final Widget Function(ImageProvider? artwork) builder;

  @override
  ConsumerState<_SongArtwork> createState() => _SongArtworkState();
}

class _SongArtworkState extends ConsumerState<_SongArtwork> {
  ArtworkKey? _key;
  Uint8List? _bytes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(_SongArtwork oldWidget) {
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
      size: (TakiSongTile.artworkSize * MediaQuery.devicePixelRatioOf(context))
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

/// Mensaje en línea cuando una parte de la cola está vacía.
class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TakiSpacing.pageGutter,
        vertical: TakiSpacing.xl,
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TakiTypography.body.copyWith(color: TakiColors.textSecondary),
      ),
    );
  }
}
