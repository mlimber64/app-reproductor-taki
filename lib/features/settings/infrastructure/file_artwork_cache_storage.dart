import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/entities/storage_usage.dart';
import '../domain/ports/artwork_cache_storage_port.dart';

/// [ArtworkCacheStoragePort] over the `artwork` folder of the temporary
/// directory, the same place `ArtworkFileCache` writes to.
class FileArtworkCacheStorage implements ArtworkCacheStoragePort {
  FileArtworkCacheStorage({Future<Directory> Function()? cacheDirectory})
      : _cacheDirectory = cacheDirectory ?? getTemporaryDirectory;

  final Future<Directory> Function() _cacheDirectory;

  Future<Directory> _artworkDirectory() async =>
      Directory('${(await _cacheDirectory()).path}/artwork');

  @override
  Future<StorageUsage> usage() async {
    try {
      final directory = await _artworkDirectory();
      if (!await directory.exists()) return StorageUsage.empty;

      var bytes = 0;
      var files = 0;
      await for (final entity in directory.list()) {
        if (entity is! File) continue;
        try {
          bytes += await entity.length();
          files++;
        } catch (_) {
          // The file vanished between listing and measuring: ignore it.
        }
      }
      return StorageUsage(bytes: bytes, fileCount: files);
    } catch (_) {
      return StorageUsage.empty;
    }
  }

  @override
  Future<StorageUsage> clear() async {
    var bytes = 0;
    var files = 0;
    try {
      final directory = await _artworkDirectory();
      if (!await directory.exists()) return StorageUsage.empty;

      await for (final entity in directory.list()) {
        if (entity is! File) continue;
        try {
          final length = await entity.length();
          await entity.delete();
          bytes += length;
          files++;
        } catch (_) {
          // In use or already gone: skip it, it will be regenerated.
        }
      }
    } catch (_) {
      // Report what was freed so far.
    }
    return StorageUsage(bytes: bytes, fileCount: files);
  }
}
