import 'music_identity.dart';
import 'provider_attribution.dart';

/// Resultado de resolver la atribución de un conjunto de [MusicIdentity].
///
/// Cada identidad pedida cae en **exactamente un** cubo, y los dos dicen cosas
/// distintas:
/// - [found]: la fuente la conoce y devuelve su atribución. La clave coincide
///   con `attribution.identity`. La atribución puede ser **incompleta**
///   (`ProviderAttribution.isComplete`): sigue siendo `found`.
/// - [absent]: **no hay atribución** para esa identidad (fuente sin atribución,
///   como la local; fuente no registrada; canción que la fuente ya no conoce).
///   No es un error y no se reintenta por ello.
///
/// Un **fallo real** (red, credencial, contrato roto…) no es un cubo: se lanza
/// como `AttributionLookupFailure`.
final class AttributionLookupResult {
  const AttributionLookupResult({
    this.found = const {},
    this.absent = const {},
  });

  static const AttributionLookupResult empty = AttributionLookupResult();

  final Map<MusicIdentity, ProviderAttribution> found;
  final Set<MusicIdentity> absent;

  /// Unión de dos resultados de conjuntos de identidades disjuntos.
  AttributionLookupResult merge(AttributionLookupResult other) =>
      AttributionLookupResult(
        found: {...found, ...other.found},
        absent: {...absent, ...other.absent},
      );

  @override
  String toString() =>
      'AttributionLookupResult(found: ${found.length}, absent: ${absent.length})';
}
