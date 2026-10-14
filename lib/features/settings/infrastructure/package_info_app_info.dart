import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../domain/entities/app_info.dart';
import '../domain/ports/app_info_port.dart';

/// [AppInfoPort] over `package_info_plus` and `device_info_plus`.
class PackageInfoAppInfo implements AppInfoPort {
  const PackageInfoAppInfo();

  static const String _unknown = 'unknown';

  @override
  Future<AppInfo> read() async {
    var name = 'Taki';
    var version = _unknown;
    var build = '';
    try {
      final package = await PackageInfo.fromPlatform();
      if (package.appName.trim().isNotEmpty) name = package.appName;
      version = package.version;
      build = package.buildNumber;
    } catch (_) {
      // Keep the placeholders: the About section must still render.
    }

    var platform = _unknown;
    try {
      final android = await DeviceInfoPlugin().androidInfo;
      platform = 'Android ${android.version.release} '
          '(API ${android.version.sdkInt})';
    } catch (_) {
      // Keep the placeholder.
    }

    return AppInfo(
      name: name,
      version: version,
      buildNumber: build,
      platform: platform,
    );
  }
}
