/// Fallos del sistema de artwork, sin filtrar detalles de la tecnología (HTTP,
/// SDK, MediaStore…): quien los lanza traduce su error a uno de estos tipos.
///
/// Mapa conceptual:
/// - «No hay carátula» **no** es una excepción: es `UnavailableArtworkReference`
///   (al resolver) o `null` (al cargar).
/// - «No se pudo resolver la referencia» → [ArtworkResolutionException].
/// - «No se pudo cargar la imagen» → subtipos de [ArtworkLoadException].
///
/// La UI actual muestra el placeholder en cualquier caso; la distinción existe
/// para que fases futuras puedan reintentar, registrar o informar.
sealed class ArtworkException implements Exception {
  const ArtworkException();
}

/// El resolvedor no pudo decidir la referencia (transitorio o no).
/// [cause] es solo para depuración.
final class ArtworkResolutionException extends ArtworkException {
  const ArtworkResolutionException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'ArtworkResolutionException($message)';
}

/// La imagen de una referencia no se pudo cargar.
sealed class ArtworkLoadException extends ArtworkException {
  const ArtworkLoadException();
}

/// La URL no sirve para una petición (no es `http`/`https` con host).
final class ArtworkUnsupportedUrlException extends ArtworkLoadException {
  const ArtworkUnsupportedUrlException(this.url);

  final String url;

  @override
  String toString() => 'ArtworkUnsupportedUrlException($url)';
}

/// Fallo de red: sin conexión, DNS, TLS, corte o tiempo agotado.
/// Normalmente transitorio.
final class ArtworkNetworkException extends ArtworkLoadException {
  const ArtworkNetworkException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'ArtworkNetworkException($message)';
}

/// El servidor respondió con un estado que no es 2xx.
final class ArtworkHttpException extends ArtworkLoadException {
  const ArtworkHttpException(this.statusCode);

  final int statusCode;

  @override
  String toString() => 'ArtworkHttpException($statusCode)';
}

/// La respuesta fue 2xx pero su contenido no es una imagen utilizable
/// (vacío, demasiado grande o formato no reconocido).
final class ArtworkInvalidDataException extends ArtworkLoadException {
  const ArtworkInvalidDataException(this.reason);

  final String reason;

  @override
  String toString() => 'ArtworkInvalidDataException($reason)';
}
