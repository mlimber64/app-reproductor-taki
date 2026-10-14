import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taki/app/theme/app_theme.dart';
import 'package:taki/core/artwork/artwork_providers.dart';
import 'package:taki/core/domain/entities/catalog_search.dart';
import 'package:taki/core/domain/entities/catalog_section.dart';
import 'package:taki/core/domain/entities/song.dart';
import 'package:taki/core/widgets/taki_song_card.dart';
import 'package:taki/core/widgets/taki_song_tile.dart';
import 'package:taki/features/player/presentation/providers/player_providers.dart';
import 'package:taki/features/search/presentation/pages/search_page.dart';
import 'package:taki/features/search/presentation/search_texts.dart';

import '../../../helpers/catalog_fakes.dart';
import '../../../helpers/library_fakes.dart';
import '../../../helpers/player_fakes.dart';

const _debounce = Duration(milliseconds: 400);

/// Every section answers with ids of its own so tests can tell carousels
/// apart: week 1…6, month 11…16, new releases 21…26, genres 31…36.
CatalogSearchPage _pageFor(CatalogSection section) {
  final from = switch (section.kind) {
    CatalogSectionKind.popularThisWeek => 1,
    CatalogSectionKind.popularThisMonth => 11,
    CatalogSectionKind.newReleases => 21,
    CatalogSectionKind.genre => 31,
  };
  return fakePage(6, from: from);
}

