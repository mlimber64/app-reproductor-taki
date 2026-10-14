import '../entities/catalog_search.dart';

/// Búsqueda de solo lectura en el catálogo de una fuente.
///
/// Los errores se propagan como [CatalogSearchFailure].
abstract interface class CatalogSearch {
  Future<CatalogSearchPage> search(CatalogSearchQuery query);
}
