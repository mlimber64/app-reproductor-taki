import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/artwork_reference.dart';
import '../../../../core/theme/taki_colors.dart';
import '../../../../core/theme/taki_spacing.dart';
import '../../../../core/utils/duration_format.dart';
import '../../../../core/widgets/taki_button.dart';
import '../../../../core/widgets/taki_empty_state.dart';
import '../../../../core/widgets/taki_error_state.dart';
import '../../../../core/widgets/taki_playlist_card.dart';
import '../../../../core/widgets/taki_section_header.dart';
import '../../domain/entities/playlist.dart';
import '../playlist_cover_albums.dart';
import '../playlist_cover_images.dart';
import '../providers/playlists_providers.dart';
import '../widgets/delete_playlist_dialog.dart';
import '../widgets/playlist_name_dialog.dart';

class PlaylistsPage extends ConsumerWidget {
  const PlaylistsPage({super.key, required this.onOpenPlaylist});

  static const String title = 'Playlists';

  /// Abre el detalle (la navegación la decide el router).
  final void Function(int playlistId) onOpenPlaylist;

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await showPlaylistNameDialog(
      context,
      title: 'Nueva playlist',
      confirmLabel: 'Crear',
    );
    if (name == null) return;
    try {
      final id = await ref.read(createPlaylistProvider).call(name);
      onOpenPlaylist(id);
    } catch (_) {
      if (context.mounted) _showMessage(context, 'No se pudo crear la playlist');
    }
  }

  Future<void> _showActions(
    BuildContext context,
    WidgetRef ref,
    Playlist playlist,
  ) async {
    final action = await showModalBottomSheet<_PlaylistAction>(
      context: context,
      backgroundColor: TakiColors.surfaceElevated,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                playlist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Renombrar'),
              onTap: () => Navigator.of(context).pop(_PlaylistAction.rename),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Eliminar'),
              onTap: () => Navigator.of(context).pop(_PlaylistAction.delete),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case _PlaylistAction.rename:
        final name = await showPlaylistNameDialog(
          context,
          title: 'Renombrar playlist',
          confirmLabel: 'Guardar',
          initialName: playlist.name,
        );
        if (name != null) {
          await ref.read(renamePlaylistProvider).call(playlist.id, name);
        }
      case _PlaylistAction.delete:
        if (!await confirmDeletePlaylist(context, playlist.name)) return;
        await ref.read(deletePlaylistProvider).call(playlist.id);
        if (context.mounted) _showMessage(context, 'Playlist eliminada');
    }
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);
    final libraryArtwork = ref.watch(playlistCoverArtworkProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(title)),
      body: playlists.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        // Sin pull-to-refresh, como antes.
        error: (_, _) => TakiErrorState(
          title: 'Playlists no disponibles',
          message: 'No pudimos leer tus playlists guardadas.',
          action: TakiStateAction(
            label: 'Reintentar',
            onPressed: () => retryPlaylists(ref),
          ),
        ),
        data: (list) => ListView.builder(
          padding: const EdgeInsets.only(bottom: TakiSpacing.lg),
          itemCount: list.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  TakiSpacing.pageGutter,
                  TakiSpacing.sm,
                  TakiSpacing.pageGutter,
                  0,
                ),
                child: _NewPlaylistButton(
                  onPressed: () => _create(context, ref),
                ),
              );
            }
            if (index == 1) {
              // "Nueva playlist" ya está arriba: el vacío no repite la acción.
              return list.isEmpty
                  ? const TakiEmptyState(
                      icon: Icons.queue_music_rounded,
                      title: 'Sin playlists',
                      description: 'Aún no tienes playlists. Crea la primera '
                          'para agrupar tus canciones.',
                    )
                  : const TakiSectionHeader(
                      // El grupo se muestra en MAYÚSCULAS: "TUS PLAYLISTS".
                      title: 'Tus playlists',
                      variant: TakiSectionHeaderVariant.group,
                    );
            }
            final playlist = list[index - 2];
            return _PlaylistRow(
              playlist: playlist,
              // Las primeras 4 entradas guardadas (las ausentes de la
              // biblioteca entran como null) → carátulas de la portada.
              coverArtwork: playlistCoverArtwork([
                for (final identity in playlist.coverIdentities)
                  libraryArtwork[identity],
              ]),
              onTap: () => onOpenPlaylist(playlist.id),
              onLongPress: () => _showActions(context, ref, playlist),
            );
          },
        ),
      ),
    );
  }
}

enum _PlaylistAction { rename, delete }

/// "Nueva playlist": `TakiButton` secundario con icono (sin equivalente Taki
/// del borde discontinuo anterior), alineado al inicio.
class _NewPlaylistButton extends StatelessWidget {
  const _NewPlaylistButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // La lista da a cada elemento todo el ancho; sin aflojarlo, el área
    // táctil del botón se extendería más allá de la píldora visible.
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TakiButton(
        label: 'Nueva playlist',
        icon: Icons.add_rounded,
        variant: TakiButtonVariant.secondary,
        onPressed: onPressed,
      ),
    );
  }
}

/// Una playlist como [TakiPlaylistCard]. El resumen se pasa entero como
/// `subtitle` para conservar "0 canciones" (la tarjeta diría "Vacía").
class _PlaylistRow extends StatelessWidget {
  const _PlaylistRow({
    required this.playlist,
    required this.coverArtwork,
    required this.onTap,
    required this.onLongPress,
  });

  final Playlist playlist;

  /// Carátulas de la portada ya elegidas ([playlistCoverArtwork]): `[]` sin
  /// canciones (placeholder con borde), `[Unavailable]` con canciones pero sin
  /// carátulas (una pieza sin imagen).
  final List<ArtworkReference> coverArtwork;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        onLongPressHint: 'Renombrar o eliminar',
        child: PlaylistCoverImages(
          artwork: coverArtwork,
          size: TakiPlaylistCard.artworkSize,
          builder: (images) => TakiPlaylistCard(
            title: playlist.name,
            artwork: images,
            subtitle: formatSongsSummary(
              playlist.songCount,
              playlist.totalDuration,
            ),
            onTap: onTap,
            onLongPress: onLongPress,
          ),
        ),
      ),
    );
  }
}
