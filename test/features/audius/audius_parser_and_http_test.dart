import 'package:flutter_test/flutter_test.dart';
import 'package:taki/features/audius/domain/entities/audius_exception.dart';
import 'package:taki/features/audius/domain/ports/audius_api.dart';
import 'package:taki/features/audius/infrastructure/audius_response_parser.dart';
import 'package:taki/features/audius/infrastructure/http_audius_api.dart';

import '../../helpers/audius_fakes.dart';

void main() {
  group('parseAudiusTracks', () {
    test('maps the fields of a track', () {
      final parsed = parseAudiusTracks(audiusBody([audiusJson('x1')]));

      final track = parsed.tracks.single;
      expect(track.id, 'x1');
      expect(track.title, 'Song');
      expect(track.artistName, 'Artist');
      expect(track.durationSeconds, 120);
      expect(track.artworkUrl, 'https://cdn.example/x1/480x480.jpg');
      expect(track.permalink, '/Artist/x1');
      expect(track.license, 'All rights reserved');
    });

    test('skips deleted, unstreamable and gated tracks but counts them', () {
      final parsed = parseAudiusTracks(audiusBody([
        audiusJson('ok'),
        audiusJson('gone', deleted: true),
        audiusJson('off', streamable: false),
        audiusJson('gated', streamAccess: false),
      ]));

      expect(parsed.tracks.map((t) => t.id), ['ok']);
      expect(parsed.rawCount, 4);
    });

    test('falls back to the closest cover size', () {
      final json = audiusJson('c')
        ..['artwork'] = {'150x150': 'https://cdn.example/small.jpg'};

      final parsed = parseAudiusTracks(audiusBody([json]));

      expect(parsed.tracks.single.artworkUrl, 'https://cdn.example/small.jpg');
    });

    test('a track without cover or license keeps them null', () {
      final parsed = parseAudiusTracks(
        audiusBody([audiusJson('n', artwork: false, license: null)]),
      );

      expect(parsed.tracks.single.artworkUrl, isNull);
      expect(parsed.tracks.single.license, isNull);
    });

    test('rejects a body that is not the expected shape', () {
      expect(() => parseAudiusTracks('nope'),
          throwsA(isA<AudiusMalformedResponseException>()));
      expect(() => parseAudiusTracks('[]'),
          throwsA(isA<AudiusMalformedResponseException>()));
      expect(() => parseAudiusTracks('{"data": 3}'),
          throwsA(isA<AudiusMalformedResponseException>()));
    });
  });

  group('HttpAudiusApi', () {
    late FakeAudiusHttp http;
    HttpAudiusApi build() => HttpAudiusApi(http);

    setUp(() => http = FakeAudiusHttp());

    test('search sends the query, paging and app name', () async {
      await build().searchTracks(query: 'jazz club', limit: 20, offset: 40);

      final uri = http.requests.single;
      expect(uri.host, 'api.audius.co');
      expect(uri.path, '/v1/tracks/search');
      expect(uri.queryParameters, {
        'query': 'jazz club',
        'limit': '20',
        'offset': '40',
        'app_name': 'taki',
      });
    });

    test('trending maps the window and the genre', () async {
      await build().trending(
        window: AudiusTrendingWindow.month,
        genre: 'Hip-Hop/Rap',
        limit: 10,
        offset: 0,
      );

      final uri = http.requests.single;
      expect(uri.path, '/v1/tracks/trending');
      expect(uri.queryParameters['time'], 'month');
      expect(uri.queryParameters['genre'], 'Hip-Hop/Rap');
    });

    test('underground uses its own chart', () async {
      await build().underground(limit: 5, offset: 0);

      expect(http.requests.single.path, '/v1/tracks/trending/underground');
    });

    test('hasMore is true when the page came back full', () async {
      final page =
          await build().searchTracks(query: 'a', limit: 2, offset: 0);
      expect(page.hasMore, isTrue);

      final partial =
          await build().searchTracks(query: 'a', limit: 5, offset: 0);
      expect(partial.hasMore, isFalse);
    });

    test('tracksByIds repeats id once per track in a single request',
        () async {
      await build().tracksByIds(['a1', 'a2', 'a1']);

      final uri = http.requests.single;
      expect(uri.path, '/v1/tracks');
      expect(uri.queryParametersAll['id'], ['a1', 'a2']);
    });

    test('tracksByIds with nothing asks nothing', () async {
      expect(await build().tracksByIds(const []), isEmpty);
      expect(http.requests, isEmpty);
    });

    test('streamUrl is built without a request', () {
      final url = build().streamUrl('DX0Xb');

      expect(url, 'https://api.audius.co/v1/tracks/DX0Xb/stream?app_name=taki');
      expect(http.requests, isEmpty);
    });

    test('a non-2xx status is a network exception without the URL', () async {
      http.status = 503;

      await expectLater(
        build().searchTracks(query: 'a', limit: 1, offset: 0),
        throwsA(isA<AudiusNetworkException>()
            .having((e) => e.statusCode, 'status', 503)
            .having((e) => e.message, 'message', isNot(contains('http')))),
      );
    });

    test('a transport error does not leak its cause', () async {
      http.error = Exception('https://secret.example/?token=1');

      await expectLater(
        build().searchTracks(query: 'a', limit: 1, offset: 0),
        throwsA(isA<AudiusNetworkException>().having(
            (e) => e.message, 'message', isNot(contains('secret')))),
      );
    });
  });
}
