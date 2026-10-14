import 'package:taki/features/settings/domain/entities/app_info.dart';
import 'package:taki/features/settings/domain/entities/storage_usage.dart';
import 'package:taki/features/settings/domain/ports/app_info_port.dart';
import 'package:taki/features/settings/domain/ports/artwork_cache_storage_port.dart';

const testAppInfo = AppInfo(
  name: 'Taki',
  version: '1.2.3',
  buildNumber: '45',
  platform: 'Android 16 (API 36)',
);

class FakeAppInfo implements AppInfoPort {
  FakeAppInfo([this.info = testAppInfo]);

  final AppInfo info;

  @override
  Future<AppInfo> read() async => info;
}

/// In-memory artwork cache: [clear] frees everything it held.
class FakeArtworkCacheStorage implements ArtworkCacheStoragePort {
  FakeArtworkCacheStorage([this.current = StorageUsage.empty]);

  StorageUsage current;
  int clearCalls = 0;

  @override
  Future<StorageUsage> usage() async => current;

  @override
  Future<StorageUsage> clear() async {
    clearCalls++;
    final freed = current;
    current = StorageUsage.empty;
    return freed;
  }
}
