import 'dart:async';

import 'package:taki/core/domain/entities/attribution_lookup_failure.dart';
import 'package:taki/core/domain/entities/attribution_lookup_result.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/core/domain/entities/provider_attribution.dart';
import 'package:taki/core/domain/ports/attribution_lookup.dart';
import 'package:taki/core/domain/ports/external_link_opener.dart';

/// `AttributionLookup` guionizado: cada pedido queda pendiente hasta que el test
/// lo responde (para fijar el orden de las respuestas, p. ej. una tardía).
class ScriptedAttributionLookup implements AttributionLookup {
  final List<Set<MusicIdentity>> calls = [];
  final Map<MusicIdentity, Completer<AttributionLookupResult>> _pending = {};

  Completer<AttributionLookupResult> _completerFor(MusicIdentity id) =>
      _pending.putIfAbsent(id, Completer<AttributionLookupResult>.new);

  @override
  Future<AttributionLookupResult> findAll(Iterable<MusicIdentity> identities) {
    final set = identities.toSet();
    calls.add(set);
    return _completerFor(set.single).future;
  }

  void found(ProviderAttribution attribution) =>
      _completerFor(attribution.identity).complete(
        AttributionLookupResult(found: {attribution.identity: attribution}),
      );

  void absent(MusicIdentity identity) => _completerFor(identity)
      .complete(AttributionLookupResult(absent: {identity}));

  void fail(MusicIdentity identity) => _completerFor(identity)
      .completeError(const AttributionLookupFailure('falló', source: 'test'));
}

/// Lookup que responde enseguida lo mismo para cualquier identidad.
class ImmediateAttributionLookup implements AttributionLookup {
  ImmediateAttributionLookup(this.answer);

  final AttributionLookupResult Function(MusicIdentity identity) answer;

  @override
  Future<AttributionLookupResult> findAll(Iterable<MusicIdentity> identities) async =>
      answer(identities.single);
}

class FakeLinkOpener implements ExternalLinkOpener {
  FakeLinkOpener({this.result = true});

  bool result;
  final List<Uri> opened = [];

  @override
  Future<bool> open(Uri url) async {
    opened.add(url);
    return result;
  }
}

ProviderAttribution testAttribution(
  MusicIdentity identity, {
  String providerName = 'Jamendo',
  Uri? pageUrl,
  Uri? licenseUrl,
  String? licenseName,
}) =>
    ProviderAttribution(
      identity: identity,
      providerName: providerName,
      pageUrl: pageUrl,
      licenseUrl: licenseUrl,
      licenseName: licenseName,
    );
