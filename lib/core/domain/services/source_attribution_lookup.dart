import '../entities/attribution_lookup_failure.dart';
import '../entities/attribution_lookup_result.dart';
import '../entities/music_identity.dart';
import '../ports/attribution_lookup.dart';

/// Enruta cada identidad al [AttributionLookup] **de su fuente**
/// (`identity.source`). Misma idea que `SourceSongLookup`: una fuente nueva se
/// registra añadiéndola al mapa.
///
/// - Una identidad de una fuente **sin lookup registrado** es `absent` (no se
///   inventa nada).
/// - Los lookups se consultan una vez por fuente, en paralelo.
/// - Si un lookup falla, el fallo se **propaga** (como en `SourceSongLookup`):
///   el lote entero falla y **no** se disfraza de `absent`.
/// - Hace cumplir el contrato: una identidad que el lookup no contabilizó pasa a
///   `absent`; una atribución devuelta bajo una identidad que no es la suya, o
///   para una identidad no pedida, es un `AttributionLookupFailure`.
class SourceAttributionLookup implements AttributionLookup {
  SourceAttributionLookup(Map<String, AttributionLookup> bySource)
      : _bySource = Map.unmodifiable(bySource);

  final Map<String, AttributionLookup> _bySource;

  @override
  Future<AttributionLookupResult> findAll(
    Iterable<MusicIdentity> identities,
  ) async {
    final bySource = <String, Set<MusicIdentity>>{};
    for (final identity in identities) {
      (bySource[identity.source] ??= {}).add(identity);
    }

    final unrouted = <MusicIdentity>{};
    final pending = <Future<AttributionLookupResult>>[];
    for (final MapEntry(key: source, value: group) in bySource.entries) {
      final lookup = _bySource[source];
      if (lookup == null) {
        unrouted.addAll(group);
        continue;
      }
      pending.add(_resolve(source, lookup, group));
    }

    var result = AttributionLookupResult(absent: unrouted);
    for (final partial in await Future.wait(pending)) {
      result = result.merge(partial);
    }
    return result;
  }

  Future<AttributionLookupResult> _resolve(
    String source,
    AttributionLookup lookup,
    Set<MusicIdentity> group,
  ) async {
    final AttributionLookupResult raw;
    try {
      raw = await lookup.findAll(group);
    } on AttributionLookupFailure {
      rethrow;
    } catch (error) {
      throw AttributionLookupFailure(
        'el lookup de la fuente falló',
        source: source,
        cause: error.runtimeType,
      );
    }

    for (final MapEntry(key: identity, value: attribution)
        in raw.found.entries) {
      if (!group.contains(identity)) {
        throw AttributionLookupFailure(
          'devolvió una atribución para una identidad que no se pidió '
          '($identity)',
          source: source,
        );
      }
      if (attribution.identity != identity) {
        throw AttributionLookupFailure(
          'devolvió la atribución de ${attribution.identity} para $identity',
          source: source,
        );
      }
    }

    // Ya validado: `found` solo trae identidades pedidas. Las no contabilizadas
    // son `absent`.
    return AttributionLookupResult(
      found: raw.found,
      absent: group.difference(raw.found.keys.toSet()),
    );
  }
}
