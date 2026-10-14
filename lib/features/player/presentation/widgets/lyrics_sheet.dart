import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/lyrics.dart';
import '../../../../core/domain/entities/song.dart';
import '../../../../core/lyrics/lyrics_providers.dart';
import '../../../../core/theme/taki_colors.dart';
import '../../../../core/theme/taki_spacing.dart';
import '../../../../core/theme/taki_typography.dart';
import '../../../../core/widgets/taki_button.dart';
import '../providers/player_providers.dart';

/// Texts of the lyrics screen.
abstract final class LyricsTexts {
  static const String title = 'Letra';
  static const String loading = 'Buscando la letra';
  static const String notFound = 'No encontramos la letra de esta canción.';
  static const String instrumental = 'Esta canción es instrumental.';
  static const String failed = 'No pudimos consultar la letra.';
  static const String retry = 'Reintentar';
  static const String credit =
      'Letra de LRCLIB, consultada con el título y el artista de la canción.';
}

/// The query for [song]. A song with no title cannot be looked up.
LyricsQuery lyricsQueryFor(Song song) => LyricsQuery(
      title: song.title,
      artist: song.artist,
      durationSeconds:
          song.durationMs > 0 ? (song.durationMs / 1000).round() : null,
    );

/// Opens the lyrics of [song]. The lookup happens here, when the user asks.
Future<void> showLyricsSheet(BuildContext context, Song song) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: TakiColors.surfaceElevated,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => LyricsSheet(song: song),
  );
}

class LyricsSheet extends ConsumerWidget {
  const LyricsSheet({super.key, required this.song});

  final Song song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = lyricsQueryFor(song);
    final lyrics = ref.watch(lyricsProvider(query));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TakiSpacing.pageGutter,
              0,
              TakiSpacing.pageGutter,
              TakiSpacing.sm,
            ),
            child: Semantics(
              header: true,
              child: Text(
                LyricsTexts.title,
                style: TakiTypography.titleMedium.copyWith(
                  color: TakiColors.textPrimary,
                ),
              ),
            ),
          ),
          Expanded(
            child: lyrics.when(
              loading: () => const _Message(
                text: LyricsTexts.loading,
                progress: true,
              ),
              error: (_, _) => _Message(
                text: LyricsTexts.failed,
                action: TakiButton(
                  label: LyricsTexts.retry,
                  variant: TakiButtonVariant.secondary,
                  onPressed: () => ref.invalidate(lyricsProvider(query)),
                ),
              ),
              data: (value) {
                if (value == null || (!value.hasContent && !value.instrumental)) {
                  return const _Message(text: LyricsTexts.notFound);
                }
                if (value.instrumental) {
                  return const _Message(text: LyricsTexts.instrumental);
                }
                return value.isSynced
                    ? _SyncedLyrics(
                        lyrics: value,
                        scrollController: scrollController,
                      )
                    : _PlainLyrics(
                        text: value.text!,
                        scrollController: scrollController,
                      );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TakiSpacing.pageGutter,
              TakiSpacing.xs,
              TakiSpacing.pageGutter,
              TakiSpacing.md,
            ),
            child: Text(
              LyricsTexts.credit,
              style: TakiTypography.caption.copyWith(
                color: TakiColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.progress = false, this.action});

  final String text;
  final bool progress;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TakiSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (progress) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: TakiSpacing.md),
            ],
            Text(
              text,
              textAlign: TextAlign.center,
              style: TakiTypography.bodyLarge.copyWith(
                color: TakiColors.textSecondary,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: TakiSpacing.md),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class _PlainLyrics extends StatelessWidget {
  const _PlainLyrics({required this.text, required this.scrollController});

  final String text;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: TakiSpacing.pageGutterImmersive,
        vertical: TakiSpacing.md,
      ),
      child: Text(
        text,
        style: TakiTypography.bodyLarge.copyWith(
          color: TakiColors.textPrimary,
          height: 1.6,
        ),
      ),
    );
  }
}

/// Timed lyrics: the line being sung is highlighted and kept in view, and
/// tapping a line seeks the song there.
class _SyncedLyrics extends ConsumerStatefulWidget {
  const _SyncedLyrics({required this.lyrics, required this.scrollController});

  final Lyrics lyrics;
  final ScrollController scrollController;

  @override
  ConsumerState<_SyncedLyrics> createState() => _SyncedLyricsState();
}

class _SyncedLyricsState extends ConsumerState<_SyncedLyrics> {
  late final List<GlobalKey> _keys = [
    for (final _ in widget.lyrics.lines) GlobalKey(),
  ];
  int _current = -1;

  void _follow(int index) {
    if (index < 0 || index >= _keys.length) return;
    final context = _keys[index].currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      alignment: 0.4,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final index = widget.lyrics.indexAt(position);
    if (index != _current) {
      _current = index;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _follow(index);
      });
    }

    final lines = widget.lyrics.lines;
    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: TakiSpacing.pageGutterImmersive,
        vertical: TakiSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lines.length; i++)
            _Line(
              key: _keys[i],
              text: lines[i].text,
              active: i == index,
              onTap: () => ref.read(seekProvider).call(lines[i].time),
            ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    super.key,
    required this.text,
    required this.active,
    required this.onTap,
  });

  final String text;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // An empty line is an instrumental pause: it keeps its space.
    final shown = text.isEmpty ? '♪' : text;
    return Semantics(
      button: true,
      selected: active,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: TakiSpacing.sm),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TakiTypography.headline.copyWith(
              fontSize: 22,
              color: active ? TakiColors.textPrimary : TakiColors.textMuted,
            ),
            child: Text(shown),
          ),
        ),
      ),
    );
  }
}
