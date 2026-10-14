/// La resolución de atribuciones no pudo completarse (red, credencial, contrato
/// roto…).
///
/// No significa «no hay atribución» (eso es `AttributionLookupResult.absent`):
/// quien la recibe puede reintentar. [source] es la etiqueta de la fuente que
/// falló, si se conoce; [cause] es solo para depuración y no filtra detalles de
/// la tecnología.
final class AttributionLookupFailure implements Exception {
  const AttributionLookupFailure(this.message, {this.source, this.cause});

  final String message;
  final String? source;
  final Object? cause;

  @override
  String toString() => 'AttributionLookupFailure(${source ?? '-'}: $message)';
}
