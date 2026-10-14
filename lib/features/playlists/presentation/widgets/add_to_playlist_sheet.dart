import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/song.dart';
import '../../../../core/theme/taki_colors.dart';
import '../../../../core/utils/duration_format.dart';
import '../../../../core/widgets/taki_artwork.dart';
import '../../domain/entities/playlist.dart';
import '../playlist_cover_albums.dart';
import '../playlist_cover_images.dart';
import '../providers/playlists_providers.dart';
import 'playlist_name_dialog.dart';

/// Elige una playlist (o crea una nueva) y le añade [songs]. Confirma con un
/// SnackBar; si alguna ya estaba, la añade igual y lo avisa.
Future<void> addSongsToPlaylistFlow(
  BuildContext context,
  WidgetRef ref,
  List<Song> songs,
) async {
  final choice = await showModalBottomSheet<_PlaylistChoice>(
    context: context,
    backgroundColor: TakiColors.surfaceElevated,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const _PlaylistPickerSheet(),
  );
  if (choice == null || !context.mounted) return;

  String message;
  try {
    final int playlistId;
    final String name;
    switch (choice) {
      case _NewPlaylist():
        final newName = await showPlaylistNameDialog(
          context,
          title: 'Nueva playlist',
          confirmLabel: 'Crear',
        );
        if (newName == null || !context.mounted) return;
        playlistId = await ref.read(createPlaylistProvider).call(newName);
        name = newName;
      case _ExistingPlaylist(:final playlist):
        playlistId = playlist.id;
        name = playlist.name;
    }
    final wasThere =
        await ref.read(addSongsToPlaylistProvider).call(playlistId, songs);
    message = wasThere
        ? 'Ya estaba en «$name»; se añadió otra vez'
        : 'Añadida a «$name»';
  } catch (_) {
    message = 'Las playlists no están disponibles';
  }

  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

sealed class _PlaylistChoice {
  const _PlaylistChoice();
}

final class _NewPlaylist extends _PlaylistChoice {
  const _NewPlaylist();
}

final class _ExistingPlaylist extends _PlaylistChoice {
  const _ExistingPlaylist(this.playlist);

  final Playlist playlist;
}

/// Lado lógico de la portada de cada playlist del selector.
const double _coverSize = 44;

class _PlaylistPickerSheet extends ConsumerWidget {
  const _PlaylistPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);
    final libraryArtwork = ref.watch(playlistCoverArtworkProvider);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Añadir a una playlist',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: const Text('Nueva playlist'),
              onTap: () => Navigator.of(context).pop(const _NewPlaylist()),
            ),
            const Divider(height: 1),
            Flexible(
              child: switch (playlists) {
                AsyncData(:final value) => ListView.builder(
                    shrinkWrap: true,
                    itemCount: value.length,
                    itemBuilder: (context, index) {
                      final playlist = value[index];
                      return ListTile(
                        minTileHeight: 64,
                        // Las primeras 4 entradas guardadas (las ausentes de la
                        // biblioteca entran como null), como la lista.
                        leading: PlaylistCoverImages(
                          artwork: playlistCoverArtwork([
                            for (final id in playlist.coverIdentities)
                              libraryArtwork[id],
                          ]),
                          size: _coverSize,
                          builder: (images) => TakiArtwork.mosaic(
                            size: _coverSize,
                            images: images,
                          ),
                        ),
                        title: Text(
                          playlist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          formatSongsSummary(
                            playlist.songCount,
                            playlist.totalDuration,
                          ),
                        ),
                        onTap: () => Navigator.of(context)
                            .pop(_ExistingPlaylist(playlist)),
                      );
                    },
                  ),
                AsyncError() => const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Las playlists no están disponibles'),
                  ),
                _ => const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
