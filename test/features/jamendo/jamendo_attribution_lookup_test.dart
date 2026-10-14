import 'package:flutter_test/flutter_test.dart';
import 'package:taki/app/jamendo_wiring.dart';
import 'package:taki/core/domain/entities/attribution_lookup_failure.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/features/jamendo/domain/entities/jamendo_exception.dart';
import 'package:taki/features/jamendo/domain/entities/jamendo_track.dart';
import 'package:taki/features/jamendo/domain/services/jamendo_attribution_lookup.dart';

import '../../helpers/jamendo_fakes.dart';

MusicIdentity jid(String id) => MusicIdentity('jamendo', id);

void main() {
  group('JamendoAttributionLookup', () {
    test('resuelve en lote con una sola consulta', () async {
      final api = FakeJamendoApi(
          tracks: [buildTrack('1'), buildTrack('2'), buildTrack('3')]);
      final result = await JamendoAttributionLookup(api)
          .findAll([jid('1'), jid('2'), jid('3')]);

      expect(api.idCalls, hasLength(1));
      expect(api.idCalls.single.toSet(), {'1', '2', '3'});
      expect(result.found.keys, {jid('1'), jid('2'), jid('3')});
      expect(result.absent, isEmpty);
    });

    test('la atribución es la de JamendoTrack.attribution', () async {
      final track = buildTrack('7');
      final result = await JamendoAttributionLookup(FakeJamendoApi(tracks: [track]))
          .findAll([jid('7')]);
      expect(result.found[jid('7')], track.attribution);
      final attribution = result.found[jid('7')]!;
      expect(attribution.identity, jid('7'));
      expect(attribution.providerName, jamendoProviderName);
      expect(attribution.pageUrl, Uri.parse('https://www.jamendo.com/track/7'));
      expect(attribution.licenseName, 'CC BY-NC-ND 3.0');
    });

    test('una atribución incompleta sigue siendo found', () async {
      final api = FakeJamendoApi(tracks: [const JamendoTrack(id: '9', name: 'n')]);
      final result = await JamendoAttributionLookup(api).findAll([jid('9')]);
      expect(result.found[jid('9')]!.isComplete, isFalse);
      expect(result.absent, isEmpty);
    });

    test('un id que la API no devuelve es absent (no es un error)', () async {
      final api = FakeJamendoApi(tracks: [buildTrack('1')]);
      final result =
          await JamendoAttributionLookup(api).findAll([jid('1'), jid('2')]);
      expect(result.found.keys, {jid('1')});
      expect(result.absent, {jid('2')});
    });

    test('las identidades de otras fuentes son absent y no van a la API',
        () async {
      final api = FakeJamendoApi(tracks: [buildTrack('1')]);
      final local = MusicIdentity('local', '1');
      final result =
          await JamendoAttributionLookup(api).findAll([jid('1'), local]);
      expect(api.idCalls.single, ['1']);
      expect(result.found.keys, {jid('1')});
      expect(result.absent, {local});
    });

    test('solo identidades ajenas: ninguna llamada', () async {
      final api = FakeJamendoApi(tracks: [buildTrack('1')]);
      final local = MusicIdentity('local', '1');
      final result = await JamendoAttributionLookup(api).findAll([local]);
      expect(api.idCalls, isEmpty);
      expect(result.found, isEmpty);
      expect(result.absent, {local});
    });

    test('sin identidades: vacío y sin llamadas', () async {
      final api = FakeJamendoApi();
      final result = await JamendoAttributionLookup(api).findAll([]);
      expect(api.idCalls, isEmpty);
      expect(result.found, isEmpty);
      expect(result.absent, isEmpty);
    });

    test('misma externalId en otra fuente no se confunde', () async {
      final api = FakeJamendoApi(tracks: [buildTrack('42')]);
      final local = MusicIdentity('local', '42');
      final result =
          await JamendoAttributionLookup(api).findAll([local, jid('42')]);
      expect(result.found.keys, {jid('42')});
      expect(result.absent, {local});
    });

    test('los duplicados se piden una vez', () async {
      final api = FakeJamendoApi(tracks: [buildTrack('1')]);
      await JamendoAttributionLookup(api).findAll([jid('1'), jid('1')]);
      expect(api.idCalls.single, ['1']);
    });

    group('fallos', () {
      test('un error de Jamendo es AttributionLookupFailure, no absent',
          () async {
        final api = FakeJamendoApi(error: const JamendoInvalidClientException());
        await expectLater(
          JamendoAttributionLookup(api).findAll([jid('1')]),
          throwsA(isA<AttributionLookupFailure>()
              .having((e) => e.source, 'source', 'jamendo')
              .having((e) => e.cause, 'cause', isA<JamendoException>())),
        );
      });

      test('un error inesperado se traduce sin detalles', () async {
        final api = FakeJamendoApi(error: StateError('boom'));
        await expectLater(
          JamendoAttributionLookup(api).findAll([jid('1')]),
          throwsA(isA<AttributionLookupFailure>()
              .having((e) => e.source, 'source', 'jamendo')
              .having((e) => e.cause, 'cause', StateError)
              .having((e) => e.message, 'message', isNot(contains('boom')))),
        );
      });

      test('un track que no se pidió es un fallo del contrato', () async {
        final api = FakeJamendoApi(tracks: [buildTrack('1')]);
        final lookup = JamendoAttributionLookup(_Extra(api, buildTrack('99')));
        await expectLater(
          lookup.findAll([jid('1')]),
          throwsA(isA<AttributionLookupFailure>()
              .having((e) => e.source, 'source', 'jamendo')),
        );
      });
    });
  });

  group('wiring', () {
    test('buildAttributionLookup(null): todo es absent', () async {
      final lookup = buildAttributionLookup(null);
      final result = await lookup.findAll([jid('1'), MusicIdentity('local', '2')]);
      expect(result.found, isEmpty);
      expect(result.absent, {jid('1'), MusicIdentity('local', '2')});
    });

    test('con Jamendo: enruta solo las identidades jamendo', () async {
      final api = FakeJamendoApi(tracks: [buildTrack('1'), buildTrack('2')]);
      final lookup = buildAttributionLookup(buildJamendoServicesFor(api));
      final local = MusicIdentity('local', '1');
      final result =
          await lookup.findAll([jid('1'), jid('2'), jid('3'), local]);

      expect(api.idCalls, hasLength(1));
      expect(api.idCalls.single.toSet(), {'1', '2', '3'});
      expect(result.found.keys, {jid('1'), jid('2')});
      expect(result.absent, {jid('3'), local});
    });

    test('un fallo de Jamendo llega como AttributionLookupFailure', () async {
      final api = FakeJamendoApi(error: const JamendoInvalidClientException());
      final lookup = buildAttributionLookup(buildJamendoServicesFor(api));
      await expectLater(
        lookup.findAll([jid('1')]),
        throwsA(isA<AttributionLookupFailure>()),
      );
    });

    test('JamendoServices expone el lookup', () {
      final services = buildJamendoServicesFor(FakeJamendoApi());
      expect(services.attribution, isA<JamendoAttributionLookup>());
    });
  });
}

/// Devuelve un track extra que nadie pidió.
class _Extra extends FakeJamendoApi {
  _Extra(FakeJamendoApi inner, this.extra) : super(tracks: inner.tracks);

  final JamendoTrack extra;

  @override
  Future<List<JamendoTrack>> tracksByIds(Iterable<String> ids) async =>
      [...await super.tracksByIds(ids), extra];
}
