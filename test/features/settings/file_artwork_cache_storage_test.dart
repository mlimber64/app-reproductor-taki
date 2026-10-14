import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taki/features/settings/domain/entities/storage_usage.dart';
import 'package:taki/features/settings/infrastructure/file_artwork_cache_storage.dart';

void main() {
  late Directory root;
  late FileArtworkCacheStorage storage;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('taki_artwork_cache_test');
    storage = FileArtworkCacheStorage(cacheDirectory: () async => root);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<void> seed(Map<String, int> files) async {
    final dir = Directory('${root.path}/artwork')..createSync(recursive: true);
    for (final entry in files.entries) {
      File('${dir.path}/${entry.key}')
          .writeAsBytesSync(List.filled(entry.value, 1));
    }
  }

  test('a missing folder is an empty cache', () async {
    expect(await storage.usage(), StorageUsage.empty);
    expect(await storage.clear(), StorageUsage.empty);
  });

  test('usage counts the files and their bytes', () async {
    await seed({'a.jpg': 100, 'b.img': 250});

    expect(
      await storage.usage(),
      const StorageUsage(bytes: 350, fileCount: 2),
    );
  });

  test('clear deletes every file and reports what was freed', () async {
    await seed({'a.jpg': 100, 'b.img': 250});

    final freed = await storage.clear();

    expect(freed, const StorageUsage(bytes: 350, fileCount: 2));
    expect(await storage.usage(), StorageUsage.empty);
    expect(Directory('${root.path}/artwork').existsSync(), isTrue);
  });

  test('clear leaves files outside the artwork folder untouched', () async {
    await seed({'a.jpg': 100});
    final other = File('${root.path}/keep.txt')..writeAsStringSync('keep');

    await storage.clear();

    expect(other.existsSync(), isTrue);
  });
}
