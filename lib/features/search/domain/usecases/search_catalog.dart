import '../../../../core/domain/entities/catalog_search.dart';
import '../../../../core/domain/ports/catalog_search.dart';
import '../entities/catalog_result_item.dart';
import '../entities/catalog_search_policy.dart';

/// Busca por texto en **un** [CatalogSearch] y entrega resultados
/// provider-neutral ([CatalogResultItem]).
///
/// Una llamada = una petición lógica: no reintenta, no duerme y no repite (la
/// intermitencia de una fuente es asunto de su infraestructura).
///
/// - [text] se envía **tal cual** (sin normalizar); quien llama garantiza que
///   no está en blanco.
/// - Cada página pide `limit = pageSize` desde `offset`.
/// - Los fallos salen siempre como [CatalogSearchFailure]; un error inesperado
///   se traduce sin detalles de la tecnología.
class SearchCatalog {
  const SearchCatalog(
    this._search, {
    this.pageSize = CatalogSearchPolicy.defaultPageSize,
  });

  final CatalogSearch _search;
  final int pageSize;

  Future<CatalogResultPage> call(String text, {int offset = 0}) async {
    final query = CatalogSearchQuery(text: text, limit: pageSize, offset: offset);
    final CatalogSearchPage page;
    try {
      page = await _search.search(query);
    } on CatalogSearchFailure {
      rethrow;
    } catch (error) {
      throw CatalogSearchFailure(
        'fallo inesperado en la búsqueda',
        cause: error.runtimeType,
      );
    }
    return CatalogResultPage(
      items: [
        for (final song in page.songs)
          CatalogResultItem(song, attribution: page.attributionOf(song)),
      ],
      hasMore: page.hasMore,
    );
  }
}
