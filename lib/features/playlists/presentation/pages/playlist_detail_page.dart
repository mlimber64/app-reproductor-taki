import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/artwork/album_artwork_builder.dart';
import '../../../../core/domain/entities/song.dart';
import '../../../../core/theme/taki_colors.dart';
import '../../../../core/theme/taki_elevation.dart';
import '../../../../core/theme/taki_icon_size.dart';
import '../../../../core/theme/taki_radius.dart';
import '../../../../core/theme/taki_spacing.dart';
import '../../../../core/theme/taki_typography.dart';
import '../../../../core/utils/duration_format.dart';
import '../../../../core/widgets/song_actions.dart';
import '../../../../core/widgets/taki_artwork.dart';
import '../../../../core/widgets/taki_button.dart';
import '../../../../core/widgets/taki_empty_state.dart';
import '../../../../core/widgets/taki_error_state.dart';
import '../../../../core/widgets/taki_interaction.dart';
import '../../../../core/widgets/taki_song_tile.dart';
import '../../../library/presentation/providers/songs_notifier.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/playlist_entry.dart';
import '../playlist_cover_albums.dart';
import '../playlist_cover_images.dart';
import '../providers/playlists_providers.dart';
import '../widgets/delete_playlist_dialog.dart';
import '../widgets/playlist_name_dialog.dart';

/// Detalle de una playlist: encabezado, Reproducir/Aleatorio y sus canciones
/// reordenables.
///
/// La lista muestra solo las canciones que están en la biblioteca; al mover o
/// quitar se traduce a las posiciones reales de la playlist.
class PlaylistDetailPage extends ConsumerStatefulWidget {
  const PlaylistDetailPage({
    super.key,
    required this.playlistId,
    required this.onSongActions,
  });

  final int playlistId;

  /// Menú de acciones de una canción (pulsación larga o menú "⋯").
  final ShowSongActions onSongActions;

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
      // No es un fallo: la playlist se eliminó. Estado neutro, sin acción.
      return playlistValue.hasValue
          ? const TakiEmptyState(
              icon: Icons.playlist_remove_rounded,
              title: 'Esta playlist ya no existe',
              description: 'Puede que se haya eliminado.',
            )
          : const Center(child: CircularProgressIndicator());
    }

    final library = ref.watch(songsProvider).valueOrNull;

    return ref.watch(playlistItemsProvider(_id)).when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _error(),
          // El permiso de música solo hace falta para la fuente local: las
          // canciones de otras fuentes se muestran igual. Sin permiso y sin
          // nada que mostrar, se pide (como antes).
          data: (items) => items.isEmpty && library is LibraryNeedsPermission
              ? TakiErrorState(
                  kind: TakiErrorStateKind.permission,
                  title: 'Taki necesita acceso a tu música',
                  message: 'Las playlists se muestran a partir de las '
                      'canciones de tu teléfono.',
                  action: TakiStateAction(
                    label: library.permanentlyDenied
                        ? 'Abrir ajustes'
                        : 'Permitir acceso',
                    onPressed:
                        ref.read(songsProvider.notifier).requestPermission,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: ref.read(songsProvider.notifier).rescan,
                  child: _SongList(
                    playlist: playlist,
                    items: _optimistic ?? items,
                    onPlay: _play,
                    onShuffle: _playShuffled,
                    onReorder: _reorder,
                    onRemove: _remove,
                    onSongActions: widget.onSongActions,
                  ),
                ),
        );
  }

  Widget _error() => TakiErrorState(
        title: 'Playlist no disponible',
        message: 'No pudimos leer esta playlist.',
        action: TakiStateAction(
          label: 'Reintentar',
          onPressed: () => retryPlaylists(ref),
        ),
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
    required this.onSongActions,
  });

  final Playlist playlist;
  final List<PlaylistItem> items;
  final ShowSongActions onSongActions;
  final void Function(List<PlaylistItem> items, int index) onPlay;
  final void Function(List<PlaylistItem> items) onShuffle;
  final void Function(List<PlaylistItem> items, int oldIndex, int newIndex)
      onReorder;
  final void Function(List<PlaylistItem> items, PlaylistItem item) onRemove;

  void _showActions(BuildContext context, WidgetRef ref, PlaylistItem item) {
    onSongActions(
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
    // Solo la canción actual y si suena: no reconstruir con la posición.
    final currentIdentity = ref.watch(
      currentSongProvider.select((song) => song.valueOrNull?.musicIdentity),
    );
    final isPlaying = ref.watch(
          playbackStateProvider.select((state) => state.valueOrNull?.isPlaying),
        ) ??
        false;

    return ReorderableListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      // Alto medido con una fila real: crece con el tamaño de texto
      // (TakiSongTile, §8) y la lista sigue siendo perezosa.
      prototypeItem:
          items.isEmpty ? null : _SongRow.prototype(items.first.song),
      header: _Header(
        playlist: playlist,
        items: items,
        onPlay: items.isEmpty ? null : () => onPlay(items, 0),
        onShuffle: items.isEmpty ? null : () => onShuffle(items),
      ),
      // TakiEmptyState se desplaza por su cuenta: sin IgnorePointer, arrastrar
      // sobre él no llegaría a la lista y no habría pull-to-refresh. No tiene
      // acciones, así que no se pierde ninguna.
      footer: items.isEmpty
          ? const IgnorePointer(
              child: TakiEmptyState(
                icon: Icons.playlist_add_rounded,
                title: 'Sin canciones',
                description: 'Esta playlist está vacía. Añade canciones desde '
                    'la Biblioteca.',
              ),
            )
          : const SizedBox(height: TakiSpacing.lg),
      itemCount: items.length,
      onReorder: (oldIndex, newIndex) => onReorder(items, oldIndex, newIndex),
      // La fila arrastrada flota (nivel 2, §5), sin sombra; como en la Cola.
      proxyDecorator: (child, index, animation) => Material(
        color: TakiElevation.floating.surface,
        borderRadius: TakiRadius.mdAll,
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return _SongRow(
          // La entrada, no la canción: una playlist admite duplicados.
          key: ValueKey(item.entry.id),
          song: item.song,
          listIndex: index,
          playback: item.song.musicIdentity != currentIdentity
              ? TakiNowPlaying.none
              : isPlaying
                  ? TakiNowPlaying.playing
                  : TakiNowPlaying.paused,
          onTap: () => onPlay(items, index),
          onActions: () => _showActions(context, ref, item),
        );
      },
    );
  }
}

