import 'package:equatable/equatable.dart';

/// One timed line of a song's lyrics.
class LyricLine extends Equatable {
  const LyricLine(this.time, this.text);

  final Duration time;
  final String text;

  @override
  List<Object?> get props => [time, text];
}

/// The lyrics of a song: timed [lines], plain [text], or both.
///
/// Instrumental tracks have neither and say so with [instrumental].
class Lyrics extends Equatable {
  const Lyrics({
    this.lines = const [],
    this.text,
    this.instrumental = false,
  });

  /// Lines with their start time, in order. Empty when the lyrics are not
  /// synchronized.
  final List<LyricLine> lines;

  /// The same lyrics without timing, when the provider has them.
  final String? text;

  final bool instrumental;

  bool get isSynced => lines.isNotEmpty;

  bool get hasContent => isSynced || (text?.trim().isNotEmpty ?? false);

  /// Index of the line being sung at [position]: the last one that has
  /// started. `-1` before the first line (or when there are no timed lines).
  int indexAt(Duration position) {
    var low = 0;
    var high = lines.length - 1;
    var found = -1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      if (lines[mid].time <= position) {
        found = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return found;
  }

  @override
  List<Object?> get props => [lines, text, instrumental];
}

/// What identifies a song to a lyrics provider. Equal queries are the same
/// request, so it is usable as a cache key.
class LyricsQuery extends Equatable {
  const LyricsQuery({
    required this.title,
    this.artist,
    this.durationSeconds,
  });

  final String title;
  final String? artist;
  final int? durationSeconds;

  @override
  List<Object?> get props => [title, artist, durationSeconds];
}

/// The lyrics provider could not be reached or answered something unusable.
/// "No lyrics for this song" is not a failure: it is a `null` result.
final class LyricsLookupFailure implements Exception {
  const LyricsLookupFailure(this.message);

  final String message;

  @override
  String toString() => 'LyricsLookupFailure($message)';
}
