import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/entities/catalog_search.dart';
import 'package:taki/core/domain/entities/catalog_section.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/features/jamendo/domain/entities/jamendo_exception.dart';
import 'package:taki/features/jamendo/domain/entities/jamendo_track.dart';
import 'package:taki/features/jamendo/domain/ports/jamendo_api.dart';
import 'package:taki/features/jamendo/domain/services/jamendo_catalog_browse.dart';

import '../../helpers/jamendo_fakes.dart';

void main() {
  late FakeJamendoApi api;
  late JamendoCatalogBrowse browse;

  setUp(() {
    api = FakeJamendoApi(tracks: [
      buildTrack('1', name: 'Uno'),
      buildTrack('2', name: 'Dos'),
    ]);
    browse = JamendoCatalogBrowse(api);
  });

  group('each section maps to one listing', () {
    test('popular this week', () async {
      await browse.section(CatalogSection.popularThisWeek, limit: 12);

      expect(api.listArgs.single, {
        'order': JamendoTrackOrder.popularityWeek,
        'tag': null,
        'limit': 12,
        'offset': 0,
      });
    });

    test('popular this month', () async {
      await browse.section(CatalogSection.popularThisMonth);

      expect(api.listArgs.single['order'], JamendoTrackOrder.popularityMonth);
      expect(api.listArgs.single['tag'], isNull);
    });

    test('new releases', () async {
      await browse.section(CatalogSection.newReleases);

      expect(api.listArgs.single['order'], JamendoTrackOrder.releaseDateDesc);
      expect(api.listArgs.single['tag'], isNull);
    });

    test('a genre is the weekly popularity of its tag', () async {
      await browse.section(CatalogSection.genre('rock'));

      expect(api.listArgs.single['order'], JamendoTrackOrder.popularityWeek);
      expect(api.listArgs.single['tag'], 'rock');
    });

    test('none of them goes through search', () async {
      await browse.section(CatalogSection.newReleases);

      expect(api.searchCalls, 0);
      expect(api.listCalls, 1);
    });
  });

  test('maps tracks to universal songs keeping the API order', () async {
    final page = await browse.section(CatalogSection.popularThisWeek);

    expect([for (final s in page.songs) s.title], ['Uno', 'Dos']);
    expect(page.songs.first.musicIdentity, MusicIdentity(jamendoSource, '1'));
  });

  test('carries each track attribution by identity', () async {
    final page = await browse.section(CatalogSection.popularThisWeek);

    final attribution = page.attributionOf(page.songs.first);
    expect(attribution?.providerName, jamendoProviderName);
    expect(attribution?.licenseName, 'CC BY-NC-ND 3.0');
  });

  test('forwards hasMore from the API', () async {
    api.hasMore = true;

    expect(
      (await browse.section(CatalogSection.popularThisWeek)).hasMore,
      isTrue,
    );
  });

  test('API failures become CatalogSearchFailure without the cause text',
      () async {
    api.error = const JamendoNetworkException('HTTP 500', statusCode: 500);

    await expectLater(
      browse.section(CatalogSection.popularThisWeek),
      throwsA(
        isA<CatalogSearchFailure>()
            .having((e) => e.source, 'source', jamendoSource)
            .having((e) => e.message, 'message', isNot(contains('500'))),
      ),
    );
  });

  test('rejects a non-positive limit', () {
    expect(
      () => browse.section(CatalogSection.popularThisWeek, limit: 0),
      throwsArgumentError,
    );
  });
}
