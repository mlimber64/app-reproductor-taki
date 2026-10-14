/// Describe una fuente de catálogo registrada: lo mínimo que una pantalla
/// necesita saber de ella sin conocer a su proveedor.
///
/// - [source] es **la misma** etiqueta opaca de `MusicIdentity.source` (no es
///   un identificador nuevo): las canciones que devuelve esa fuente la llevan.
/// - [label] es el nombre para mostrar; lo aporta quien cablea la fuente.
///
/// Es solo descripción: no busca, no reproduce y no dice si la fuente está
/// caída (eso es un `CatalogSearchFailure` al buscar). Que exista en el
/// registro significa que está disponible.
final class CatalogProviderInfo {
  CatalogProviderInfo({required this.source, required this.label}) {
    if (source.trim().isEmpty) {
      throw ArgumentError.value(source, 'source', 'no puede estar vacío');
    }
    if (label.trim().isEmpty) {
      throw ArgumentError.value(label, 'label', 'no puede estar vacío');
    }
  }

  final String source;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is CatalogProviderInfo &&
      other.source == source &&
      other.label == label;

  @override
  int get hashCode => Object.hash(CatalogProviderInfo, source, label);

  @override
  String toString() => 'CatalogProviderInfo($source, $label)';
}

/// Se pidió el catálogo de una fuente que no está registrada.
final class UnknownCatalogSource implements Exception {
  const UnknownCatalogSource(this.source);

  final String source;

  @override
  String toString() => 'UnknownCatalogSource($source)';
}
