import 'package:flutter_test/flutter_test.dart';
import 'package:taki/app/jamendo_wiring.dart';
import 'package:taki/features/jamendo/domain/entities/jamendo_exception.dart';
import 'package:taki/features/jamendo/infrastructure/http_jamendo_api.dart';
import 'package:taki/features/jamendo/infrastructure/jamendo_credentials.dart';

import '../../helpers/jamendo_fakes.dart';

void main() {
  group('normalizeJamendoClientId', () {
    test('válidos: hexadecimal de 8, el fake de tests y los extremos', () {
      expect(normalizeJamendoClientId('a1b2c3d4'), 'a1b2c3d4');
      expect(normalizeJamendoClientId(fakeClientId), fakeClientId);
      expect(normalizeJamendoClientId('abcd'), 'abcd'); // 4: mínimo
      expect(normalizeJamendoClientId('a' * 64), 'a' * 64); // 64: máximo
      expect(normalizeJamendoClientId('A_b-9'), 'A_b-9');
    });

    test('recorta espacios de los extremos', () {
      expect(normalizeJamendoClientId('  a1b2c3d4\n'), 'a1b2c3d4');
    });

    test('ausente o vacío → null', () {
      for (final raw in [null, '', '   ', '\n']) {
        expect(normalizeJamendoClientId(raw), isNull, reason: '"$raw"');
      }
    });

    test('formato inválido → null', () {
      for (final raw in [
        'abc', // demasiado corto
        'a' * 65, // demasiado largo
        'a1b2 c3d4', // espacio interior
        'a1b2c3d4&x=1', // intento de inyectar parámetros
        'client_id=a1b2c3d4', // valor pegado con el nombre
        '--dart-define=a1b2c3d4',
        '"a1b2c3d4"', // comillas
        'a1b2c3d4/',
        'a1b2c3d?',
        'ñandú12', // no ASCII
      ]) {
        expect(normalizeJamendoClientId(raw), isNull, reason: raw);
      }
    });
  });

  group('credenciales', () {
    test('el nombre de la variable es JAMENDO_CLIENT_ID', () {
      expect(EnvironmentJamendoCredentials.variableName, 'JAMENDO_CLIENT_ID');
    });

    test('Static: válida, ausente, vacía e inválida', () {
      expect(const StaticJamendoCredentials(fakeClientId).clientId, fakeClientId);
      expect(const StaticJamendoCredentials(null).clientId, isNull);
      expect(const StaticJamendoCredentials('').clientId, isNull);
      expect(const StaticJamendoCredentials('no válido!').clientId, isNull);
    });

    test('Environment sin --dart-define (ejecución normal): ausente', () {
      const defined = String.fromEnvironment('JAMENDO_CLIENT_ID');
      if (defined.isNotEmpty) return; // lo cubre el test de abajo
      expect(const EnvironmentJamendoCredentials().clientId, isNull);
    });

    test('Environment con --dart-define=JAMENDO_CLIENT_ID=<fake> (solo si se '
        'ejecuta con él)', () {
      const defined = String.fromEnvironment('JAMENDO_CLIENT_ID');
      if (defined.isEmpty) return;
      expect(
        const EnvironmentJamendoCredentials().clientId,
        normalizeJamendoClientId(defined),
      );
    }, skip: const String.fromEnvironment('JAMENDO_CLIENT_ID').isEmpty
        ? 'se activa con --dart-define=JAMENDO_CLIENT_ID=<fake>'
        : false);

    test('toString no revela el valor', () {
      expect(const StaticJamendoCredentials(fakeClientId).toString(),
          isNot(contains(fakeClientId)));
    });
  });

  group('efecto en la app', () {
    test('configuración válida → Jamendo se construye', () {
      expect(
        buildJamendoServices(FakeHttp(),
            credentials: const StaticJamendoCredentials(fakeClientId)),
        isNotNull,
      );
    });

    test('ausente, vacía o inválida → Jamendo no se registra', () {
      for (final raw in [null, '', ' ', 'abc', 'con espacio', 'a&b=cdef']) {
        expect(
          buildJamendoServices(FakeHttp(),
              credentials: StaticJamendoCredentials(raw)),
          isNull,
          reason: '$raw',
        );
      }
    });

    test('un client_id inválido no llega a la red', () async {
      final http = FakeHttp();
      final api = HttpJamendoApi(http, const StaticJamendoCredentials('a&b=cdef'));
      await expectLater(
        api.tracksByIds(['1']),
        throwsA(isA<JamendoInvalidClientException>()),
      );
      expect(http.requests, isEmpty);
    });

    test('el client_id se envía recortado y codificado en la query', () async {
      final http = FakeHttp();
      await HttpJamendoApi(http, const StaticJamendoCredentials('  $fakeClientId '))
          .tracksByIds(['1']);
      expect(http.requests.single.queryParameters['client_id'], fakeClientId);
    });
  });
}
