import '../entities/catalog_provider_info.dart';
import 'catalog_browse.dart';
import 'catalog_search.dart';

/// Registro de las fuentes de catálogo disponibles.
///
/// Es la única forma en que una pantalla llega a un [CatalogSearch]: no conoce
/// a ningún proveedor, solo etiquetas de fuente.
///
/// Contrato:
/// - [available] lista las fuentes registradas, en el orden de registro. Vacío
///   significa «no hay catálogo» (p. ej. sin credencial): no es un error ni
///   «sin resultados».
/// - [searchIn] devuelve el catálogo de `source` o lanza `UnknownCatalogSource`.
abstract interface class CatalogSources {
  List<CatalogProviderInfo> get available;

  bool get isAvailable;

  CatalogSearch searchIn(String source);

  /// Discovery for `source`, or `null` when that source cannot be browsed.
  /// Throws `UnknownCatalogSource` if `source` is not registered.
  CatalogBrowse? browseIn(String source);
}
