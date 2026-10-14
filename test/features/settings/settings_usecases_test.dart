import 'package:flutter_test/flutter_test.dart';
import 'package:taki/features/settings/domain/entities/storage_usage.dart';
import 'package:taki/features/settings/domain/usecases/settings_usecases.dart';

import '../../helpers/settings_fakes.dart';

void main() {
  test('displayVersion includes the build number when there is one', () {
    expect(testAppInfo.displayVersion, '1.2.3 (45)');
  });

  test('GetArtworkCacheUsage reads from the storage', () async {
    final storage = FakeArtworkCacheStorage(
      const StorageUsage(bytes: 4000, fileCount: 2),
    );
    expect(
      await GetArtworkCacheUsage(storage)(),
      const StorageUsage(bytes: 4000, fileCount: 2),
    );
  });

  test('ClearArtworkCache empties the storage and reports what was freed',
      () async {
    final storage = FakeArtworkCacheStorage(
      const StorageUsage(bytes: 4000, fileCount: 2),
    );

    final freed = await ClearArtworkCache(storage)();

    expect(freed, const StorageUsage(bytes: 4000, fileCount: 2));
    expect(await storage.usage(), StorageUsage.empty);
  });

  test('the diagnostics report holds only app facts and counters', () {
    final report = buildDiagnosticsReport(
      info: testAppInfo,
      catalogSources: const ['Jamendo'],
      libraryStatus: '98 songs',
      artworkCache: const StorageUsage(bytes: 4000, fileCount: 2),
      artworkCacheSize: '4 kB',
    );

    expect(report, '''
Taki 1.2.3 (45)
Platform: Android 16 (API 36)
Library: 98 songs
Online catalogs: Jamendo
Artwork cache: 2 files, 4 kB''');
  });

  test('the report says "none" when there are no online catalogs', () {
    final report = buildDiagnosticsReport(
      info: testAppInfo,
      catalogSources: const [],
      libraryStatus: 'empty',
      artworkCache: StorageUsage.empty,
      artworkCacheSize: '0 B',
    );
    expect(report, contains('Online catalogs: none'));
  });
}
