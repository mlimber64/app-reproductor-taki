import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/music_identity.dart';
import '../../../../core/domain/entities/provider_attribution.dart';
import '../../../../core/lookup/attribution_lookup_providers.dart';

/// Atribución de la canción con esa identidad, resuelta con el contrato
/// provider-agnostic `AttributionLookup`.
///
/// - `data(attribution)`: la fuente la dio. `data(null)`: **ausente** (no es un
///   error). `error`: fallo real del lookup; **no** se convierte en ausencia
///   aquí: la pantalla decide no mostrar nada.
/// - Es una familia por identidad: una respuesta tardía de otra canción vive en
///   otra entrada y nunca puede pintarse sobre la actual.
final attributionProvider = FutureProvider.autoDispose
    .family<ProviderAttribution?, MusicIdentity>((ref, identity) async {
  final result = await ref.watch(attributionLookupProvider).findAll([identity]);
  return result.found[identity];
});
