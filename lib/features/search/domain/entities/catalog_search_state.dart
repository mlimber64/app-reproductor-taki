import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/catalog_search.dart';
import 'catalog_result_item.dart';

/// Estado de la búsqueda de catálogo (docs/PHASE_3_2B_SEARCH_STATE.md).
///
/// Cada caso dice algo distinto y no se convierten entre sí:
/// - [SearchIdle]: no hay búsqueda (consulta vacía o por debajo del mínimo).
/// - [SearchTyping]: el usuario edita; todavía no toca ejecutarla.
/// - [SearchLoading]: primera página en curso.
/// - [SearchResults]: hay resultados.
/// - [SearchEmpty]: búsqueda válida y completada **sin** resultados.
/// - [SearchFailed]: el catálogo falló.
/// - [SearchUnavailable]: no hay ningún catálogo registrado.
sealed class CatalogSearchState extends Equatable {
  const CatalogSearchState();
}

final class SearchIdle extends CatalogSearchState {
  const SearchIdle();

  @override
  List<Object?> get props => const [];
}

/// Consulta en espera del debounce. [text] es lo escrito, sin modificar.
///
/// [previous] es el último estado **asentado** ([SearchResults], [SearchEmpty]
/// o [SearchFailed]) o `null`: la UI puede seguir mostrándolo mientras el
/// usuario teclea, sin parpadear a vacío.
final class SearchTyping extends CatalogSearchState {
  const SearchTyping(this.text, {this.previous});

  final String text;
  final CatalogSearchState? previous;

  @override
  List<Object?> get props => [text, previous];
}

/// Primera página de [query] en curso.
final class SearchLoading extends CatalogSearchState {
  const SearchLoading(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

/// Estado de la carga de la página siguiente dentro de [SearchResults].
enum LoadMoreStatus {
  /// Nada en curso (puede haber más o no, según `hasMore`).
  idle,
  loading,

  /// La última página falló; los resultados siguen ahí y se puede reintentar.
  failed,
}

/// Resultados de [query]: ≥ 1 elemento.
///
/// - [hasMore]: se puede pedir otra página. Es `false` tras una página vacía,
///   aunque el catálogo dijera lo contrario.
/// - [nextOffset]: `offset` de la próxima página (`offset + limit` de la
///   anterior, como dice el contrato; no `items.length`, porque una fuente
///   puede descartar elementos inválidos).
/// - [loadMore]: un fallo de la página siguiente **no** pasa a [SearchFailed].
final class SearchResults extends CatalogSearchState {
  const SearchResults({
    required this.query,
    required this.items,
    required this.hasMore,
    required this.nextOffset,
    this.loadMore = LoadMoreStatus.idle,
  });

  final String query;
  final List<CatalogResultItem> items;
  final bool hasMore;
  final int nextOffset;
  final LoadMoreStatus loadMore;

  SearchResults withLoadMore(LoadMoreStatus status) => SearchResults(
        query: query,
        items: items,
        hasMore: hasMore,
        nextOffset: nextOffset,
        loadMore: status,
      );

  @override
  List<Object?> get props => [query, items, hasMore, nextOffset, loadMore];
}

/// La búsqueda de [query] terminó bien y no devolvió nada. No es un error.
final class SearchEmpty extends CatalogSearchState {
  const SearchEmpty(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

/// El catálogo falló al buscar [query] (primera página).
final class SearchFailed extends CatalogSearchState {
  const SearchFailed(this.query, this.failure);

  final String query;
  final CatalogSearchFailure failure;

  @override
  List<Object?> get props => [query, failure];
}

/// No hay ningún catálogo registrado: no se puede buscar. No es «sin
/// resultados» ni un fallo.
final class SearchUnavailable extends CatalogSearchState {
  const SearchUnavailable();

  @override
  List<Object?> get props => const [];
}
