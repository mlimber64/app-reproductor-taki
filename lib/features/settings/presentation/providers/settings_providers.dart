import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/app_info.dart';
import '../../domain/entities/storage_usage.dart';
import '../../domain/ports/app_info_port.dart';
import '../../domain/ports/artwork_cache_storage_port.dart';
import '../../domain/usecases/settings_usecases.dart';
import '../../infrastructure/file_artwork_cache_storage.dart';
import '../../infrastructure/package_info_app_info.dart';

final appInfoPortProvider = Provider<AppInfoPort>(
  (ref) => const PackageInfoAppInfo(),
);

final artworkCacheStorageProvider = Provider<ArtworkCacheStoragePort>(
  (ref) => FileArtworkCacheStorage(),
);

final getArtworkCacheUsageProvider = Provider<GetArtworkCacheUsage>(
  (ref) => GetArtworkCacheUsage(ref.watch(artworkCacheStorageProvider)),
);

final clearArtworkCacheProvider = Provider<ClearArtworkCache>(
  (ref) => ClearArtworkCache(ref.watch(artworkCacheStorageProvider)),
);

final appInfoProvider = FutureProvider<AppInfo>(
  (ref) => ref.watch(appInfoPortProvider).read(),
);

/// Disk used by the artwork cache. Re-read each time Settings opens.
final artworkCacheUsageProvider = FutureProvider.autoDispose<StorageUsage>(
  (ref) => ref.watch(getArtworkCacheUsageProvider).call(),
);
