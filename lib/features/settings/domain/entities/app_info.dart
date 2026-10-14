/// Static facts about the installed app and the device it runs on.
///
/// Plain data for the About section and the diagnostics report. It carries no
/// identifiers of the user, their account or their library.
class AppInfo {
  const AppInfo({
    required this.name,
    required this.version,
    required this.buildNumber,
    required this.platform,
  });

  final String name;

  /// Human readable version (`1.0.0`).
  final String version;

  /// Build number (`1`); empty when the platform does not report one.
  final String buildNumber;

  /// Device and OS summary, e.g. `Android 16 (API 36)`.
  final String platform;

  /// `1.0.0 (1)`, or just the version when there is no build number.
  String get displayVersion =>
      buildNumber.isEmpty ? version : '$version ($buildNumber)';
}
