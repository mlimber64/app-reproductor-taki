import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taki/app/theme/app_theme.dart';
import 'package:taki/core/artwork/artwork_providers.dart';
import 'package:taki/core/domain/entities/song.dart';
import 'package:taki/core/widgets/taki_song_card.dart';
import 'package:taki/features/library/presentation/providers/history_providers.dart';
import 'package:taki/features/library/presentation/widgets/recently_played_section.dart';

import '../../helpers/library_fakes.dart';

void main() {
  Future<List<(List<Song>, int)>> pump(
    WidgetTester tester,
    AsyncValue<List<Song>> songs,
  ) async {
    final plays = <(List<Song>, int)>[];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        artworkRepositoryProvider.overrideWithValue(NoArtworkRepository()),
        recentSongsProvider.overrideWith((ref) async {
          return switch (songs) {
            AsyncData(:final value) => value,
            AsyncError(:final error) => throw error,
            _ => await Future<List<Song>>.delayed(const Duration(hours: 1)),
          };
        }),
      ],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: RecentlyPlayedSection(
            currentIdentity: null,
            isPlaying: false,
            onPlayAt: (list, index) async => plays.add((list, index)),
            onActions: (_) async {},
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();
    return plays;
  }

  testWidgets('shows the recent songs as cards under its title',
      (tester) async {
    await pump(tester, AsyncData([buildSong(id: 1), buildSong(id: 2)]));

    expect(find.text(RecentlyPlayedSection.title), findsOneWidget);
    expect(find.byType(TakiSongCard), findsNWidgets(2));
  });

  testWidgets('takes no space when there is no history', (tester) async {
    await pump(tester, const AsyncData(<Song>[]));

    expect(find.text(RecentlyPlayedSection.title), findsNothing);
    expect(find.byType(TakiSongCard), findsNothing);
  });

  testWidgets('a history that cannot be read is simply not shown',
      (tester) async {
    await pump(tester, AsyncError(StateError('db'), StackTrace.empty));

    expect(find.text(RecentlyPlayedSection.title), findsNothing);
  });

  testWidgets('tapping a card plays the list from that card', (tester) async {
    final plays = await pump(
      tester,
      AsyncData([buildSong(id: 1, title: 'Alpha'), buildSong(id: 2, title: 'Beta')]),
    );

    await tester.tap(find.text('Beta'));
    await tester.pump();

    expect(plays.single.$1.map((s) => s.title), ['Alpha', 'Beta']);
    expect(plays.single.$2, 1);
  });
}
