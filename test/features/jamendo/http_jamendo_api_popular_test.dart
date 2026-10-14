import 'package:flutter_test/flutter_test.dart';
import 'package:taki/features/jamendo/domain/entities/jamendo_exception.dart';
import 'package:taki/features/jamendo/domain/ports/jamendo_api.dart';
import 'package:taki/features/jamendo/infrastructure/http_jamendo_api.dart';
import 'package:taki/features/jamendo/infrastructure/jamendo_credentials.dart';

import '../../helpers/jamendo_fakes.dart';

void main() {
  late FakeHttp http;

  HttpJamendoApi build({int retries = 0, String? clientId = fakeClientId}) =>
      HttpJamendoApi(
        http,
        StaticJamendoCredentials(clientId),
        emptyRetries: retries,
        retryDelay: Duration.zero,
      );

  setUp(() => http = FakeHttp());

  group('listTracks', () {
    test('sends the base parameters and no search criteria', () async {
      await build().listTracks(
        order: JamendoTrackOrder.popularityWeek,
        limit: 20,
        offset: 0,
      );

      final uri = http.requests.single;
      expect(uri.host, 'api.jamendo.com');
      expect(uri.path, '/v3.0/tracks/');
      final q = uri.queryParameters;
      expect(q['limit'], '20');
      expect(q['offset'], '0');
      expect(q['audioformat'], 'mp32');
      expect(q['client_id'], fakeClientId);
      expect(q.containsKey('namesearch'), isFalse);
      expect(q.containsKey('artist_name'), isFalse);
      expect(q.containsKey('tags'), isFalse);
    });

    test('each order maps to the value Jamendo expects', () async {
      const expected = {
        JamendoTrackOrder.popularityWeek: 'popularity_week',
        JamendoTrackOrder.popularityMonth: 'popularity_month',
        JamendoTrackOrder.releaseDateDesc: 'releasedate_desc',
      };

      for (final entry in expected.entries) {
        http.requests.clear();
        await build().listTracks(order: entry.key, limit: 5, offset: 0);
        expect(http.requests.single.queryParameters['order'], entry.value);
      }
    });

    test('a tag is sent as tags', () async {
      await build().listTracks(
        order: JamendoTrackOrder.popularityWeek,
        tag: 'hiphop',
        limit: 5,
        offset: 0,
      );

      expect(http.requests.single.queryParameters['tags'], 'hiphop');
    });

    test('a blank tag is not sent', () async {
      await build().listTracks(
        order: JamendoTrackOrder.popularityWeek,
        tag: '  ',
        limit: 5,
        offset: 0,
      );

      expect(http.requests.single.queryParameters.containsKey('tags'), isFalse);
    });

    test('parses the tracks of the response', () async {
      final page = await build().listTracks(
        order: JamendoTrackOrder.releaseDateDesc,
        limit: 20,
        offset: 0,
      );

      expect(page.tracks, isNotEmpty);
    });

    test('retries an intermittent empty answer like the other queries',
        () async {
      http.queue.add('{"headers":{"status":"success"},"results":[]}');

      final page = await build(retries: 2).listTracks(
        order: JamendoTrackOrder.popularityWeek,
        limit: 20,
        offset: 0,
      );

      expect(http.requests, hasLength(2));
      expect(page.tracks, isNotEmpty);
    });

    test('a missing credential fails before any request', () async {
      await expectLater(
        build(clientId: null).listTracks(
          order: JamendoTrackOrder.popularityWeek,
          limit: 20,
          offset: 0,
        ),
        throwsA(isA<JamendoInvalidClientException>()),
      );
      expect(http.requests, isEmpty);
    });

    test('an HTTP error does not leak the credential', () async {
      http.status = 503;

      await expectLater(
        build().listTracks(
          order: JamendoTrackOrder.popularityWeek,
          limit: 20,
          offset: 0,
        ),
        throwsA(
          isA<JamendoNetworkException>().having(
            (e) => e.toString(),
            'message',
            isNot(contains(fakeClientId)),
          ),
        ),
      );
    });
  });
}
