import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/entities/lyrics.dart';
import 'package:taki/core/domain/ports/artwork_http_client.dart';
import 'package:taki/features/lyrics/infrastructure/lrclib_lyrics_source.dart';

/// Answers by path, in order of the queued responses for that path.
class _Http implements ArtworkHttpClient {
  final Map<String, List<(int, String)>> answers = {};
  final List<Uri> requests = [];
  Object? error;

  @override
  Future<ArtworkHttpResponse> get(
    Uri uri, {
    required Duration timeout,
    required int maxBytes,
  }) async {
    requests.add(uri);
    if (error != null) throw error!;
    final queue = answers[uri.path] ?? const [(404, '')];
    final (status, body) = queue.length > 1
        ? answers[uri.path]!.removeAt(0)
        : queue.first;
    return ArtworkHttpResponse(status, Uint8List.fromList(utf8.encode(body)));
  }
}

String _entry({
  String synced = '[00:01.00] Hello',
  String? plain = 'Hello',
  double duration = 100,
  bool instrumental = false,
}) =>
    jsonEncode({
      'trackName': 'T',
      'artistName': 'A',
      'duration': duration,
      'instrumental': instrumental,
      'syncedLyrics': synced.isEmpty ? null : synced,
      'plainLyrics': plain,
    });

void main() {
  late _Http http;
  late LrclibLyricsSource source;
  const query = LyricsQuery(title: 'Song', artist: 'Band', durationSeconds: 100);

  setUp(() {
    http = _Http();
    source = LrclibLyricsSource(http);
  });

  test('an exact match returns synced and plain lyrics', () async {
    http.answers['/api/get'] = [(200, _entry())];

    final lyrics = await source.find(query);

    expect(lyrics!.isSynced, isTrue);
    expect(lyrics.lines.single.text, 'Hello');
    expect(lyrics.text, 'Hello');
    final uri = http.requests.single;
    expect(uri.host, 'lrclib.net');
    expect(uri.queryParameters, {
      'track_name': 'Song',
      'artist_name': 'Band',
      'duration': '100',
    });
  });

  test('plain-only lyrics are returned as plain', () async {
    http.answers['/api/get'] = [(200, _entry(synced: ''))];

    final lyrics = await source.find(query);

    expect(lyrics!.isSynced, isFalse);
    expect(lyrics.text, 'Hello');
  });

  test('an instrumental track is flagged', () async {
    http.answers['/api/get'] = [
      (200, _entry(instrumental: true, synced: '', plain: null)),
    ];

    final lyrics = await source.find(query);

    expect(lyrics!.instrumental, isTrue);
  });

  test('a 404 falls back to search and takes the closest duration', () async {
    http.answers['/api/get'] = [(404, '')];
    http.answers['/api/search'] = [
      (
        200,
        jsonEncode([
          jsonDecode(_entry(duration: 180, plain: 'far')),
          jsonDecode(_entry(duration: 101, plain: 'close')),
        ]),
      ),
    ];

    final lyrics = await source.find(query);

    expect(lyrics!.text, 'close');
    expect(http.requests.map((u) => u.path), ['/api/get', '/api/search']);
  });

  test('search prefers synced lyrics at the same distance', () async {
    http.answers['/api/get'] = [(404, '')];
    http.answers['/api/search'] = [
      (
        200,
        jsonEncode([
          jsonDecode(_entry(synced: '', plain: 'plain only')),
          jsonDecode(_entry(plain: 'with timing')),
        ]),
      ),
    ];

    final lyrics = await source.find(query);

    expect(lyrics!.isSynced, isTrue);
  });

  test('candidates outside the tolerance are not lyrics for this song',
      () async {
    http.answers['/api/get'] = [(404, '')];
    http.answers['/api/search'] = [
      (200, jsonEncode([jsonDecode(_entry(duration: 300))])),
    ];

    expect(await source.find(query), isNull);
  });

  test('without artist it goes straight to search', () async {
    http.answers['/api/search'] = [
      (200, jsonEncode([jsonDecode(_entry())])),
    ];

    final lyrics = await source
        .find(const LyricsQuery(title: 'Song', durationSeconds: 100));

    expect(lyrics, isNotNull);
    expect(http.requests.single.path, '/api/search');
    expect(http.requests.single.queryParameters.containsKey('artist_name'),
        isFalse);
  });

  test('nothing anywhere is null, not a failure', () async {
    http.answers['/api/get'] = [(404, '')];
    http.answers['/api/search'] = [(200, '[]')];

    expect(await source.find(query), isNull);
  });

  test('a blank title is not looked up', () async {
    expect(await source.find(const LyricsQuery(title: '  ')), isNull);
    expect(http.requests, isEmpty);
  });

  test('server errors and bad bodies are failures, without the URL', () async {
    http.answers['/api/get'] = [(500, '')];
    await expectLater(
      source.find(query),
      throwsA(isA<LyricsLookupFailure>()
          .having((e) => e.message, 'message', isNot(contains('lrclib')))),
    );

    http.answers['/api/get'] = [(200, 'not json')];
    await expectLater(source.find(query), throwsA(isA<LyricsLookupFailure>()));
  });

  test('a transport error does not leak its cause', () async {
    http.error = Exception('https://lrclib.net/?track_name=secret');

    await expectLater(
      source.find(query),
      throwsA(isA<LyricsLookupFailure>()
          .having((e) => e.message, 'message', isNot(contains('secret')))),
    );
  });
}