void main() {
  late FakeCatalogSearch search;
  late FakeCatalogBrowse browse;
  late ManualSearchScheduler clock;
  late FakeAudioPlayerPort player;
  late FakeNotificationPermission notifications;
  late MockPlaySongs playSongs;
  late ProviderContainer container;
  late List<Song> actionSongs;

  setUpAll(() => registerFallbackValue(<Song>[]));

  setUp(() {
    actionSongs = [];
    search = FakeCatalogSearch((_) async => fakePage(3));
    browse = FakeCatalogBrowse((section, _) async => _pageFor(section));
    clock = ManualSearchScheduler();
    player = FakeAudioPlayerPort();
    notifications = FakeNotificationPermission();
    playSongs = MockPlaySongs();
    when(() => playSongs(any(), any())).thenAnswer((_) async {});
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    bool withBrowse = true,
    double textScale = 1,
    Size size = const Size(412, 915),
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    container = catalogContainer(
      search: search,
      browse: withBrowse ? browse : null,
      scheduler: clock,
      overrides: [
        artworkRepositoryProvider.overrideWithValue(NoArtworkRepository()),
        audioPlayerPortProvider.overrideWithValue(player),
        notificationPermissionProvider.overrideWithValue(notifications),
        playSongsProvider.overrideWithValue(playSongs),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: SearchPage(
            onSongActions: (context, ref, song, {extraActions = const []}) async {
              actionSongs.add(song);
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows the first carousels as cover cards before searching',
      (tester) async {
    await pumpPage(tester);

    expect(find.text('Populares esta semana'), findsOneWidget);
    expect(find.text('Más escuchadas del mes'), findsOneWidget);
    expect(find.text('Novedades'), findsOneWidget);
    expect(find.byType(TakiSongCard), findsWidgets);
    expect(find.text(SearchTexts.idleTitle), findsNothing);
  });

  testWidgets('carousels are stacked vertically in order', (tester) async {
    await pumpPage(tester);

    final week = tester.getTopLeft(find.text('Populares esta semana')).dy;
    final month = tester.getTopLeft(find.text('Más escuchadas del mes')).dy;
    final fresh = tester.getTopLeft(find.text('Novedades')).dy;

    expect(month, greaterThan(week));
    expect(fresh, greaterThan(month));
  });

  testWidgets('sections load lazily: only the visible ones are requested',
      (tester) async {
    await pumpPage(tester);

    expect(browse.calls, contains(CatalogSection.popularThisWeek));
    expect(browse.calls.length, lessThan(9));
    expect(browse.calls, isNot(contains(CatalogSection.genre('chillout'))));
  });

  testWidgets('scrolling down loads the genre carousels', (tester) async {
    await pumpPage(tester);
    final before = browse.calls.length;

    await tester.fling(find.byType(ListView).first, const Offset(0, -2500), 2500);
    await tester.pumpAndSettle();

    expect(browse.calls.length, greaterThan(before));
    expect(browse.calls, contains(CatalogSection.genre('rock')));
  });

  testWidgets('a carousel scrolls horizontally to reveal more songs',
      (tester) async {
    await pumpPage(tester);
    expect(find.text('T6'), findsNothing, reason: 'off screen, not built yet');

    final firstRow = find.descendant(
      of: find.byType(ListView).first,
      matching: find.byType(ListView),
    ).first;
    await tester.drag(firstRow, const Offset(-900, 0));
    await tester.pumpAndSettle();

    expect(find.text('T6'), findsOneWidget);
  });

  testWidgets('without a browsable source it keeps the plain idle view',
      (tester) async {
    await pumpPage(tester, withBrowse: false);

    expect(find.text(SearchTexts.idleTitle), findsOneWidget);
    expect(find.byType(TakiSongCard), findsNothing);
    expect(browse.calls, isEmpty);
  });

  testWidgets('an empty first carousel falls back to the idle view',
      (tester) async {
    browse.handler = (_, _) async => fakePage(0);

    await pumpPage(tester);

    expect(find.text(SearchTexts.idleTitle), findsOneWidget);
    expect(find.byType(TakiSongCard), findsNothing);
  });

  testWidgets('tapping a card plays that carousel from that card',
      (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('T2'));
    await tester.pump();

    final captured =
        verify(() => playSongs(captureAny(), captureAny())).captured;
    final songs = captured[0] as List<Song>;
    expect(songs.map((s) => s.title), ['T1', 'T2', 'T3', 'T4', 'T5', 'T6']);
    expect(captured[1], 1);
  });

  testWidgets('a card of another carousel plays that carousel\'s list',
      (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('T12'));
    await tester.pump();

    final captured =
        verify(() => playSongs(captureAny(), captureAny())).captured;
    final songs = captured[0] as List<Song>;
    expect(songs.first.title, 'T11');
    expect(captured[1], 1);
  });

  testWidgets('long press opens the song actions with the same song',
      (tester) async {
    await pumpPage(tester);

    await tester.longPress(find.text('T3'));
    await tester.pump();

    expect(actionSongs.map((s) => s.title), ['T3']);
  });

  testWidgets('while a carousel loads it shows placeholders', (tester) async {
    final pending = Completer<CatalogSearchPage>();
    browse.handler = (section, _) => section == CatalogSection.popularThisMonth
        ? pending.future
        : Future.value(_pageFor(section));

    await pumpPage(tester);

    expect(find.text('Más escuchadas del mes'), findsOneWidget);
    expect(find.bySemanticsLabel(SearchTexts.featuredLoading), findsOneWidget);
    expect(find.text('T11'), findsNothing);

    pending.complete(_pageFor(CatalogSection.popularThisMonth));
    await tester.pump();
    await tester.pump();
    expect(find.text('T11'), findsOneWidget);
  });

  testWidgets('one failing carousel does not affect the others',
      (tester) async {
    browse.handler = (section, _) async {
      if (section == CatalogSection.popularThisMonth) {
        throw const CatalogSearchFailure('down', source: fakeCatalogSource);
      }
      return _pageFor(section);
    };

    await pumpPage(tester);

    expect(find.text(SearchTexts.featuredSectionFailed), findsOneWidget);
    expect(find.text('T1'), findsOneWidget, reason: 'the week still shows');
    expect(find.text('T21'), findsOneWidget, reason: 'new releases too');
  });

  testWidgets('retrying a failed carousel reloads only that one',
      (tester) async {
    var monthAttempts = 0;
    browse.handler = (section, _) async {
      if (section == CatalogSection.popularThisMonth && ++monthAttempts == 1) {
        throw const CatalogSearchFailure('down', source: fakeCatalogSource);
      }
      return _pageFor(section);
    };

    await pumpPage(tester);
    final weekCalls = browse.calls
        .where((s) => s == CatalogSection.popularThisWeek)
        .length;

    await tester.tap(find.text(SearchTexts.retry));
    await tester.pump();
    await tester.pump();

    expect(find.text(SearchTexts.featuredSectionFailed), findsNothing);
    expect(find.text('T11'), findsOneWidget);
    expect(
      browse.calls.where((s) => s == CatalogSection.popularThisWeek).length,
      weekCalls,
      reason: 'the week was not asked again',
    );
  });

  testWidgets('searching replaces the carousels with the results and clearing '
      'brings them back without reloading', (tester) async {
    await pumpPage(tester);
    final loaded = browse.calls.length;

    await tester.enterText(find.byType(TextField), 'rock');
    await tester.pump();
    clock.advance(_debounce);
    await tester.pump();
    await tester.pump();

    expect(find.byType(TakiSongCard), findsNothing);
    expect(find.byType(TakiSongTile), findsWidgets);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    await tester.pump();

    expect(find.byType(TakiSongCard), findsWidgets);
    expect(browse.calls.length, loaded, reason: 'sections are kept');
  });

  testWidgets('does not overflow at 150 % text or on a small screen',
      (tester) async {
    await pumpPage(tester, textScale: 1.5, size: const Size(360, 640));

    expect(tester.takeException(), isNull);
    expect(find.byType(TakiSongCard), findsWidgets);
  });
}