/// Fila de la playlist: `TakiSongTile` con ⋯ (acciones) y el asa de
/// arrastre.
class _SongRow extends StatelessWidget {
  const _SongRow({
    super.key,
    required this.song,
    required this.listIndex,
    required this.playback,
    required this.onTap,
    required this.onActions,
  }) : _isPrototype = false;

  /// Fila de referencia para medir el alto (no se muestra ni reacciona).
  const _SongRow.prototype(this.song)
      : listIndex = 0,
        playback = TakiNowPlaying.none,
        onTap = null,
        onActions = null,
        _isPrototype = true;

  static const String reorderLabel = 'Arrastrar para reordenar';

  final Song song;

  /// Posición en la lista visible (la que usa ReorderableListView).
  final int listIndex;
  final TakiNowPlaying playback;
  final VoidCallback? onTap;
  final VoidCallback? onActions;
  final bool _isPrototype;

  @override
  Widget build(BuildContext context) {
    final handle = ReorderableDragStartListener(
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
    );

    // El prototipo lleva ⋯ para medir igual que una fila real.
    if (_isPrototype) {
      return TakiSongTile(song: song, onMore: () {}, trailing: handle);
    }

    return AlbumArtworkBuilder.reference(
      reference: song.artwork,
      size: TakiSongTile.artworkSize,
      builder: (_, artwork) => TakiSongTile(
        song: song,
        artwork: artwork,
        playback: playback,
        onTap: onTap,
        onLongPress: onActions,
        onMore: onActions,
        trailing: handle,
      ),
    );
  }
}

/// Portada, "PLAYLIST", nombre, resumen y Reproducir / Aleatorio sobre una
/// zona agrupada (nivel 1, §5).
class _Header extends StatelessWidget {
  const _Header({
    required this.playlist,
    required this.items,
    required this.onPlay,
    required this.onShuffle,
  });

  /// Lado de la portada (`artworkHeader`, §7.3).
  static const double coverSize = 128;

  final Playlist playlist;
  final List<PlaylistItem> items;
  final VoidCallback? onPlay;
  final VoidCallback? onShuffle;

  @override
  Widget build(BuildContext context) {
    final total = items.fold(
      Duration.zero,
      (sum, item) => sum + item.song.duration,
    );
    final hiddenCount = playlist.songCount - items.length;
    // Las 4 primeras canciones *visibles* (las ausentes de la biblioteca no
    // están en `items`); no `Playlist.coverIdentities`, como usa la lista.
    final coverArtwork = playlistCoverArtwork(
      items.take(4).map((item) => item.song.artwork),
    );

    return Container(
      color: TakiElevation.raised.surface,
      margin: const EdgeInsets.only(bottom: TakiSpacing.sm),
      padding: const EdgeInsets.fromLTRB(
        TakiSpacing.pageGutter,
        TakiSpacing.sm,
        TakiSpacing.pageGutter,
        TakiSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PlaylistCoverImages(
                artwork: coverArtwork,
                size: coverSize,
                builder: (images) =>
                    TakiArtwork.mosaic(size: coverSize, images: images),
              ),
              const SizedBox(width: TakiSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PLAYLIST',
                      style: TakiTypography.eyebrow.copyWith(
                        color: TakiColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: TakiSpacing.xs),
                    Semantics(
                      header: true,
                      child: Text(
                        playlist.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TakiTypography.headline.copyWith(
                          color: TakiColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: TakiSpacing.xs),
                    Text(
                      // Entries hidden because their source is unavailable
                      // (e.g. local songs without the music permission) are
                      // still counted by the playlist, so say so.
                      hiddenCount > 0
                          ? '${formatSongsSummary(items.length, total)} · '
                              '$hiddenCount no disponibles'
                          : formatSongsSummary(items.length, total),
                      style: TakiTypography.trackSubtitle.copyWith(
                        color: TakiColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: TakiSpacing.lg),
          // Con texto grande, Aleatorio pasa debajo en vez de desbordar.
          Wrap(
            spacing: TakiSpacing.md,
            runSpacing: TakiSpacing.md,
            children: [
              TakiButton(
                label: 'Reproducir',
                icon: Icons.play_arrow_rounded,
                onPressed: onPlay,
              ),
              TakiButton(
                label: 'Aleatorio',
                icon: Icons.shuffle_rounded,
                variant: TakiButtonVariant.secondary,
                onPressed: onShuffle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
