import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/widgets/play_shuffle_buttons.dart';
import '../../../../app/widgets/song_actions_sheet.dart';
import '../../../../core/utils/duration_format.dart';
import '../../../../core/widgets/message_view.dart';
import '../../../library/presentation/providers/songs_notifier.dart';
import '../../../library/presentation/widgets/song_tile.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/playlist_entry.dart';
import '../providers/playlists_providers.dart';
import '../widgets/delete_playlist_dialog.dart';
import '../widgets/playlist_cover.dart';
import '../widgets/playlist_name_dialog.dart';

/// Detalle de una playlist: encabezado, Reproducir/Aleatorio y sus canciones
/// reordenables.
///
/// La lista muestra solo las canciones que están en la biblioteca; al mover o
/// quitar se traduce a las posiciones reales de la playlist.
class PlaylistDetailPage extends ConsumerStatefulWidget {
  const PlaylistDetailPage({super.key, required this.playlistId});

  final int playlistId;

  @override
  ConsumerState<PlaylistDetailPage> createState() =>
      _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends ConsumerState<PlaylistDetailPage> {
  /// Lista con el último cambio del usuario aplicado, mientras la base lo
  /// guarda y se recalcula (evita que la fila "salte" al soltarla).
  List<PlaylistItem>? _optimistic;
  bool _wasFound = false;
  bool _closing = false;

  int get _id => widget.playlistId;

  void _close() {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).maybePop();
  }

  Future<void> _play(List<PlaylistItem> items, int index) async {
    await ref
        .read(playSongsProvider)
        .call([for (final item in items) item.song], index);
    unawaited(ref.read(notificationPermissionProvider).requestIfNeeded());
  }

  Future<void> _playShuffled(List<PlaylistItem> items) async {
    await ref
        .read(playSongsShuffledProvider)
        .call([for (final item in items) item.song]);
    unawaited(ref.read(notificationPermissionProvider).requestIfNeeded());
  }

  void _reorder(List<PlaylistItem> items, int oldIndex, int newIndex) {
    // Flutter da el destino antes de quitar el elemento.
    final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (target == oldIndex) return;

    final from = items[oldIndex].entry.position;
    final to = items[target].entry.position;
    final reordered = List.of(items);
    reordered.insert(target, reordered.removeAt(oldIndex));
    setState(() => _optimistic = reordered);
    ref.read(movePlaylistSongProvider).call(_id, from, to);
  }

  Future<void> _remove(List<PlaylistItem> items, PlaylistItem item) async {
    setState(() => _optimistic = List.of(items)..remove(item));
    final remove = ref.read(removeFromPlaylistProvider);
    await remove(item.entry);
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Quitada de la playlist'),
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () => remove.undo(item.entry),
          ),
        ),
      );
  }

  Future<void> _rename(Playlist playlist) async {
    final name = await showPlaylistNameDialog(
      context,
      title: 'Renombrar playlist',
      confirmLabel: 'Guardar',
      initialName: playlist.name,
    );
    if (name != null) {
      await ref.read(renamePlaylistProvider).call(playlist.id, name);
    }
  }

  Future<void> _delete(Playlist playlist) async {
    if (!await confirmDeletePlaylist(context, playlist.name)) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    _closing = true;
    await ref.read(deletePlaylistProvider).call(playlist.id);
    if (mounted) Navigator.of(context).maybePop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Playlist eliminada')));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(playlistItemsProvider(_id), (_, next) {
      if (next.hasValue && _optimistic != null) {
        setState(() => _optimistic = null);
      }
    });

    final playlistValue = ref.watch(playlistProvider(_id));
    final playlist = playlistValue.valueOrNull;
    if (playlist != null) _wasFound = true;
    if (playlistValue.hasValue && playlist == null && _wasFound) {
      // Se borró desde otro lugar: volver a la lista.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _close();
      });
    }

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (playlist != null)
            PopupMenuButton<_HeaderAction>(
              tooltip: 'Opciones de la playlist',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (action) => switch (action) {
                _HeaderAction.rename => _rename(playlist),
                _HeaderAction.delete => _delete(playlist),
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _HeaderAction.rename,
                  child: Text('Renombrar'),
                ),
                PopupMenuItem(
                  value: _HeaderAction.delete,
                  child: Text('Eliminar playlist'),
                ),
              ],
            ),
        ],
      ),
      body: _body(playlistValue, playlist),
    );
  }

  Widget _body(AsyncValue<Playlist?> playlistValue, Playlist? playlist) {
    if (playlistValue.hasError) return _error();
    if (playlist == null) {
      return playlistValue.hasValue
          ? const MessageView(
              icon: Icons.playlist_remove_rounded,
              title: 'Esta playlist ya no existe',
              message: 'Puede que se haya eliminado.',
            )
          : const Center(child: CircularProgressIndicator());
    }

    final library = ref.watch(songsProvider).valueOrNull;
    if (library is LibraryNeedsPermission) {
      return MessageView(
        icon: Icons.lock_outline_rounded,
        title: 'Taki necesita acceso a tu música',
        message: 'Las playlists se muestran a partir de las canciones de tu '
            'teléfono.',
        actionLabel:
            library.permanentlyDenied ? 'Abrir ajustes' : 'Permitir acceso',
        onAction: ref.read(songsProvider.notifier).requestPermission,
      );
    }

    return ref.watch(playlistItemsProvider(_id)).when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _error(),
          data: (items) => RefreshIndicator(
            onRefresh: ref.read(songsProvider.notifier).rescan,
            child: _SongList(
              playlist: playlist,
              items: _optimistic ?? items,
              onPlay: _play,
              onShuffle: _playShuffled,
              onReorder: _reorder,
              onRemove: _remove,
            ),
          ),
        );
  }

  Widget _error() => MessageView(
        icon: Icons.error_outline_rounded,
        title: 'Playlist no disponible',
        message: 'No pudimos leer esta playlist.',
        actionLabel: 'Reintentar',
        onAction: () => retryPlaylists(ref),
      );
}

