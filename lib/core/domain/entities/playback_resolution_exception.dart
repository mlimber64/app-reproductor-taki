import 'music_identity.dart';

/// Fallo al resolver cómo reproducir una canción.
///
/// Distingue los casos **sin filtrar detalles de la tecnología** (HTTP, SDK,
/// MediaStore…): quien lo lanza traduce su error a uno de estos tipos.
///
/// Mapa conceptual de casos:
/// - «la canción existe pero no se puede reproducir» → **no** es una
///   excepción: es `UnavailableResource`.
/// - «esta fuente no conoce la identidad» → [IdentityNotFound].
/// - «no se pudo resolver ahora» (transitorio o no) → [PlaybackResolutionError].
/// - Casos futuros (fuente no disponible, sin red…) serán nuevos subtipos de
///   esta clase; no hace falta crearlos hasta que exista una fuente que los
///   produzca.
sealed class PlaybackResolutionException implements Exception {
  const PlaybackResolutionException();
}

/// El resolvedor no conoce esta identidad (p. ej. su fuente no es la suya).
final class IdentityNotFound extends PlaybackResolutionException {
  const IdentityNotFound(this.identity);

  final MusicIdentity identity;

  @override
  String toString() => 'IdentityNotFound($identity)';
}

/// La resolución falló por un motivo que no es «identidad desconocida».
///
/// Puede ser transitorio: quien la recibe puede reintentar. [cause] es solo
/// para depuración y es opaca para el dominio.
final class PlaybackResolutionError extends PlaybackResolutionException {
  const PlaybackResolutionError(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'PlaybackResolutionError($message)';
}
