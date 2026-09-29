import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/duration_format.dart';
import '../../../library/domain/entities/song.dart';
import '../../../library/presentation/widgets/artwork_image.dart';
import '../../domain/entities/playback_state.dart';
import '../providers/player_providers.dart';
import '../widgets/playing_bars.dart';

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
  static const double _rowHeight = 64;

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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(
                onClose: _close,
                onClear: upcomingCount == 0
                    ? null
                    : () => _confirmClear(upcomingCount),
              ),
              const SizedBox(height: 8),
              const _SectionLabel('SONANDO AHORA'),
              const SizedBox(height: 8),
              if (current != null)
                _NowPlayingCard(song: current, isPlaying: isPlaying)
              else
                const _EmptyMessage('No está sonando nada'),
              const SizedBox(height: 24),
              Row(
                children: [
                  const _SectionLabel('A CONTINUACIÓN'),
                  const Spacer(),
                  if (upcomingCount > 0)
                    Text(
                      _summary(queue.sublist(start)),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: upcomingCount == 0
                    ? const _EmptyMessage('No hay más canciones en la cola')
                    : ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        itemExtent: _rowHeight,
                        itemCount: upcomingCount,
                        onReorder: (oldIndex, newIndex) {
                          // Flutter da el destino antes de quitar el elemento.
                          final target =
                              newIndex > oldIndex ? newIndex - 1 : newIndex;
                          ref
                              .read(moveInQueueProvider)
                              .call(start + oldIndex, start + target);
                        },
                        proxyDecorator: (child, index, animation) => Material(
                          color: AppColors.surfaceElevated,
                          elevation: 6,
                          borderRadius: BorderRadius.circular(12),
                          child: child,
                        ),
                        itemBuilder: (context, i) {
                          final index = start + i;
                          return _QueueRow(
                            key: keys[index],
                            song: queue[index],
                            listIndex: i,
                            onTap: () => ref
                                .read(skipToQueueItemProvider)
                                .call(index),
                            onRemove: () => _remove(state, index),
                          );
                        },
                      ),
              ),
            ],
          ),
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

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose, required this.onClear});

  final VoidCallback onClose;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'Cola',
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'Cerrar',
              onPressed: onClose,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceElevated,
                foregroundColor: AppColors.textPrimary,
                fixedSize: const Size.square(44),
                minimumSize: const Size.square(44),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onClear,
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                minimumSize: const Size(64, 48),
              ),
              child: const Text('Limpiar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 12,
            letterSpacing: 1.2,
            color: AppColors.textSecondary,
          ),
    );
  }
}

class _NowPlayingCard extends StatelessWidget {
  const _NowPlayingCard({required this.song, required this.isPlaying});

  final Song song;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          ArtworkImage(albumId: song.albumId),
          const SizedBox(width: 12),
          Expanded(
            child: _TitleAndArtist(
              song: song,
              titleColor: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          PlayingBars(animate: isPlaying),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    super.key,
    required this.song,
    required this.listIndex,
    required this.onTap,
    required this.onRemove,
  });

  final Song song;

  /// Posición dentro de "A continuación" (la que usa ReorderableListView).
  final int listIndex;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            ArtworkImage(albumId: song.albumId, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: _TitleAndArtist(
                song: song,
                titleColor: AppColors.textPrimary,
              ),
            ),
            IconButton(
              tooltip: 'Quitar de la cola',
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
              color: AppColors.textSecondary,
              style: IconButton.styleFrom(minimumSize: const Size.square(48)),
            ),
            ReorderableDragStartListener(
              index: listIndex,
              child: const Tooltip(
                message: 'Arrastrar para reordenar',
                child: SizedBox.square(
                  dimension: 48,
                  child: Icon(
                    Icons.drag_handle_rounded,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleAndArtist extends StatelessWidget {
  const _TitleAndArtist({required this.song, required this.titleColor});

  final Song song;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyLarge?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          song.artist ?? 'Artista desconocido',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium?.copyWith(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
      ),
    );
  }
}
