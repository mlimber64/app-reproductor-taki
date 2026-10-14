import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/entities/attribution_lookup_failure.dart';
import 'package:taki/core/domain/entities/attribution_lookup_result.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/core/domain/entities/provider_attribution.dart';
import 'package:taki/core/domain/ports/attribution_lookup.dart';
import 'package:taki/core/domain/services/source_attribution_lookup.dart';
import 'package:taki/core/lookup/attribution_lookup_providers.dart';

MusicIdentity id(String source, String externalId) =>
    MusicIdentity(source, externalId);

ProviderAttribution attr(MusicIdentity identity, {bool complete = true}) =>
    ProviderAttribution(
      identity: identity,
      providerName: identity.source.toUpperCase(),
      pageUrl: complete ? Uri.parse('https://x.example/${identity.externalId}') : null,
      licenseUrl: complete ? Uri.parse('https://cc.example/by') : null,
    );

/// `AttributionLookup` guionizado: registra cada llamada.
class FakeAttributionLookup implements AttributionLookup {
  FakeAttributionLookup(this.handler);

  Future<AttributionLookupResult> Function(Set<MusicIdentity> ids) handler;
  final List<Set<MusicIdentity>> calls = [];

  /// Responde `found` para las identidades de [known] y `absent` para el resto.
  factory FakeAttributionLookup.knowing(Set<MusicIdentity> known,
      {bool complete = true}) {
    return FakeAttributionLookup((ids) async => AttributionLookupResult(
          found: {
            for (final i in ids)
              if (known.contains(i)) i: attr(i, complete: complete),
          },
          absent: {
            for (final i in ids)
              if (!known.contains(i)) i,
          },
        ));
  }

  @override
  Future<AttributionLookupResult> findAll(Iterable<MusicIdentity> identities) {
    final ids = identities.toSet();
    calls.add(ids);
    return handler(ids);
  }
}

