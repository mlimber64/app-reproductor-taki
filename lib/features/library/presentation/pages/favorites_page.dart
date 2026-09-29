import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/widgets/play_shuffle_buttons.dart';
import '../../../../app/widgets/song_actions_sheet.dart';
import '../../../../core/utils/duration_format.dart';
import '../../../../core/widgets/message_view.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../domain/entities/song.dart';
import '../providers/favorites_providers.dart';
import '../providers/songs_notifier.dart';
import '../widgets/song_tile.dart';

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  static const String title = 'Favoritos';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(songsProvider).valueOrNull;
    final favorites = ref.watch(favoriteSongsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(title)),
      body: library is LibraryNeedsPermission
          ? MessageView(
              icon: Icons.lock_outline_rounded,
              title: 'Taki necesita acceso a tu música',
              message: 'Tus favoritos se muestran a partir de las canciones '
                  'de tu teléfono.',
              actionLabel: library.permanentlyDenied
                  ? 'Abrir ajustes'
                  : 'Permitir acceso',
              onAction: ref.read(songsProvider.notifier).requestPermission,
            )
          : favorites.when(
              // Al recalcular (p. ej. tras marcar un favorito) se mantiene la
              // lista anterior en vez de parpadear con el indicador.
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => MessageView(
                icon: Icons.error_outline_rounded,
                title: 'Favoritos no disponibles',
                message: 'No pudimos leer tus favoritos guardados.',
                actionLabel: 'Reintentar',
                onAction: () => retryFavorites(ref),
              ),
              data: (songs) => songs.isEmpty
                  ? MessageView(
                      icon: Icons.favorite_border_rounded,
                      title: 'Sin favoritos',
                      message: 'Aún no tienes favoritos. Toca el corazón en '
                          'Reproduciendo o mantén pulsada una canción.',
                      onRefresh: ref.read(songsProvider.notifier).rescan,
                    )
                  : RefreshIndicator(
                      onRefresh: ref.read(songsProvider.notifier).rescan,
                      child: _FavoritesList(songs: songs),
                    ),
            ),
    );
  }
}

class _FavoritesList extends ConsumerWidget {
  const _FavoritesList({required this.songs});

  final List<Song> songs;

  Future<void> _play(WidgetRef ref, int index) async {
    await ref.read(playSongsProvider).call(songs, index);
    unawaited(ref.read(notificationPermissionProvider).requestIfNeeded());
  }

  Future<void> _playShuffled(WidgetRef ref) async {
    await ref.read(playSongsShuffledProvider).call(songs);
    unawaited(ref.read(notificationPermissionProvider).requestIfNeeded());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSongId = ref.watch(
      currentSongProvider.select((song) => song.valueOrNull?.id),
    );

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _FavoritesHeader(
            songs: songs,
            onPlay: () => _play(ref, 0),
            onShuffle: () => _playShuffled(ref),
          ),
        ),
        SliverFixedExtentList.builder(
          itemExtent: SongTile.height,
          itemCount: songs.length,
          itemBuilder: (context, index) => SongTile(
            song: songs[index],
            isCurrent: songs[index].id == currentSongId,
            onTap: () => _play(ref, index),
            onLongPress: () => showSongActions(context, ref, songs[index]),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}

class _FavoritesHeader extends StatelessWidget {
  const _FavoritesHeader({
    required this.songs,
    required this.onPlay,
    required this.onShuffle,
  });

  final List<Song> songs;
  final VoidCallback onPlay;
  final VoidCallback onShuffle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = songs.length == 1 ? '1 canción' : '${songs.length} canciones';
    final total = songs.fold(Duration.zero, (sum, song) => sum + song.duration);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count · ${formatTotalDuration(total)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          PlayShuffleButtons(onPlay: onPlay, onShuffle: onShuffle),
        ],
      ),
    );
  }
}
