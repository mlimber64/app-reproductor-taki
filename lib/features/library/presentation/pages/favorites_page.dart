import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/artwork/album_artwork_builder.dart';
import '../../../../core/domain/entities/song.dart';
import '../../../../core/theme/taki_colors.dart';
import '../../../../core/theme/taki_spacing.dart';
import '../../../../core/theme/taki_typography.dart';
import '../../../../core/utils/duration_format.dart';
import '../../../../core/widgets/song_actions.dart';
import '../../../../core/widgets/taki_button.dart';
import '../../../../core/widgets/taki_empty_state.dart';
import '../../../../core/widgets/taki_error_state.dart';
import '../../../../core/widgets/taki_song_tile.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../providers/favorites_providers.dart';
import '../providers/songs_notifier.dart';

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key, required this.onSongActions});

  static const String title = 'Favoritos';

  /// Menú de acciones de una canción (pulsación larga).
  final ShowSongActions onSongActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(songsProvider).valueOrNull;
    final favorites = ref.watch(favoriteSongsProvider);
    final notifier = ref.read(songsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text(title)),
      // Permiso y error sin pull-to-refresh; vacío y lista sí.
      // El permiso de música solo hace falta para la fuente local: las
      // canciones de otras fuentes se muestran igual. Sin permiso y sin nada que
      // mostrar, se pide (como antes).
      body: favorites.when(
        // Al recalcular (p. ej. tras marcar un favorito) se mantiene la
        // lista anterior en vez de parpadear con el indicador.
        skipLoadingOnReload: true,
        // A failed recalculation (e.g. offline) keeps the last good list
        // instead of replacing it with the error state.
        skipError: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => TakiErrorState(
          title: 'Favoritos no disponibles',
          message: 'No pudimos leer tus favoritos guardados.',
          action: TakiStateAction(
            label: 'Reintentar',
            onPressed: () => retryFavorites(ref),
          ),
        ),
        data: (songs) => songs.isEmpty && library is LibraryNeedsPermission
            ? TakiErrorState(
                kind: TakiErrorStateKind.permission,
                title: 'Taki necesita acceso a tu música',
                message: 'Tus favoritos se muestran a partir de las canciones '
                    'de tu teléfono.',
                action: TakiStateAction(
                  label: library.permanentlyDenied
                      ? 'Abrir ajustes'
                      : 'Permitir acceso',
                  onPressed: notifier.requestPermission,
                ),
              )
            : RefreshIndicator(
                onRefresh: notifier.rescan,
                child: songs.isEmpty
                    ? const TakiEmptyState(
                        icon: Icons.favorite_border_rounded,
                        title: 'Sin favoritos',
                        description: 'Aún no tienes favoritos. Toca el '
                            'corazón en Reproduciendo o mantén pulsada una '
                            'canción.',
                      )
                    : _FavoritesList(
                        songs: songs,
                        onSongActions: onSongActions,
                      ),
              ),
      ),
    );
  }
}

class _FavoritesList extends ConsumerWidget {
  const _FavoritesList({required this.songs, required this.onSongActions});

  /// En el orden de `favoriteSongsProvider` (más recientes primero); no se
  /// vuelve a ordenar.
  final List<Song> songs;
  final ShowSongActions onSongActions;

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
    // Solo la canción actual y si suena: no reconstruir con la posición.
    final currentIdentity = ref.watch(
      currentSongProvider.select((song) => song.valueOrNull?.musicIdentity),
    );
    final isPlaying = ref.watch(
          playbackStateProvider.select((state) => state.valueOrNull?.isPlaying),
        ) ??
        false;

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
        // Alto medido con una fila real: crece con el tamaño de texto y la
        // lista sigue siendo perezosa.
        SliverPrototypeExtentList.builder(
          prototypeItem: TakiSongTile(song: songs.first),
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            // Sin corazón: aquí todas son favoritas (§8).
            return AlbumArtworkBuilder.reference(
              reference: song.artwork,
              size: TakiSongTile.artworkSize,
              builder: (_, artwork) => TakiSongTile(
                song: song,
                artwork: artwork,
                playback: song.musicIdentity != currentIdentity
                    ? TakiNowPlaying.none
                    : isPlaying
                        ? TakiNowPlaying.playing
                        : TakiNowPlaying.paused,
                onTap: () => _play(ref, index),
                onLongPress: () => onSongActions(context, ref, song),
              ),
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: TakiSpacing.lg)),
      ],
    );
  }
}

/// Resumen ("N canciones · duración") y Reproducir / Aleatorio.
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
    final count = songs.length == 1 ? '1 canción' : '${songs.length} canciones';
    final total = songs.fold(Duration.zero, (sum, song) => sum + song.duration);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TakiSpacing.pageGutter,
        TakiSpacing.sm,
        TakiSpacing.pageGutter,
        TakiSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // El encabezado es "Favoritos" (barra superior); el resumen se
          // anuncia como un nodo propio.
          Semantics(
            container: true,
            child: Text(
              '$count · ${formatTotalDuration(total)}',
              style: TakiTypography.trackSubtitle.copyWith(
                color: TakiColors.textSecondary,
              ),
            ),
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
