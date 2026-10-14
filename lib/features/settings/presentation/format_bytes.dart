/// Human readable size using decimal units (the ones Android's own storage
/// screen shows): `0 B`, `512 B`, `1,5 kB`, `3,2 MB`.
///
/// The decimal separator is a comma, matching the app's Spanish locale.
String formatBytes(int bytes) {
  if (bytes < 1000) return '${bytes < 0 ? 0 : bytes} B';

  const units = ['kB', 'MB', 'GB', 'TB'];
  var value = bytes / 1000;
  var unit = 0;
  while (value >= 1000 && unit < units.length - 1) {
    value /= 1000;
    unit++;
  }

  final text = value >= 100
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1).replaceAll('.', ',');
  return '${text.endsWith(',0') ? text.substring(0, text.length - 2) : text} '
      '${units[unit]}';
}
