import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/entities/catalog_search.dart';
import 'package:taki/core/domain/entities/catalog_section.dart';
import 'package:taki/features/search/domain/usecases/get_featured_songs.dart';

import '../../helpers/catalog_fakes.dart';

void main() {
  const section = CatalogSection.popularThisWeek;

  test('asks the source for the section with the configured limit', () async {
    final browse = FakeCatalogBrowse();

    await GetFeaturedSongs(browse, limit: 8)(CatalogSection.newReleases);

    expect(browse.calls, [CatalogSection.newReleases]);
    expect(browse.limits, [8]);
  });

  test('returns provider-neutral items in the source order', () async {
    final browse = FakeCatalogBrowse((_, _) async => fakePage(3));

    final items = await GetFeaturedSongs(browse)(section);

    expect([for (final i in items) i.song.title], ['T1', 'T2', 'T3']);
  });

  test('keeps the attribution that travels with each song', () async {
    final browse =
        FakeCatalogBrowse((_, _) async => fakePage(2, attributedOnly: {2}));

    final items = await GetFeaturedSongs(browse)(section);

    expect(items[0].attribution, isNull);
    expect(items[1].attribution?.licenseName, 'CC BY 4.0');
  });

  test('drops repeated songs, keeping the first occurrence', () async {
    final browse = FakeCatalogBrowse((_, _) async {
      final a = fakePage(2);
      return CatalogSearchPage([...a.songs, a.songs.first], hasMore: false);
    });

    final items = await GetFeaturedSongs(browse)(section);

    expect(items, hasLength(2));
  });

  test('a section the source cannot answer is an empty list, not an error',
      () async {
    final browse = FakeCatalogBrowse((_, _) async => fakePage(0));

    expect(await GetFeaturedSongs(browse)(section), isEmpty);
  });

  test('source failures propagate as CatalogSearchFailure', () async {
    final browse = FakeCatalogBrowse(
      (_, _) async =>
          throw const CatalogSearchFailure('down', source: 'fake'),
    );

    await expectLater(
      GetFeaturedSongs(browse)(section),
      throwsA(isA<CatalogSearchFailure>()),
    );
  });

  test('an unexpected error is translated without technology details',
      () async {
    final browse = FakeCatalogBrowse((_, _) async => throw StateError('boom'));

    await expectLater(
      GetFeaturedSongs(browse)(section),
      throwsA(
        isA<CatalogSearchFailure>()
            .having((e) => e.message, 'message', isNot(contains('boom'))),
      ),
    );
  });
}