enum _HeaderAction { rename, delete }

class _SongList extends ConsumerWidget {
  const _SongList({
    required this.playlist,
    required this.items,
    required this.onPlay,
    required this.onShuffle,
    required this.onReorder,
    required this.onRemove,
  });

  final Playlist playlist;
  final List<PlaylistItem> items;
  final void Function(List<PlaylistItem> items, int index) onPlay;
  final void Function(List<PlaylistItem> items) onShuffle;
  final void Function(List<PlaylistItem> items, int oldIndex, int newIndex)
      onReorder;
  final void Function(List<PlaylistItem> items, PlaylistItem item) onRemove;

  void _showActions(BuildContext context, WidgetRef ref, PlaylistItem item) {
    showSongActions(
      context,
      ref,
      item.song,
      extraActions: [
        ExtraSongAction(
          icon: Icons.remove_circle_outline_rounded,
          label: 'Quitar de la playlist',
          onSelected: () async => onRemove(items, item),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSongId = ref.watch(
      currentSongProvider.select((song) => song.valueOrNull?.id),
    );

    return ReorderableListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemExtent: SongTile.height,
      header: _Header(
        playlist: playlist,
        items: items,
        onPlay: items.isEmpty ? null : () => onPlay(items, 0),
        onShuffle: items.isEmpty ? null : () => onShuffle(items),
      ),
      footer: items.isEmpty
          ? const _EmptyPlaylist()
          : const SizedBox(height: 16),
      itemCount: items.length,
      onReorder: (oldIndex, newIndex) => onReorder(items, oldIndex, newIndex),
      proxyDecorator: (child, index, animation) => Material(
        color: AppColors.surfaceElevated,
        elevation: 6,
        child: child,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return SongTile(
          key: ValueKey(item.entry.id),
          song: item.song,
          isCurrent: item.song.id == currentSongId,
          onTap: () => onPlay(items, index),
          onLongPress: () => _showActions(context, ref, item),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Más opciones',
                onPressed: () => _showActions(context, ref, item),
                icon: const Icon(Icons.more_horiz_rounded),
                color: AppColors.textSecondary,
                style: IconButton.styleFrom(
                  minimumSize: const Size.square(48),
                ),
              ),
              ReorderableDragStartListener(
                index: index,
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
        );
      },
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.playlist,
    required this.items,
    required this.onPlay,
    required this.onShuffle,
  });

  final Playlist playlist;
  final List<PlaylistItem> items;
  final VoidCallback? onPlay;
  final VoidCallback? onShuffle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final total = items.fold(
      Duration.zero,
      (sum, item) => sum + item.song.duration,
    );

    return Container(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PlaylistCover(
                albumIds: [for (final item in items.take(4)) item.song.albumId],
                isEmpty: items.isEmpty,
                size: 128,
                borderRadius: 18,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PLAYLIST',
                      style: textTheme.labelSmall?.copyWith(
                        fontSize: 11,
                        letterSpacing: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      playlist.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.headlineSmall?.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatSongsSummary(items.length, total),
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PlayShuffleButtons(onPlay: onPlay, onShuffle: onShuffle),
        ],
      ),
    );
  }
}

class _EmptyPlaylist extends StatelessWidget {
  const _EmptyPlaylist();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
      child: Text(
        'Esta playlist está vacía. Añade canciones desde la Biblioteca.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
      ),
    );
  }
}
