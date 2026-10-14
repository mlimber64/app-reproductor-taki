import '../entities/app_info.dart';

/// Reads the facts of the installed app. Never throws: an unavailable value
/// is reported with a neutral placeholder instead of an error.
abstract interface class AppInfoPort {
  Future<AppInfo> read();
}
