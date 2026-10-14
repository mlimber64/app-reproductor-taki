import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/artwork/album_artwork_builder.dart';
import '../../../../core/domain/entities/music_identity.dart';
import '../../../../core/domain/entities/song.dart';
import '../../../../core/theme/taki_spacing.dart';
import '../../../../core/widgets/taki_playing_indicator.dart';
import '../../../../core/widgets/taki_section_header.dart';
import '../../../../core/widgets/taki_song_card.dart';
import '../providers/history_providers.dart';

/// "Escuchado recientemente": a carousel of cover cards at the top of the
/// library. It takes no space while there is nothing to show (no history yet,
/// still loading, or the history could not be read).
class RecentlyPlayedSection extends ConsumerWidget {
  const RecentlyPlayedSection({
    super.key,
    required this.currentIdentity,
    required this.isPlaying,
    required this.onPlayAt,
    required this.onActions,
  });

  static const String title = 'Escuchado recientemente';
  static const double cover = 132;
  static const double gap = 12;

  final MusicIdentity? currentIdentity;
  final bool isPlaying;
  final Future<void> Function(List<Song> songs, int index) onPlayAt;
  final Future<void> Function(Song song) onActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(recentSongsProvider).valueOrNull;
    if (songs == null || songs.isEmpty) return const SizedBox.shrink();

    final height = cover + TakiSongCard.textBlockHeight(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TakiSectionHeader(title: title, isFirst: true),
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: TakiSpacing.pageGutter,
            ),
            itemCount: songs.length,
            separatorBuilder: (_, _) => const SizedBox(width: gap),
            itemBuilder: (context, index) {
              final song = songs[index];
              return AlbumArtworkBuilder.reference(
                reference: song.artwork,
                size: cover,
                builder: (_, artwork) => TakiSongCard(
                  song: song,
                  artworkSize: cover,
                  artwork: artwork,
                  playback: song.musicIdentity != currentIdentity
                      ? TakiNowPlaying.none
                      : isPlaying
                          ? TakiNowPlaying.playing
                          : TakiNowPlaying.paused,
                  onTap: () => onPlayAt(songs, index),
                  onLongPress: () => onActions(song),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: TakiSpacing.sm),
      ],
    );
  }
}
