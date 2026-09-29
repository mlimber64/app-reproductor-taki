import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/artwork/artwork_cache.dart';
import '../../../../core/artwork/artwork_providers.dart';
import '../../../../core/constants/library_constants.dart';
import '../../../../core/domain/entities/song.dart';
import '../../../../core/theme/taki_colors.dart';
import '../../../../core/theme/taki_spacing.dart';
import '../../../../core/theme/taki_typography.dart';
import '../../../../core/utils/duration_format.dart';
import '../../../../core/widgets/song_actions.dart';
import '../../../../core/widgets/taki_empty_state.dart';
import '../../../../core/widgets/taki_error_state.dart';
import '../../../../core/widgets/taki_song_tile.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../providers/songs_notifier.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key, required this.onSongActions});

  static const String title = 'Biblioteca';

  /// Menú de acciones de una canción (pulsación larga).
  final ShowSongActions onSongActions;

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    // Si el usuario concede el permiso desde Ajustes, lo detectamos al volver.
    _lifecycleListener = AppLifecycleListener(
      onResume: () => ref.read(songsProvider.notifier).recheckPermission(),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(songsProvider);
    final notifier = ref.read(songsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text(LibraryPage.title)),
      body: library.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        // Error y vacío admiten pull-to-refresh (los estados Taki ya son
        // desplazables).
        error: (_, _) => RefreshIndicator(
          onRefresh: notifier.rescan,
          child: TakiErrorState(
            title: 'No pudimos leer tu música',
            message: 'Ocurrió un error al escanear el teléfono.',
            action: TakiStateAction(
              label: 'Reintentar',
              onPressed: notifier.retry,
            ),
          ),
        ),
        data: (state) => switch (state) {
          LibraryNeedsPermission(:final permanentlyDenied) => TakiErrorState(
              kind: TakiErrorStateKind.permission,
              title: 'Taki necesita acceso a tu música',
              message: permanentlyDenied
                  ? 'El permiso está desactivado. Actívalo en los ajustes de '
                      'la app, en Permisos → Música y audio.'
                  : 'Solo leemos las canciones guardadas en tu teléfono. '
                      'Nada sale de tu dispositivo.',
              action: TakiStateAction(
                label: permanentlyDenied ? 'Abrir ajustes' : 'Permitir acceso',
                onPressed: notifier.requestPermission,
              ),
            ),
          LibraryEmpty() => RefreshIndicator(
              onRefresh: notifier.rescan,
              child: TakiEmptyState(
                icon: Icons.music_off_rounded,
                title: 'No encontramos canciones',
                description: 'Copia música a tu teléfono y vuelve a '
                    'intentarlo. Los audios de menos de '
                    '${LibraryConstants.minSongDuration.inSeconds} s no se '
                    'muestran.',
                action: TakiStateAction(
                  label: 'Reintentar',
                  onPressed: notifier.retry,
                ),
              ),
            ),
          LibraryLoaded() => RefreshIndicator(
              onRefresh: notifier.rescan,
              child: _SongList(
                library: state,
                onSongActions: widget.onSongActions,
              ),
            ),
        },
      ),
    );
  }
}

class _SongList extends ConsumerWidget {
  const _SongList({required this.library, required this.onSongActions});

  final LibraryLoaded library;
  final ShowSongActions onSongActions;

  /// Reproduce la lista tal como se ve, desde la canción tocada.
  Future<void> _play(WidgetRef ref, List<Song> songs, int index) async {
    await ref.read(playSongsProvider).call(songs, index);
    // Después de arrancar: si se rechaza, la música sigue sonando.
    unawaited(ref.read(notificationPermissionProvider).requestIfNeeded());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = library.songs;
    // Solo la canción actual y si suena: no reconstruir con la posición.
    final currentSongId = ref.watch(
      currentSongProvider.select((song) => song.valueOrNull?.id),
    );
    final isPlaying = ref.watch(
          playbackStateProvider.select((state) => state.valueOrNull?.isPlaying),
        ) ??
        false;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _LibraryHeader(library: library)),
        // Alto medido con una fila real: crece con el tamaño de texto
        // (TakiSongTile, §8) y la lista sigue siendo perezosa.
        SliverPrototypeExtentList.builder(
          prototypeItem: TakiSongTile(song: songs.first),
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            return _SongArtwork(
              albumId: song.albumId,
              builder: (artwork) => TakiSongTile(
                song: song,
                artwork: artwork,
                playback: song.id != currentSongId
                    ? TakiNowPlaying.none
                    : isPlaying
                        ? TakiNowPlaying.playing
                        : TakiNowPlaying.paused,
                onTap: () => _play(ref, songs, index),
                onLongPress: () => onSongActions(context, ref, song),
              ),
            );
          },
        ),
        // §3: aire al final para que la última fila no quede pegada al
        // mini player.
        const SliverToBoxAdapter(child: SizedBox(height: TakiSpacing.lg)),
      ],
    );
  }
}

/// "Tu música" y el resumen de la biblioteca.
class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({required this.library});

  final LibraryLoaded library;

  @override
  Widget build(BuildContext context) {
    final count = library.songs.length;
    final countLabel = count == 1 ? '1 canción' : '$count canciones';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TakiSpacing.pageGutter,
        TakiSpacing.sm,
        TakiSpacing.pageGutter,
        TakiSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Tu música',
              style: TakiTypography.headline.copyWith(
                color: TakiColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: TakiSpacing.xs),
          Text(
            '$countLabel · ${formatTotalDuration(library.totalDuration)}',
            style: TakiTypography.trackSubtitle.copyWith(
              color: TakiColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Resuelve la carátula de una fila con [ArtworkCache] (bytes →
/// `MemoryImage`), la misma fuente que usaba `SongTile`.
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
