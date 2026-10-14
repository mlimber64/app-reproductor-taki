import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/core/domain/ports/artwork_http_client.dart';
import 'package:taki/features/jamendo/domain/entities/jamendo_exception.dart';
import 'package:taki/features/jamendo/domain/services/jamendo_song_lookup.dart';
import 'package:taki/features/jamendo/infrastructure/http_jamendo_api.dart';
import 'package:taki/features/jamendo/infrastructure/jamendo_credentials.dart';

import '../../helpers/jamendo_fakes.dart';

void main() {
  late FakeHttp http;
  late HttpJamendoApi api;

  HttpJamendoApi build(
    FakeHttp h, [
    String? clientId = fakeClientId,
    int retries = 0,
  ]) =>
      HttpJamendoApi(
        h,
        StaticJamendoCredentials(clientId),
        emptyRetries: retries,
        retryDelay: Duration.zero,
      );

  setUp(() {
    http = FakeHttp();
    api = build(http);
  });

  group('search', () {
    test('usa namesearch (no search) y los parámetros verificados', () async {
      await api.searchTracks(name: 'piano', limit: 20, offset: 40);

      final uri = http.requests.single;
      expect(uri.scheme, 'https');
      expect(uri.host, 'api.jamendo.com');
      expect(uri.path, '/v3.0/tracks/');
      final q = uri.queryParameters;
      expect(q['namesearch'], 'piano');
      expect(q.containsKey('search'), isFalse);
      expect(q['client_id'], fakeClientId);
      expect(q['format'], 'json');
      expect(q['audioformat'], 'mp32');
      expect(q['limit'], '20');
      expect(q['offset'], '40');
      expect(q.containsKey('artist_name'), isFalse);
      expect(q.containsKey('tags'), isFalse);
    });

    test('artista y etiqueta usan artist_name y tags', () async {
      await api.searchTracks(artistName: 'Whiteyes', tag: 'rock', limit: 5, offset: 0);
      final q = http.requests.single.queryParameters;
      expect(q['artist_name'], 'Whiteyes');
      expect(q['tags'], 'rock');
      expect(q.containsKey('namesearch'), isFalse);
    });

    test('criterios en blanco no se envían', () async {
      await api.searchTracks(name: '  ', artistName: '', tag: null, limit: 1, offset: 0);
      final q = http.requests.single.queryParameters;
      expect(q.containsKey('namesearch'), isFalse);
      expect(q.containsKey('artist_name'), isFalse);
      expect(q.containsKey('tags'), isFalse);
    });

    test('codifica UTF-8 con percent-encoding', () async {
      await api.searchTracks(name: 'canción ñ', limit: 1, offset: 0);
      final uri = http.requests.single;
      expect(uri.toString(), contains('canci%C3%B3n'));
      expect(uri.queryParameters['namesearch'], 'canción ñ');
    });

    test('hasMore: la API devolvió tantos como el límite', () async {
      var page = await api.searchTracks(name: 'a', limit: 2, offset: 0);
      expect(page.tracks.map((t) => t.id), ['2291526', '2318689']);
      expect(page.hasMore, isTrue);

      page = await api.searchTracks(name: 'a', limit: 3, offset: 0);
      expect(page.hasMore, isFalse);
    });

    test('resultados vacíos', () async {
      http.body = jamendoFixture('empty_results.json');
      final page = await api.searchTracks(name: 'zzz', limit: 10, offset: 0);
      expect(page.tracks, isEmpty);
      expect(page.hasMore, isFalse);
    });
  });

  group('tracksByIds', () {
    test('un solo request con ids separados por + y límite = cantidad', () async {
      await api.tracksByIds(['2291526', '37345']);
      final uri = http.requests.single;
      expect(uri.queryParameters['id'], '2291526 37345');
      expect(uri.toString(), contains('id=2291526+37345'));
      expect(uri.queryParameters['limit'], '2');
    });

    test('ids duplicados se envían una vez', () async {
      await api.tracksByIds(['1', '1', '2']);
      expect(http.requests.single.queryParameters['id'], '1 2');
    });

    test('sin ids no hay llamada', () async {
      expect(await api.tracksByIds(const []), isEmpty);
      expect(http.requests, isEmpty);
    });

    test('más de 50 ids se parten en lotes de 50', () async {
      http.body = jamendoFixture('empty_results.json');
      await api.tracksByIds([for (var i = 0; i < 120; i++) '$i']);
      final sizes = http.requests
          .map((u) => u.queryParameters['id']!.split(' ').length)
          .toList();
      expect(sizes, [50, 50, 20]);
      expect(HttpJamendoApi.maxIdsPerRequest, 50);
    });

    test('exactamente 50 ids es un solo lote', () async {
      http.body = jamendoFixture('empty_results.json');
      await api.tracksByIds([for (var i = 0; i < 50; i++) '$i']);
      expect(http.requests, hasLength(1));
    });

    test('los lotes se concatenan', () async {
      await api.tracksByIds([for (var i = 0; i < 51; i++) '$i']);
      expect(http.requests, hasLength(2));
    });
  });

  group('respuestas vacías intermitentes', () {
    final empty = jamendoFixture('empty_results.json');

    test('vacía y luego con resultados: reintenta y devuelve', () async {
      http.queue.add(empty);
      final page = await build(http, fakeClientId, 3)
          .searchTracks(name: 'piano', limit: 2, offset: 0);
      expect(page.tracks, hasLength(2));
      expect(http.requests, hasLength(2));
      expect(http.requests[0], http.requests[1]);
    });

    test('vacía tres veces y luego resultados (límite de reintentos)',
        () async {
      http.queue.addAll([empty, empty, empty]);
      final tracks = await build(http, fakeClientId, 3).tracksByIds(['2291526']);
      expect(tracks, isNotEmpty);
      expect(http.requests, hasLength(4));
    });

    test('siempre vacía: 1 + 3 intentos y resultado vacío', () async {
      http.body = empty;
      final tracks = await build(http, fakeClientId, 3).tracksByIds(['1']);
      expect(tracks, isEmpty);
      expect(http.requests, hasLength(4));
    });

    test('con resultados no reintenta', () async {
      await build(http, fakeClientId, 3).tracksByIds(['1']);
      expect(http.requests, hasLength(1));
    });

    test('un error de la API no se reintenta', () async {
      http.body = jamendoFixture('error_invalid_client.json');
      await expectLater(
        build(http, fakeClientId, 3).tracksByIds(['1']),
        throwsA(isA<JamendoInvalidClientException>()),
      );
      expect(http.requests, hasLength(1));
    });

    test('empty → empty → success: 3 intentos', () async {
      http.queue.addAll([empty, empty]);
      final tracks =
          await build(http, fakeClientId, 3).tracksByIds(['2291526']);
      expect(tracks, isNotEmpty);
      expect(http.requests, hasLength(3));
    });

    test('exactamente 3 empties y luego éxito: el 4.º intento es el último',
        () async {
      http.queue.addAll([empty, empty, empty]);
      final page = await build(http, fakeClientId, 3)
          .searchTracks(name: 'piano', limit: 2, offset: 0);
      expect(page.tracks, hasLength(2));
      expect(http.requests, hasLength(4));
    });

    test('4 empties: se agotan los reintentos y el 5.º éxito no se consume',
        () async {
      http.queue.addAll([empty, empty, empty, empty, jamendoFixture('tracks_search.json')]);
      final tracks =
          await build(http, fakeClientId, 3).tracksByIds(['2291526']);
      expect(tracks, isEmpty);
      expect(http.requests, hasLength(4));
      expect(http.queue, hasLength(1));
    });

    test('búsqueda realmente vacía: 4 intentos, página vacía sin más', () async {
      http.body = empty;
      final page = await build(http, fakeClientId, 3)
          .searchTracks(name: 'zzzz-no-existe', limit: 10, offset: 0);
      expect(page.tracks, isEmpty);
      expect(page.hasMore, isFalse);
      expect(http.requests, hasLength(4));
    });

    test('id realmente inexistente: 4 intentos y lista vacía', () async {
      http.body = empty;
      expect(await build(http, fakeClientId, 3).tracksByIds(['999999999']),
          isEmpty);
      expect(http.requests, hasLength(4));
    });

    test('un error de la API con results_count 0 NO es un empty success',
        () async {
      final failures = {
        'code 5': jamendoFixture('error_invalid_client.json'),
        'code 3': jamendoFixture('error_bad_param.json'),
        'code 7': '{"headers":{"status":"failed","code":7,'
            '"error_message":"m","results_count":0},"results":[]}',
        'sin code': '{"headers":{"status":"failed","results_count":0},'
            '"results":[]}',
      };
      for (final MapEntry(:key, :value) in failures.entries) {
        final h = FakeHttp(body: value);
        await expectLater(
          build(h, fakeClientId, 3).searchTracks(name: 'a', limit: 1, offset: 0),
          throwsA(isA<JamendoException>()),
          reason: key,
        );
        expect(h.requests, hasLength(1), reason: '$key no se reintenta');
      }
    });

    test('empty success y error no se confunden: empty devuelve vacío, '
        'failed lanza', () async {
      http.body = empty;
      expect(await build(http).tracksByIds(['1']), isEmpty);
      http.body = jamendoFixture('error_bad_param.json');
      await expectLater(build(http).tracksByIds(['1']), throwsA(isA<JamendoException>()));
    });

    test('un fallo de red no se trata como vacío ni se reintenta', () async {
      http.error = StateError('x');
      await expectLater(
        build(http, fakeClientId, 3).tracksByIds(['1']),
        throwsA(isA<JamendoNetworkException>()),
      );
      expect(http.requests, hasLength(1));
    });

    test('RIESGO DOCUMENTADO: tras agotar reintentos, un id existente se '
        'clasifica como missing en el lookup', () async {
      http.body = empty;
      final lookup = JamendoSongLookup(build(http, fakeClientId, 3));
      final result =
          await lookup.findAll([MusicIdentity('jamendo', '2291526')]);
      expect(result.missing, {MusicIdentity('jamendo', '2291526')});
      expect(result.found, isEmpty);
    });

    test('con un empty intermitente el lookup acaba encontrando la pista',
        () async {
      http.queue.add(empty);
      final lookup = JamendoSongLookup(build(http, fakeClientId, 3));
      final result = await lookup.findAll([
        MusicIdentity('jamendo', '2291526'),
        MusicIdentity('jamendo', '2318689'),
      ]);
      expect(result.found, hasLength(2));
      expect(result.missing, isEmpty);
    });

    test('por defecto: 3 reintentos con pausa', () async {
      http.body = empty;
      final api = HttpJamendoApi(http, const StaticJamendoCredentials(fakeClientId));
      final sw = Stopwatch()..start();
      await api.tracksByIds(['1']);
      expect(http.requests, hasLength(4));
      expect(sw.elapsed, greaterThanOrEqualTo(const Duration(milliseconds: 800)));
    });

    test('con 0 reintentos no repite', () async {
      http.body = empty;
      await build(http).tracksByIds(['1']);
      expect(http.requests, hasLength(1));
    });

    test('cada lote se reintenta por separado', () async {
      http.queue.addAll([empty]);
      await build(http, fakeClientId, 3)
          .tracksByIds([for (var i = 0; i < 60; i++) '$i']);
      // lote 1 (vacío + reintento) + lote 2.
      expect(http.requests, hasLength(3));
    });
  });

  group('errores', () {
    test('sin client_id no hay llamada y falla como client inválido', () async {
      for (final id in [null, '', '  ']) {
        final h = FakeHttp();
        await expectLater(
          build(h, id).searchTracks(name: 'a', limit: 1, offset: 0),
          throwsA(isA<JamendoInvalidClientException>()),
        );
        expect(h.requests, isEmpty);
      }
    });

    test('HTTP 200 + failed code 5 es error', () async {
      http.body = jamendoFixture('error_invalid_client.json');
      await expectLater(
        api.tracksByIds(['1']),
        throwsA(isA<JamendoInvalidClientException>()),
      );
    });

    test('HTTP 200 + failed code 3 es error de parámetro', () async {
      http.body = jamendoFixture('error_bad_param.json');
      await expectLater(
        api.searchTracks(name: 'a', limit: 1, offset: 0),
        throwsA(isA<JamendoInvalidParameterException>()),
      );
    });

    test('HTTP 500 → red con status', () async {
      http.status = 500;
      await expectLater(
        api.tracksByIds(['1']),
        throwsA(isA<JamendoNetworkException>()
            .having((e) => e.statusCode, 'statusCode', 500)),
      );
    });

    test('HTTP 299 aún es 2xx; 300 y 199 no', () async {
      http.status = 299;
      await api.tracksByIds(['1']);
      for (final s in [300, 199]) {
        http.status = s;
        await expectLater(
          api.tracksByIds(['1']),
          throwsA(isA<JamendoNetworkException>()),
        );
      }
    });

    test('fallo de red no filtra la URI ni la causa', () async {
      http.error = StateError('GET https://x?client_id=$fakeClientId falló');
      try {
        await api.tracksByIds(['1']);
        fail('debía lanzar');
      } on JamendoNetworkException catch (e) {
        expect(e.toString(), isNot(contains(fakeClientId)));
        expect(e.toString(), isNot(contains('https')));
        expect(e.message, contains('StateError'));
      }
    });

    test('timeout es error de red', () async {
      http.error = TimeoutException('t');
      await expectLater(
        api.tracksByIds(['1']),
        throwsA(isA<JamendoNetworkException>()),
      );
    });

    test('cuerpo no JSON → malformada', () async {
      http.body = '<html>';
      await expectLater(
        api.tracksByIds(['1']),
        throwsA(isA<JamendoMalformedResponseException>()),
      );
    });

    test('bytes que no son UTF-8 → malformada', () async {
      final bad = _BadBytesHttp();
      await expectLater(
        build(bad).tracksByIds(['1']),
        throwsA(isA<JamendoMalformedResponseException>()),
      );
    });

    test('el mensaje de la API se limpia del client_id', () async {
      http.body = '{"headers":{"status":"failed","code":3,'
          '"error_message":"mal $fakeClientId"},"results":[]}';
      try {
        await api.tracksByIds(['1']);
        fail('debía lanzar');
      } on JamendoException catch (e) {
        expect(e.toString(), isNot(contains(fakeClientId)));
      }
    });
  });

  test('las credenciales no revelan el valor', () {
    expect(
      const StaticJamendoCredentials(fakeClientId).toString(),
      isNot(contains(fakeClientId)),
    );
    expect(const EnvironmentJamendoCredentials().toString(),
        'EnvironmentJamendoCredentials()');
  });
}

class _BadBytesHttp extends FakeHttp {
  @override
  Future<ArtworkHttpResponse> get(
    Uri uri, {
    required Duration timeout,
    required int maxBytes,
  }) async =>
      ArtworkHttpResponse(200, Uint8List.fromList([0xFF, 0xFE, 0xFD]));
}
