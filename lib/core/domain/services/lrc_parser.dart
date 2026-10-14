import '../entities/lyrics.dart';

final RegExp _timestamp = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');
final RegExp _leadingTimestamps = RegExp(r'^\s*((?:\[\d{1,3}:\d{2}(?:[.:]\d{1,3})?\])+)(.*)$');

/// Parses synchronized lyrics in LRC format into timed lines.
///
/// - A line may carry several timestamps (`[00:10.00][01:20.00] chorus`): it
///   becomes one line per timestamp.
/// - Metadata tags (`[ar:...]`, `[ti:...]`, `[offset:...]`) and lines without a
///   timestamp are ignored.
/// - The result is sorted by time (stable for equal times).
/// - Empty text is kept: it is how LRC marks an instrumental pause, and the UI
///   uses it to clear the highlighted line.
List<LyricLine> parseLrc(String source) {
  final lines = <LyricLine>[];
  for (final raw in source.split(RegExp(r'\r?\n'))) {
    final match = _leadingTimestamps.firstMatch(raw);
    if (match == null) continue;
    final text = match.group(2)!.trim();
    for (final stamp in _timestamp.allMatches(match.group(1)!)) {
      final minutes = int.parse(stamp.group(1)!);
      final seconds = int.parse(stamp.group(2)!);
      final fraction = stamp.group(3);
      final millis = fraction == null
          ? 0
          : int.parse(fraction.padRight(3, '0').substring(0, 3));
      lines.add(LyricLine(
        Duration(minutes: minutes, seconds: seconds, milliseconds: millis),
        text,
      ));
    }
  }
  // `List.sort` is not stable: keep the file order for equal times.
  final indexed = [for (var i = 0; i < lines.length; i++) (i, lines[i])];
  indexed.sort((a, b) {
    final byTime = a.$2.time.compareTo(b.$2.time);
    return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
  });
  return [for (final entry in indexed) entry.$2];
}
