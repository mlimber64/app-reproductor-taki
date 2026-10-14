import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/entities/attribution_lookup_failure.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/core/lookup/attribution_lookup_providers.dart';
import 'package:taki/features/player/presentation/providers/attribution_providers.dart';

import '../../../helpers/attribution_fakes.dart';

void main() {
  final id = MusicIdentity('jamendo', '1');
  late ScriptedAttributionLookup lookup;
  late ProviderContainer container;

  setUp(() {
    lookup = ScriptedAttributionLookup();
    container = ProviderContainer(
      overrides: [attributionLookupProvider.overrideWithValue(lookup)],
    );
    addTearDown(container.dispose);
  });

  test('found → data(attribution) y se pidió solo esa identidad', () async {
    final attribution = testAttribution(id);
    final future = container.read(attributionProvider(id).future);
    lookup.found(attribution);
    expect(await future, attribution);
    expect(lookup.calls.single, {id});
  });

  test('absent → data(null): ausencia, no error', () async {
    final future = container.read(attributionProvider(id).future);
    lookup.absent(id);
    expect(await future, isNull);
    expect(container.read(attributionProvider(id)).hasError, isFalse);
  });

  test('fallo real → error, NO ausencia silenciosa', () async {
    final sub = container.listen(attributionProvider(id), (_, _) {});
    lookup.fail(id);
    await expectLater(
      container.read(attributionProvider(id).future),
      throwsA(isA<AttributionLookupFailure>()),
    );
    expect(sub.read().hasError, isTrue);
    expect(sub.read().valueOrNull, isNull);
  });

  test('identidades distintas no se mezclan (familia)', () async {
    final other = MusicIdentity('jamendo', '2');
    final a = container.read(attributionProvider(id).future);
    final b = container.read(attributionProvider(other).future);
    lookup.found(testAttribution(other, providerName: 'B'));
    expect((await b)!.providerName, 'B');
    lookup.absent(id);
    expect(await a, isNull);
  });
}
