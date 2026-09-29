import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/entities/song.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/song_actions.dart';
import '../../features/library/presentation/providers/favorites_providers.dart';
import '../../features/player/presentation/providers/player_providers.dart';
import '../../features/playlists/presentation/widgets/add_to_playlist_sheet.dart';

// Vive en app/ porque combina varias features (cola, favoritos y playlists).

enum SongAction { playNext, addToQueue, toggleFavorite, addToPlaylist }

/// Acciones de una canción (pulsación larga o menú "⋯"): cola, favoritos,
/// playlists y las [extraActions] de la pantalla. Confirma con un SnackBar.
///
/// Es un [ShowSongActions]: el router lo pasa a las páginas que lo usan.
Future<void> showSongActions(
  BuildContext context,
  WidgetRef ref,
  Song song, {
  List<ExtraSongAction> extraActions = const [],
}) async {
  final choice = await showModalBottomSheet<Object>(
    context: context,
    backgroundColor: AppColors.surfaceElevated,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) =>
        SongActionsSheet(song: song, extraActions: extraActions),
  );
  if (choice == null || !context.mounted) return;

  if (choice is ExtraSongAction) {
    await choice.onSelected();
    return;
  }

  String message;
  switch (choice as SongAction) {
    case SongAction.addToPlaylist:
      await addSongsToPlaylistFlow(context, ref, [song]);
      return;
    case SongAction.playNext || SongAction.addToQueue:
      final wasIdle =
          ref.read(audioPlayerPortProvider).state.currentSong == null;
      if (choice == SongAction.playNext) {
        await ref.read(playNextProvider).call([song]);
      } else {
        await ref.read(addToQueueProvider).call([song]);
      }
      unawaited(ref.read(notificationPermissionProvider).requestIfNeeded());
      message = wasIdle
          ? 'Reproduciendo «${song.title}»'
          : choice == SongAction.playNext
              ? 'Sonará a continuación'
              : 'Añadida a la cola';
    case SongAction.toggleFavorite:
      try {
        final isFavorite = await ref.read(toggleFavoriteProvider).call(song);
        message = isFavorite ? 'Añadida a favoritos' : 'Quitada de favoritos';
      } catch (_) {
        message = 'Los favoritos no están disponibles';
      }
  }

  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class SongActionsSheet extends ConsumerWidget {
  const SongActionsSheet({
    super.key,
    required this.song,
    this.extraActions = const [],
  });

  final Song song;
  final List<ExtraSongAction> extraActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final isFavorite = ref.watch(isFavoriteProvider(song.id));

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.queue_play_next_rounded),
              title: const Text('Reproducir a continuación'),
              onTap: () => Navigator.of(context).pop(SongAction.playNext),
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add_rounded),
              title: const Text('Añadir a la cola'),
              onTap: () => Navigator.of(context).pop(SongAction.addToQueue),
            ),
            ListTile(
              leading: Icon(
                isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
              ),
              title: Text(
                isFavorite ? 'Quitar de favoritos' : 'Añadir a favoritos',
              ),
              onTap: () =>
                  Navigator.of(context).pop(SongAction.toggleFavorite),
            ),
            ListTile(
              leading: const Icon(Icons.library_add_rounded),
              title: const Text('Añadir a una playlist'),
              onTap: () => Navigator.of(context).pop(SongAction.addToPlaylist),
            ),
            for (final action in extraActions)
              ListTile(
                leading: Icon(action.icon),
                title: Text(action.label),
                onTap: () => Navigator.of(context).pop(action),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
