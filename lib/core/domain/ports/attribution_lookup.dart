import '../entities/attribution_lookup_result.dart';
import '../entities/music_identity.dart';

/// Resuelve la **atribución** de canciones por identidad:
/// `MusicIdentity → ProviderAttribution?`, sin depender de que exista la
/// pantalla de búsqueda que la trajo.
///
/// Es solo resolución de atribución: no busca, no reproduce, no persiste nada
/// (ni atribución, ni URLs, ni licencia) y no conoce la UI.
///
/// Contrato de [findAll]:
/// - Recibe un conjunto de identidades (los duplicados se tratan como una) que
///   **pueden ser de varias fuentes**.
/// - Devuelve un [AttributionLookupResult] donde **cada identidad pedida está en
///   exactamente un cubo**: `found` o `absent`.
/// - Una identidad de una fuente que esta implementación no maneja es `absent`,
///   no un error.
/// - Un fallo real se lanza como `AttributionLookupFailure`; **nunca** se
///   convierte en `absent`.
/// - Es por lotes a propósito: una sola llamada para muchas identidades.
abstract interface class AttributionLookup {
  Future<AttributionLookupResult> findAll(Iterable<MusicIdentity> identities);
}
