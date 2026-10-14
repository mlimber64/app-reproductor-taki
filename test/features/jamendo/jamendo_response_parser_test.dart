import 'package:flutter_test/flutter_test.dart';
import 'package:taki/features/jamendo/domain/entities/jamendo_exception.dart';
import 'package:taki/features/jamendo/infrastructure/jamendo_response_parser.dart';

import '../../helpers/jamendo_fakes.dart';

String envelope(String headers, [String results = '[]']) =>
    '{"headers":$headers,"results":$results}';

const ok = '{"status":"success","code":0,"results_count":1}';

void main() {
  group('éxito', () {
    test('parsea el fixture real: id como texto y campos observados', () {
      final parsed = parseJamendoTracks(jamendoFixture('tracks_search.json'));
      expect(parsed.rawCount, 2);
      final t = parsed.tracks.first;
      expect(t.id, '2291526');
      expect(t.name, "Love's Harmony (Background Romantic Piano)");
      expect(t.artistName, 'Lite Saturation');
      expect(t.albumName, 'Endless Affection');
      expect(t.durationSeconds, 144);
      expect(t.albumImage, contains('usercontent.jamendo.com'));
      expect(t.audio, startsWith('https://prod-1.storage.jamendo.com/'));
      expect(t.shareUrl, 'https://www.jamendo.com/track/2291526');
      expect(t.licenseUrl, contains('creativecommons.org'));
    });

    test('resultados vacíos son éxito', () {
      final parsed = parseJamendoTracks(jamendoFixture('empty_results.json'));
      expect(parsed.tracks, isEmpty);
      expect(parsed.rawCount, 0);
    });

    test('campos opcionales ausentes quedan en null / 0', () {
      final parsed = parseJamendoTracks(envelope(ok, '[{"id":"7","name":"X"}]'));
      final t = parsed.tracks.single;
      expect(t.artistName, isNull);
      expect(t.albumName, isNull);
      expect(t.albumImage, isNull);
      expect(t.audio, isNull);
      expect(t.shareUrl, isNull);
      expect(t.licenseUrl, isNull);
      expect(t.durationSeconds, 0);
    });

    test('cadenas vacías son null y duración de otro tipo es 0', () {
      final parsed = parseJamendoTracks(envelope(ok,
          '[{"id":"7","name":"X","artist_name":"","audio":"","duration":"12"}]'));
      final t = parsed.tracks.single;
      expect(t.artistName, isNull);
      expect(t.audio, isNull);
      expect(t.durationSeconds, 0);
    });

    test('un id numérico se conserva como texto, sin normalizar', () {
      final parsed = parseJamendoTracks(envelope(ok,
          '[{"id":42,"name":"A"},{"id":"0042","name":"B"}]'));
      expect(parsed.tracks.map((t) => t.id), ['42', '0042']);
    });

    test('mantiene el orden de la API', () {
      final parsed = parseJamendoTracks(jamendoFixture('tracks_search.json'));
      expect(parsed.tracks.map((t) => t.id), ['2291526', '2318689']);
    });

    test('album_image sale de album_image, no de image', () {
      final parsed = parseJamendoTracks(envelope(ok,
          '[{"id":"1","name":"x","album_image":"https://a/album","image":"https://a/image"}]'));
      expect(parsed.tracks.single.albumImage, 'https://a/album');
    });

    test('un id solo con espacios no vale', () {
      final parsed = parseJamendoTracks(
          envelope(ok, '[{"id":"  ","name":"x"},{"id":" 5 ","name":"y"}]'));
      expect(parsed.tracks.map((t) => t.id), [' 5 ']);
    });

    test('omite tracks sin id o sin nombre, pero cuenta rawCount', () {
      final parsed = parseJamendoTracks(envelope(ok,
          '[{"name":"sin id"},{"id":"1"},{"id":"2","name":" "},'
          '{"id":"3","name":"ok"},"basura",{"id":"","name":"x"}]'));
      expect(parsed.tracks.map((t) => t.id), ['3']);
      expect(parsed.rawCount, 6);
    });

    test('no lee headers.next', () {
      final parsed = parseJamendoTracks(envelope(
        '{"status":"success","code":0,"next":"https://x?client_id=$fakeClientId"}',
      ));
      expect(parsed.tracks, isEmpty);
    });
  });

  group('errores aunque el HTTP sea 200', () {
    test('code 5 → client inválido', () {
      expect(
        () => parseJamendoTracks(jamendoFixture('error_invalid_client.json')),
        throwsA(isA<JamendoInvalidClientException>()),
      );
    });

    test('code 3 → parámetro inválido', () {
      expect(
        () => parseJamendoTracks(jamendoFixture('error_bad_param.json')),
        throwsA(isA<JamendoInvalidParameterException>()),
      );
    });

    test('code 7 → error de método con su código', () {
      expect(
        () => parseJamendoTracks(envelope(
            '{"status":"failed","code":7,"error_message":"no method"}')),
        throwsA(isA<JamendoApiException>().having((e) => e.code, 'code', 7)),
      );
    });

    test('código desconocido o ausente → JamendoApiException', () {
      expect(
        () => parseJamendoTracks(envelope('{"status":"failed","code":99}')),
        throwsA(isA<JamendoApiException>().having((e) => e.code, 'code', 99)),
      );
      expect(
        () => parseJamendoTracks(envelope('{"status":"failed"}')),
        throwsA(isA<JamendoApiException>().having((e) => e.code, 'code', null)),
      );
    });

    test('un status distinto de success es error aunque el código sea 0', () {
      expect(
        () => parseJamendoTracks(envelope('{"status":"failed","code":0}')),
        throwsA(isA<JamendoApiException>()),
      );
    });

    test('cualquier status que no sea success es error', () {
      for (final status in ['error', 'failed', 'warning', '']) {
        expect(
          () => parseJamendoTracks(
              envelope('{"status":"$status","code":0}')),
          throwsA(isA<JamendoApiException>()),
          reason: status,
        );
      }
    });

    test('el mensaje se limpia del client_id', () {
      try {
        parseJamendoTracks(
          envelope('{"status":"failed","code":3,'
              '"error_message":"bad $fakeClientId value"}'),
          clientId: fakeClientId,
        );
        fail('debía lanzar');
      } on JamendoInvalidParameterException catch (e) {
        expect(e.message, 'bad *** value');
        expect(e.toString(), isNot(contains(fakeClientId)));
      }
    });

    test('mensaje ausente usa un texto genérico', () {
      expect(
        () => parseJamendoTracks(envelope('{"status":"failed","code":3}')),
        throwsA(isA<JamendoInvalidParameterException>()
            .having((e) => e.message, 'message', 'error de la API')),
      );
    });
  });

  group('respuesta malformada', () {
    for (final body in [
      'no es json',
      '[]',
      '"texto"',
      '{}',
      '{"headers":[]}',
      '{"headers":{}}',
      '{"headers":{"status":1}}',
      '{"headers":{"status":"success"}}',
      '{"headers":{"status":"success"},"results":{}}',
    ]) {
      test(body, () {
        expect(
          () => parseJamendoTracks(body),
          throwsA(isA<JamendoMalformedResponseException>()),
        );
      });
    }
  });
}
