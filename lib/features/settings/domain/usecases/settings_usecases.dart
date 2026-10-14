import '../entities/app_info.dart';
import '../entities/storage_usage.dart';
import '../ports/artwork_cache_storage_port.dart';

class GetArtworkCacheUsage {
  const GetArtworkCacheUsage(this._storage);

  final ArtworkCacheStoragePort _storage;

  Future<StorageUsage> call() => _storage.usage();
}

class ClearArtworkCache {
  const ClearArtworkCache(this._storage);

  final ArtworkCacheStoragePort _storage;

  /// Returns what was freed.
  Future<StorageUsage> call() => _storage.clear();
}

/// Plain-text report the user can paste into a bug report.
///
/// Only app and device facts plus counters: no song titles, paths, favorites,
/// playlist names or credentials.
String buildDiagnosticsReport({
  required AppInfo info,
  required List<String> catalogSources,
  required String libraryStatus,
  required StorageUsage artworkCache,
  required String artworkCacheSize,
}) {
  final sources = catalogSources.isEmpty ? 'none' : catalogSources.join(', ');
  return [
    '${info.name} ${info.displayVersion}',
    'Platform: ${info.platform}',
    'Library: $libraryStatus',
    'Online catalogs: $sources',
    'Artwork cache: ${artworkCache.fileCount} files, $artworkCacheSize',
  ].join('\n');
}
