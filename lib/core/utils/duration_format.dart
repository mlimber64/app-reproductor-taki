/// Duración de una pista: `m:ss`, o `h:mm:ss` a partir de una hora.
String formatTrackDuration(Duration duration) {
  final totalSeconds = duration.isNegative ? 0 : duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');

  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
  }
  return '$minutes:$seconds';
}

/// Duración total legible: `2 h 05 min`, `42 min` o `45 s`.
String formatTotalDuration(Duration duration) {
  final totalSeconds = duration.isNegative ? 0 : duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;

  if (hours > 0) return '$hours h ${minutes.toString().padLeft(2, '0')} min';
  if (minutes > 0) return '$minutes min';
  return '$totalSeconds s';
}

/// Resumen de una lista: `1 canción · 3 min`, `12 canciones · 1 h 05 min`.
String formatSongsSummary(int count, Duration total) {
  if (count == 0) return '0 canciones';
  final songs = count == 1 ? '1 canción' : '$count canciones';
  return '$songs · ${formatTotalDuration(total)}';
}