void main() {
  group('AttributionLookupResult', () {
    test('vacío por defecto', () {
      const result = AttributionLookupResult();
      expect(result.found, isEmpty);
      expect(result.absent, isEmpty);
      expect(AttributionLookupResult.empty.found, isEmpty);
      expect(AttributionLookupResult.empty.absent, isEmpty);
    });

    test('merge une ambos cubos', () {
      final a = AttributionLookupResult(
          found: {id('a', '1'): attr(id('a', '1'))}, absent: {id('a', '2')});
      final b = AttributionLookupResult(
          found: {id('b', '1'): attr(id('b', '1'))}, absent: {id('b', '2')});
      final merged = a.merge(b);
      expect(merged.found.keys, {id('a', '1'), id('b', '1')});
      expect(merged.absent, {id('a', '2'), id('b', '2')});
    });

    test('toString resume los cubos', () {
      final result = AttributionLookupResult(
          found: {id('a', '1'): attr(id('a', '1'))}, absent: {id('a', '2'), id('a', '3')});
      expect(result.toString(), 'AttributionLookupResult(found: 1, absent: 2)');
    });
  });

  group('AttributionLookupFailure', () {
    test('toString con y sin fuente', () {
      expect(const AttributionLookupFailure('x', source: 's').toString(),
          'AttributionLookupFailure(s: x)');
      expect(const AttributionLookupFailure('x').toString(),
          'AttributionLookupFailure(-: x)');
    });
  });

  group('SourceAttributionLookup', () {
    test('sin identidades: vacío y sin llamadas', () async {
      final a = FakeAttributionLookup.knowing({});
      final result = await SourceAttributionLookup({'a': a}).findAll([]);
      expect(result.found, isEmpty);
      expect(result.absent, isEmpty);
      expect(a.calls, isEmpty);
    });

    test('enruta cada identidad solo a su fuente, una llamada por fuente',
        () async {
      final a = FakeAttributionLookup.knowing({id('a', '1')});
      final b = FakeAttributionLookup.knowing({id('b', '9')});
      final lookup = SourceAttributionLookup({'a': a, 'b': b});

      final result = await lookup
          .findAll([id('a', '1'), id('a', '2'), id('b', '9'), id('b', '8')]);

      expect(a.calls, [
        {id('a', '1'), id('a', '2')},
      ]);
      expect(b.calls, [
        {id('b', '9'), id('b', '8')},
      ]);
      expect(result.found.keys, {id('a', '1'), id('b', '9')});
      expect(result.absent, {id('a', '2'), id('b', '8')});
    });

    test('cada identidad cae en exactamente un cubo', () async {
      final a = FakeAttributionLookup.knowing({id('a', '1')});
      final wanted = [id('a', '1'), id('a', '2'), id('zzz', '3')];
      final result = await SourceAttributionLookup({'a': a}).findAll(wanted);
      for (final w in wanted) {
        expect(
          [result.found.containsKey(w), result.absent.contains(w)]
              .where((x) => x)
              .length,
          1,
          reason: '$w',
        );
      }
    });

    test('una fuente sin lookup registrado: absent, sin error', () async {
      final a = FakeAttributionLookup.knowing({id('a', '1')});
      final result = await SourceAttributionLookup({'a': a})
          .findAll([id('a', '1'), id('local', '5'), id('otra', '6')]);
      expect(result.found.keys, {id('a', '1')});
      expect(result.absent, {id('local', '5'), id('otra', '6')});
      expect(a.calls.single, {id('a', '1')});
    });

    test('sin ninguna fuente registrada, todo es absent', () async {
      final result = await SourceAttributionLookup({})
          .findAll([id('a', '1'), id('b', '2')]);
      expect(result.found, isEmpty);
      expect(result.absent, {id('a', '1'), id('b', '2')});
    });

    test('los duplicados cuentan como uno', () async {
      final a = FakeAttributionLookup.knowing({id('a', '1')});
      await SourceAttributionLookup({'a': a})
          .findAll([id('a', '1'), id('a', '1'), id('a', '1')]);
      expect(a.calls.single, {id('a', '1')});
    });

    test('misma externalId en fuentes distintas nunca colisiona', () async {
      final local = FakeAttributionLookup.knowing({});
      final jamendo = FakeAttributionLookup.knowing({id('jamendo', '42')});
      final result = await SourceAttributionLookup(
              {'local': local, 'jamendo': jamendo})
          .findAll([id('local', '42'), id('jamendo', '42')]);
      expect(result.found.keys, {id('jamendo', '42')});
      expect(result.absent, {id('local', '42')});
      expect(local.calls.single, {id('local', '42')});
      expect(jamendo.calls.single, {id('jamendo', '42')});
    });

    test('una identidad que el lookup no contabilizó pasa a absent', () async {
      final a = FakeAttributionLookup((ids) async =>
          AttributionLookupResult(found: {id('a', '1'): attr(id('a', '1'))}));
      final result = await SourceAttributionLookup({'a': a})
          .findAll([id('a', '1'), id('a', '2')]);
      expect(result.found.keys, {id('a', '1')});
      expect(result.absent, {id('a', '2')});
    });

    test('una atribución incompleta es found', () async {
      final a = FakeAttributionLookup.knowing({id('a', '1')}, complete: false);
      final result =
          await SourceAttributionLookup({'a': a}).findAll([id('a', '1')]);
      expect(result.found[id('a', '1')]!.isComplete, isFalse);
      expect(result.absent, isEmpty);
    });

    test('se consultan las fuentes en paralelo', () async {
      final ca = Completer<AttributionLookupResult>();
      final cb = Completer<AttributionLookupResult>();
      final a = FakeAttributionLookup((_) => ca.future);
      final b = FakeAttributionLookup((_) => cb.future);
      final future = SourceAttributionLookup({'a': a, 'b': b})
          .findAll([id('a', '1'), id('b', '1')]);
      await pumpEventQueue();
      expect(a.calls, hasLength(1));
      expect(b.calls, hasLength(1));
      ca.complete(const AttributionLookupResult());
      cb.complete(const AttributionLookupResult());
      await future;
    });

    group('fallos', () {
      test('un AttributionLookupFailure se propaga tal cual', () async {
        const failure = AttributionLookupFailure('red', source: 'a');
        final a = FakeAttributionLookup((_) async => throw failure);
        await expectLater(
          SourceAttributionLookup({'a': a}).findAll([id('a', '1')]),
          throwsA(same(failure)),
        );
      });

      test('un error inesperado se traduce, con fuente y causa', () async {
        final a = FakeAttributionLookup((_) async => throw StateError('boom'));
        await expectLater(
          SourceAttributionLookup({'a': a}).findAll([id('a', '1')]),
          throwsA(isA<AttributionLookupFailure>()
              .having((e) => e.source, 'source', 'a')
              .having((e) => e.cause, 'cause', StateError)
              .having((e) => e.message, 'message', isNot(contains('boom')))),
        );
      });

      test('el fallo de una fuente no se disfraza de absent ni se pierde',
          () async {
        final good = FakeAttributionLookup.knowing({id('a', '1')});
        final bad = FakeAttributionLookup(
            (_) async => throw const AttributionLookupFailure('x', source: 'b'));
        await expectLater(
          SourceAttributionLookup({'a': good, 'b': bad})
              .findAll([id('a', '1'), id('b', '1')]),
          throwsA(isA<AttributionLookupFailure>()),
        );
      });

      test('una fuente sin registro no es un fallo', () async {
        await expectLater(
          SourceAttributionLookup({}).findAll([id('a', '1')]),
          completion(isA<AttributionLookupResult>()),
        );
      });

      test('atribución bajo una identidad que no es la suya: fallo', () async {
        final a = FakeAttributionLookup((_) async => AttributionLookupResult(
            found: {id('a', '1'): attr(id('a', '2'))}));
        await expectLater(
          SourceAttributionLookup({'a': a}).findAll([id('a', '1')]),
          throwsA(isA<AttributionLookupFailure>()
              .having((e) => e.source, 'source', 'a')),
        );
      });

      test('atribución para una identidad que no se pidió: fallo', () async {
        final a = FakeAttributionLookup((_) async => AttributionLookupResult(
            found: {id('a', '9'): attr(id('a', '9'))}));
        await expectLater(
          SourceAttributionLookup({'a': a}).findAll([id('a', '1')]),
          throwsA(isA<AttributionLookupFailure>()
              .having((e) => e.source, 'source', 'a')),
        );
      });

      test('atribución de otra fuente devuelta por este lookup: fallo',
          () async {
        final a = FakeAttributionLookup((_) async => AttributionLookupResult(
            found: {id('b', '1'): attr(id('b', '1'))}));
        await expectLater(
          SourceAttributionLookup({'a': a}).findAll([id('a', '1')]),
          throwsA(isA<AttributionLookupFailure>()),
        );
      });
    });

    test('el mapa de fuentes se copia: cambiarlo después no afecta', () async {
      final a = FakeAttributionLookup.knowing({id('a', '1')});
      final map = <String, AttributionLookup>{'a': a};
      final lookup = SourceAttributionLookup(map);
      map.clear();
      final result = await lookup.findAll([id('a', '1')]);
      expect(result.found.keys, {id('a', '1')});
    });
  });

  group('attributionLookupProvider', () {
    test('sin override lanza (se cablea en main.dart)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(() => container.read(attributionLookupProvider),
          throwsA(anything));
    });

    test('con override devuelve el cableado', () {
      final lookup = SourceAttributionLookup({});
      final container = ProviderContainer(overrides: [
        attributionLookupProvider.overrideWithValue(lookup),
      ]);
      addTearDown(container.dispose);
      expect(container.read(attributionLookupProvider), same(lookup));
    });
  });
}
