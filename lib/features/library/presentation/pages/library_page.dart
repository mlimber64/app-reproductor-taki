import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/widgets/song_actions_sheet.dart';
import '../../../../core/constants/library_constants.dart';
import '../../../../core/utils/duration_format.dart';
import '../../../../core/widgets/message_view.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../domain/entities/song.dart';
import '../providers/songs_notifier.dart';
import '../widgets/song_tile.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  static const String title = 'Biblioteca';

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
        error: (_, _) => MessageView(
          icon: Icons.error_outline_rounded,
          title: 'No pudimos leer tu música',
          message: 'Ocurrió un error al escanear el teléfono.',
          actionLabel: 'Reintentar',
          onAction: notifier.retry,
          onRefresh: notifier.rescan,
        ),
        data: (state) => switch (state) {
          LibraryNeedsPermission(:final permanentlyDenied) => MessageView(
              icon: Icons.lock_outline_rounded,
              title: 'Taki necesita acceso a tu música',
              message: permanentlyDenied
                  ? 'El permiso está desactivado. Actívalo en los ajustes de '
                      'la app, en Permisos → Música y audio.'
                  : 'Solo leemos las canciones guardadas en tu teléfono. '
                      'Nada sale de tu dispositivo.',
              actionLabel:
                  permanentlyDenied ? 'Abrir ajustes' : 'Permitir acceso',
              onAction: notifier.requestPermission,
            ),
          LibraryEmpty() => MessageView(
              icon: Icons.music_off_outlined,
              title: 'No encontramos canciones',
              message: 'Copia música a tu teléfono y vuelve a intentarlo. '
                  'Los audios de menos de '
                  '${LibraryConstants.minSongDuration.inSeconds} s no se '
                  'muestran.',
              actionLabel: 'Reintentar',
              onAction: notifier.retry,
              onRefresh: notifier.rescan,
            ),
          LibraryLoaded() => RefreshIndicator(
              onRefresh: notifier.rescan,
              child: _SongList(library: state),
            ),
        },
      ),
    );
  }
}

class _SongList extends ConsumerWidget {
  const _SongList({required this.library});

  final LibraryLoaded library;

  /// Reproduce la lista tal como se ve, desde la canción tocada.
  Future<void> _play(WidgetRef ref, List<Song> songs, int index) async {
    await ref.read(playSongsProvider).call(songs, index);
    // Después de arrancar: si se rechaza, la música sigue sonando.
    unawaited(ref.read(notificationPermissionProvider).requestIfNeeded());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = library.songs;
    final currentSongId = ref.watch(
      currentSongProvider.select((song) => song.valueOrNull?.id),
    );

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _LibraryHeader(library: library)),
        SliverFixedExtentList.builder(
          itemExtent: SongTile.height,
          itemCount: songs.length,
          itemBuilder: (context, index) => SongTile(
            song: songs[index],
            isCurrent: songs[index].id == currentSongId,
            onTap: () => _play(ref, songs, index),
            onLongPress: () => showSongActions(context, ref, songs[index]),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({required this.library});

  final LibraryLoaded library;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final count = library.songs.length;
    final countLabel = count == 1 ? '1 canción' : '$count canciones';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tu música', style: textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            '$countLabel · ${formatTotalDuration(library.totalDuration)}',
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
