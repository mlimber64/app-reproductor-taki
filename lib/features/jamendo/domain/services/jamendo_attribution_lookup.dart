import '../../../../core/domain/entities/attribution_lookup_failure.dart';
import '../../../../core/domain/entities/attribution_lookup_result.dart';
import '../../../../core/domain/entities/music_identity.dart';
import '../../../../core/domain/entities/provider_attribution.dart';
import '../../../../core/domain/ports/attribution_lookup.dart';
import '../entities/jamendo_exception.dart';
import '../entities/jamendo_track.dart';
import '../ports/jamendo_api.dart';

/// Resuelve la atribución de identidades `jamendo` en lote (una consulta por
/// todos los ids, la misma operación que usa `JamendoSongLookup`).
///
/// - Las identidades de otras fuentes salen como `absent` (no son suyas).
/// - Un id que la API no devuelve es `absent`.
/// - La atribución es la de `JamendoTrack.attribution`; no se persiste ni se
///   guarda en caché (cada llamada va a la API).
/// - Un track con un id que no se pidió es un fallo del contrato de la API.
/// - Cualquier error de la API sale como [AttributionLookupFailure], nunca como
///   ausencia.
class JamendoAttributionLookup implements AttributionLookup {
  const JamendoAttributionLookup(this._api);

  final JamendoApi _api;

  @override
  Future<AttributionLookupResult> findAll(
    Iterable<MusicIdentity> identities,
  ) async {
    final wanted = identities.toSet();
    final mine = {
      for (final identity in wanted)
        if (identity.source == jamendoSource) identity,
    };
    final others = wanted.difference(mine);
    if (mine.isEmpty) return AttributionLookupResult(absent: others);

    final List<JamendoTrack> tracks;
    try {
      tracks = await _api.tracksByIds([for (final i in mine) i.externalId]);
    } on JamendoException catch (error) {
      throw AttributionLookupFailure(
        'no se pudo consultar Jamendo',
        source: jamendoSource,
        cause: error,
      );
    } catch (error) {
      throw AttributionLookupFailure(
        'fallo inesperado consultando Jamendo',
        source: jamendoSource,
        cause: error.runtimeType,
      );
    }

    final found = <MusicIdentity, ProviderAttribution>{};
    for (final track in tracks) {
      final identity = MusicIdentity(jamendoSource, track.id);
      if (!mine.contains(identity)) {
        throw const AttributionLookupFailure(
          'Jamendo devolvió un track que no se pidió',
          source: jamendoSource,
        );
      }
      found[identity] = track.attribution;
    }
    return AttributionLookupResult(
      found: found,
      absent: {...others, ...mine.difference(found.keys.toSet())},
    );
  }
}
