import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taki/app/theme/app_theme.dart';
import 'package:taki/core/artwork/artwork_providers.dart';
import 'package:taki/core/domain/entities/catalog_provider_info.dart';
import 'package:taki/core/domain/entities/catalog_section.dart';
import 'package:taki/core/domain/services/source_catalog_sources.dart';
import 'package:taki/features/player/presentation/providers/player_providers.dart';
import 'package:taki/features/search/presentation/pages/search_page.dart';
import 'package:taki/features/search/presentation/providers/catalog_search_providers.dart';

import '../../../helpers/catalog_fakes.dart';
import '../../../helpers/library_fakes.dart';
import '../../../helpers/player_fakes.dart';

void main() {
  late FakeCatalogSearch searchA;
  late FakeCatalogSearch searchB;
  late FakeCatalogBrowse browseA;
  late FakeCatalogBrowse browseB;
  late ManualSearchScheduler clock;
  late ProviderContainer container;

  setUp(() {
    // Source A answers T1…T3 and source B T41…T43, so a test can tell which
    // one is on screen.
    searchA = FakeCatalogSearch((_) async => fakePage(3, from: 51));
    searchB = FakeCatalogSearch((_) async => fakePage(3, from: 61));
    browseA = FakeCatalogBrowse((_, _) async => fakePage(3, from: 1));
    browseB = FakeCatalogBrowse((_, _) async => fakePage(3, from: 41));
    clock = ManualSearchScheduler();
  });

  Future<void> pumpPage(WidgetTester tester, {bool both = true}) async {
    tester.view.physicalSize = const Size(412, 915) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    container = catalogContainer(
      scheduler: clock,
      registrations: [
        CatalogSourceRegistration(
          CatalogProviderInfo(source: 'alpha', label: 'Alpha'),
          searchA,
          browse: browseA,
        ),
        if (both)
          CatalogSourceRegistration(
            CatalogProviderInfo(source: 'beta', label: 'Beta'),
            searchB,
            browse: browseB,
          ),
      ],
      overrides: [
        artworkRepositoryProvider.overrideWithValue(NoArtworkRepository()),
        audioPlayerPortProvider.overrideWithValue(FakeAudioPlayerPort()),
        notificationPermissionProvider
            .overrideWithValue(FakeNotificationPermission()),
        playSongsProvider.overrideWithValue(MockPlaySongs()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: SearchPage(
            onSongActions: (context, ref, song, {extraActions = const []}) async {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('with a single source there is nothing to pick', (tester) async {
    await pumpPage(tester, both: false);

    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets('with several sources the first one is active', (tester) async {
    await pumpPage(tester);

    expect(find.widgetWithText(ChoiceChip, 'Alpha'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Beta'), findsOneWidget);
    expect(container.read(activeCatalogSourceProvider), 'alpha');
    expect(browseA.calls, contains(CatalogSection.popularThisWeek));
    expect(browseB.calls, isEmpty);
    expect(find.text('T1'), findsWidgets);
  });

  testWidgets('picking another source loads its carousels', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Beta'));
    await tester.pump();
    await tester.pump();

    expect(container.read(activeCatalogSourceProvider), 'beta');
    expect(browseB.calls, contains(CatalogSection.popularThisWeek));
    expect(find.text('T41'), findsWidgets);
    expect(find.text('T1'), findsNothing);
  });

  testWidgets('picking a source repeats the typed search on it',
      (tester) async {
    await pumpPage(tester);
    await tester.enterText(find.byType(TextField), 'beat');
    await tester.pump();
    clock.advance(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.pump();
    expect(searchA.calls, isNotEmpty);
    expect(searchB.calls, isEmpty);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Beta'));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(searchB.calls, isNotEmpty);
    expect(find.text('T61'), findsWidgets);
    expect(find.text('T51'), findsNothing);
  });
}
