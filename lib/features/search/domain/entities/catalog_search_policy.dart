/// Parámetros de UX de la búsqueda de catálogo (decisiones D2–D4 de la fase
/// 3.2A, aprobadas).
final class CatalogSearchPolicy {
  const CatalogSearchPolicy({
    this.minimumQueryLength = defaultMinimumQueryLength,
    this.debounce = defaultDebounce,
    this.pageSize = defaultPageSize,
  })  : assert(minimumQueryLength > 0),
        assert(pageSize > 0);

  /// Caracteres (puntos de código, sin espacios exteriores) que debe tener la
  /// consulta para ejecutarse.
  static const int defaultMinimumQueryLength = 2;

  /// Espera desde la última edición antes de buscar.
  static const Duration defaultDebounce = Duration(milliseconds: 400);

  /// Canciones por página (`limit`).
  static const int defaultPageSize = 20;

  final int minimumQueryLength;
  final Duration debounce;
  final int pageSize;
}
