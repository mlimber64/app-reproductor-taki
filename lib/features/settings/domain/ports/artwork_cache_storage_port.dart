import '../entities/storage_usage.dart';

/// The on-disk artwork cache (files used by the notification and lock screen).
///
/// Its contents are always regenerable: clearing it never loses user data.
abstract interface class ArtworkCacheStoragePort {
  Future<StorageUsage> usage();

  /// Deletes every cached artwork file. Returns how much was freed. Files that
  /// cannot be deleted are skipped; it never throws.
  Future<StorageUsage> clear();
}
