import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/artwork/album_artwork_builder.dart';
import '../../../../core/domain/entities/music_identity.dart';
import '../../../../core/domain/entities/song.dart';
import '../../../../core/theme/taki_spacing.dart';
import '../../../../core/theme/taki_typography.dart';
import '../../../../core/theme/taki_colors.dart';
import '../../../../core/widgets/taki_artwork.dart';
import '../../../../core/widgets/taki_button.dart';
import '../../../../core/widgets/taki_playing_indicator.dart';
import '../../../../core/widgets/taki_section_header.dart';
import '../../../../core/widgets/taki_song_card.dart';
import '../../domain/entities/featured_section.dart';
import '../providers/catalog_search_providers.dart';
import '../search_texts.dart';

/// What the search screen shows before a search: a vertical list of
/// carousels, each one a section of the catalog (charts, new releases,
/// genres) with its songs as cover cards.
///
/// - Every carousel loads on its own, the first time it scrolls into view, so
///   a section that fails or is slow never blocks the others.
/// - It only presents `featuredSectionSongsProvider`; it neither searches nor
///   knows which source the songs come from.
/// - When nothing can be featured it shows [fallback], the plain idle message
///   the screen always had.
class FeaturedView extends ConsumerWidget {
  FeaturedView({
    super.key,
    required this.fallback,
    required this.onPlayAt,
    required this.onActions,
    this.currentIdentity,
    this.isPlaying = false,
    List<FeaturedSection>? sections,
  }) : sections = sections ?? defaultFeaturedSections;

  final Widget fallback;
  final List<FeaturedSection> sections;

  /// Identity of the song that is playing, to mark its card; the page that
  /// owns the playback provider passes it in.
  final MusicIdentity? currentIdentity;
  final bool isPlaying;

  /// Tap on a card: play that carousel's list starting at `index`.
  final Future<void> Function(List<Song> songs, int index) onPlayAt;

  /// Long press on a card: the song actions menu.
  final Future<void> Function(Song song) onActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // No browsable source: the screen behaves exactly as before.
    if (ref.watch(featuredCatalogProvider) == null || sections.isEmpty) {
      return fallback;
    }

    // The first carousel is always built, so it also decides whether there is
    // anything to feature at all: an empty answer keeps the plain idle view.
    final first = ref.watch(
      featuredSectionSongsProvider(sections.first.section),
    );
    if (first.hasValue && first.requireValue.isEmpty) return fallback;

    return RefreshIndicator(
      onRefresh: () async {
        for (final featured in sections) {
          ref.invalidate(featuredSectionSongsProvider(featured.section));
        }
        // Wait for the visible head only; the rest reload as they are seen.
        await ref
            .read(featuredSectionSongsProvider(sections.first.section).future)
            .then<void>((_) {}, onError: (Object _) {});
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(bottom: TakiSpacing.lg),
        itemCount: sections.length,
        itemBuilder: (context, index) => _Carousel(
          featured: sections[index],
          isFirst: index == 0,
          currentIdentity: currentIdentity,
          isPlaying: isPlaying,
          onPlayAt: onPlayAt,
          onActions: onActions,
        ),
      ),
    );
  }
}

/// Metrics shared by every carousel and its skeleton.
abstract final class _CarouselMetrics {
  /// Side of one cover. Narrow enough that the next card peeks in, which
  /// tells the user the row scrolls.
  static const double cover = 148;

  static const double gap = TakiSpacing.md;

  static const int skeletonCount = 4;
}

class _Carousel extends ConsumerWidget {
  const _Carousel({
    required this.featured,
    required this.isFirst,
    required this.currentIdentity,
    required this.isPlaying,
    required this.onPlayAt,
    required this.onActions,
  });

  final FeaturedSection featured;
  final bool isFirst;
  final MusicIdentity? currentIdentity;
  final bool isPlaying;
  final Future<void> Function(List<Song> songs, int index) onPlayAt;
  final Future<void> Function(Song song) onActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(featuredSectionSongsProvider(featured.section));

    // A section that came back empty has nothing to show: no header either.
    if (songs.hasValue && songs.requireValue.isEmpty) {
      return const SizedBox.shrink();
    }

    final height =
        _CarouselMetrics.cover + TakiSongCard.textBlockHeight(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TakiSectionHeader(
          title: featured.title,
          subtitle: featured.subtitle,
          isFirst: isFirst,
        ),
        SizedBox(
          height: height,
          child: songs.when(
            loading: () => const _Skeleton(),
            error: (_, _) => _SectionError(
              onRetry: () =>
                  ref.invalidate(featuredSectionSongsProvider(featured.section)),
            ),
            data: (items) {
              final list = [for (final item in items) item.song];
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: TakiSpacing.pageGutter,
                ),
                itemCount: list.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: _CarouselMetrics.gap),
                itemBuilder: (context, index) {
                  final song = list[index];
                  return AlbumArtworkBuilder.reference(
                    reference: song.artwork,
                    size: _CarouselMetrics.cover,
                    builder: (_, artwork) => TakiSongCard(
                      song: song,
                      artworkSize: _CarouselMetrics.cover,
                      artwork: artwork,
                      playback: song.musicIdentity != currentIdentity
                          ? TakiNowPlaying.none
                          : isPlaying
                              ? TakiNowPlaying.playing
                              : TakiNowPlaying.paused,
                      onTap: () => onPlayAt(list, index),
                      onLongPress: () => onActions(song),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Placeholder covers while a carousel loads, so it does not jump when the
/// songs arrive.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: SearchTexts.featuredLoading,
      liveRegion: true,
      child: ExcludeSemantics(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: TakiSpacing.pageGutter,
          ),
          itemCount: _CarouselMetrics.skeletonCount,
          separatorBuilder: (_, _) =>
              const SizedBox(width: _CarouselMetrics.gap),
          itemBuilder: (_, _) => const Align(
            alignment: Alignment.topLeft,
            child: TakiArtwork(size: _CarouselMetrics.cover),
          ),
        ),
      ),
    );
  }
}

/// A carousel that could not load: a short message and a retry, in the space
/// the cards would take, so the other sections are untouched.
class _SectionError extends StatelessWidget {
  const _SectionError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TakiSpacing.pageGutter),
      child: Align(
        alignment: Alignment.topLeft,
        child: Row(
          children: [
            Expanded(
              child: Text(
                SearchTexts.featuredSectionFailed,
                style: TakiTypography.body.copyWith(
                  color: TakiColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: TakiSpacing.md),
            TakiButton(
              label: SearchTexts.retry,
              variant: TakiButtonVariant.tertiary,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
