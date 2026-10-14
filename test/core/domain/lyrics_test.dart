import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/entities/lyrics.dart';
import 'package:taki/core/domain/services/lrc_parser.dart';

void main() {
  group('parseLrc', () {
    test('reads timed lines', () {
      final lines = parseLrc('[00:12.50] First\n[01:05.00] Second');

      expect(lines, [
        const LyricLine(Duration(seconds: 12, milliseconds: 500), 'First'),
        const LyricLine(Duration(minutes: 1, seconds: 5), 'Second'),
      ]);
    });

    test('a line with several timestamps becomes several lines, sorted', () {
      final lines = parseLrc('[00:30.00][00:10.00] Chorus\n[00:20.00] Verse');

      expect(lines.map((l) => (l.time.inSeconds, l.text)), [
        (10, 'Chorus'),
        (20, 'Verse'),
        (30, 'Chorus'),
      ]);
    });

    test('metadata tags and untimed lines are ignored', () {
      final lines = parseLrc('[ar: Someone]\n[ti: Title]\nplain\n[00:01.00] Hi');

      expect(lines.map((l) => l.text), ['Hi']);
    });

    test('keeps empty text as an instrumental pause', () {
      final lines = parseLrc('[00:01.00] Hi\n[00:05.00]\n[00:09.00] Back');

      expect(lines.map((l) => l.text), ['Hi', '', 'Back']);
    });

    test('accepts two-digit and three-digit fractions and CRLF', () {
      final lines = parseLrc('[00:01.5] a\r\n[00:02.25] b\r\n[00:03.125] c');

      expect(lines.map((l) => l.time.inMilliseconds), [1500, 2250, 3125]);
    });

    test('equal times keep the file order', () {
      final lines = parseLrc('[00:05.00] one\n[00:05.00] two');

      expect(lines.map((l) => l.text), ['one', 'two']);
    });

    test('nothing parseable gives an empty list', () {
      expect(parseLrc(''), isEmpty);
      expect(parseLrc('just words'), isEmpty);
    });
  });

  group('Lyrics', () {
    const lyrics = Lyrics(lines: [
      LyricLine(Duration(seconds: 10), 'a'),
      LyricLine(Duration(seconds: 20), 'b'),
      LyricLine(Duration(seconds: 30), 'c'),
    ]);

    test('indexAt is -1 before the first line', () {
      expect(lyrics.indexAt(Duration.zero), -1);
      expect(lyrics.indexAt(const Duration(seconds: 9)), -1);
    });

    test('indexAt is the last line that has started', () {
      expect(lyrics.indexAt(const Duration(seconds: 10)), 0);
      expect(lyrics.indexAt(const Duration(seconds: 25)), 1);
      expect(lyrics.indexAt(const Duration(minutes: 5)), 2);
    });

    test('plain lyrics are content but not synced', () {
      const plain = Lyrics(text: 'words');

      expect(plain.isSynced, isFalse);
      expect(plain.hasContent, isTrue);
      expect(plain.indexAt(const Duration(seconds: 5)), -1);
      expect(const Lyrics().hasContent, isFalse);
    });

    test('equal queries are the same request', () {
      const a = LyricsQuery(title: 'T', artist: 'A', durationSeconds: 100);
      const b = LyricsQuery(title: 'T', artist: 'A', durationSeconds: 100);

      expect(a, b);
      expect({a: 1}[b], 1);
    });
  });
}
