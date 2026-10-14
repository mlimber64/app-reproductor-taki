/// La resolución de identidades no pudo completarse (fallo transitorio o de la
/// fuente): red, lectura de la biblioteca, contrato roto…
///
/// No significa «la canción no existe» (eso es `SongLookupResult.missing`) ni
/// «no hay fuente» (`unsupported`): quien la recibe puede reintentar. [source]
/// es la etiqueta de la fuente que falló, si se conoce; [cause] es solo para
/// depuración. No filtra detalles de la tecnología (HTTP, MediaStore…).
final class SongLookupFailure implements Exception {
  const SongLookupFailure(this.message, {this.source, this.cause});

  final String message;
  final String? source;
  final Object? cause;

  @override
  String toString() => 'SongLookupFailure(${source ?? '-'}: $message)';
}
