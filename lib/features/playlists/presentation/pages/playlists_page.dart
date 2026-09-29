import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/duration_format.dart';
import '../../../../core/widgets/message_view.dart';
import '../../domain/entities/playlist.dart';
import '../providers/playlists_providers.dart';
import '../widgets/delete_playlist_dialog.dart';
import '../widgets/playlist_cover.dart';
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
      backgroundColor: AppColors.surfaceElevated,
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
    final albumIds = ref.watch(libraryAlbumIdsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(title)),
      body: playlists.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => MessageView(
          icon: Icons.error_outline_rounded,
          title: 'Playlists no disponibles',
          message: 'No pudimos leer tus playlists guardadas.',
          actionLabel: 'Reintentar',
          onAction: () => retryPlaylists(ref),
        ),
        data: (list) => ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: list.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _NewPlaylistButton(
                  onPressed: () => _create(context, ref),
                ),
              );
            }
            if (index == 1) {
              return list.isEmpty
                  ? const _EmptyPlaylists()
                  : const _SectionLabel('TUS PLAYLISTS');
            }
            final playlist = list[index - 2];
            return _PlaylistRow(
              playlist: playlist,
              albumIds: [for (final id in playlist.coverSongIds) albumIds[id]],
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

class _NewPlaylistButton extends StatelessWidget {
  const _NewPlaylistButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const radius = BorderRadius.all(Radius.circular(16));

    return Semantics(
      button: true,
      child: CustomPaint(
        painter: _DashedBorderPainter(color: AppColors.border, radius: 16),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: onPressed,
            child: SizedBox(
              height: 64,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Nueva playlist',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const double _dash = 6;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final border = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(0.75),
      );
    for (final PathMetric metric in border.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(metric.extractPath(d, d + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color || radius != oldDelegate.radius;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 12,
              letterSpacing: 1.2,
              color: AppColors.textSecondary,
            ),
      ),
    );
  }
}

class _EmptyPlaylists extends StatelessWidget {
  const _EmptyPlaylists();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 0),
      child: Column(
        children: [
          Icon(
            Icons.queue_music_rounded,
            size: 56,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Aún no tienes playlists. Crea la primera para agrupar tus '
            'canciones.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistRow extends StatelessWidget {
  const _PlaylistRow({
    required this.playlist,
    required this.albumIds,
    required this.onTap,
    required this.onLongPress,
  });

  final Playlist playlist;
  final List<int?> albumIds;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      onLongPressHint: 'Renombrar o eliminar',
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          height: 68,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                PlaylistCover(
                  albumIds: albumIds,
                  isEmpty: playlist.songCount == 0,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playlist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyLarge?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatSongsSummary(
                          playlist.songCount,
                          playlist.totalDuration,
                        ),
                        style: textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
