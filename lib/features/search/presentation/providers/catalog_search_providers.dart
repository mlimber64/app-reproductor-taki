import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/catalog/catalog_sources_providers.dart';
import '../../../../core/domain/entities/catalog_search.dart';
import '../../domain/entities/catalog_result_item.dart';
import '../../domain/entities/catalog_search_policy.dart';
import '../../domain/entities/catalog_search_state.dart';
import '../../domain/ports/search_scheduler.dart';
import '../../domain/usecases/search_catalog.dart';
import '../../infrastructure/timer_search_scheduler.dart';

final catalogSearchPolicyProvider =
    Provider<CatalogSearchPolicy>((ref) => const CatalogSearchPolicy());

final searchSchedulerProvider =
    Provider<SearchScheduler>((ref) => const TimerSearchScheduler());

/// Búsqueda sobre el catálogo registrado, o `null` si no hay ninguno.
///
/// Con una sola fuente usa esa; con varias usa la primera registrada, de forma
/// provisional (la política multi-fuente, D6, sigue pendiente: sin ranking ni
/// mezcla).
final searchCatalogProvider = Provider<SearchCatalog?>((ref) {
  final sources = ref.watch(catalogSourcesProvider);
  final policy = ref.watch(catalogSearchPolicyProvider);
  if (!sources.isAvailable) return null;
  return SearchCatalog(
    sources.searchIn(sources.available.first.source),
    pageSize: policy.pageSize,
  );
});

final catalogSearchProvider =
    NotifierProvider<CatalogSearchNotifier, CatalogSearchState>(
  CatalogSearchNotifier.new,
);

/// Controlador de la búsqueda de catálogo (docs/PHASE_3_2B_SEARCH_STATE.md).
///
/// - Cada operación que cambia la consulta o la reinicia sube la **generación**;
///   una respuesta de una generación anterior se descarta (el puerto no se
///   puede cancelar, así que no se aborta nada: solo se ignora el resultado).
/// - No reintenta nada: una operación = una llamada lógica.
/// - Sin catálogo registrado, el estado es [SearchUnavailable].
class CatalogSearchNotifier extends Notifier<CatalogSearchState> {
  SearchCatalog? _catalog;
  late CatalogSearchPolicy _policy;
  int _generation = 0;
  CancelScheduled? _cancelDebounce;

  /// Último estado asentado ([SearchResults] en reposo, [SearchEmpty] o
  /// [SearchFailed]); es lo que se restaura o se muestra mientras se teclea.
  CatalogSearchState? _settled;

  @override
  CatalogSearchState build() {
    _catalog = ref.watch(searchCatalogProvider);
    _policy = ref.watch(catalogSearchPolicyProvider);
    _settled = null;
    ref.onDispose(() {
      _generation++;
      _cancelPending();
    });
    return _catalog == null ? const SearchUnavailable() : const SearchIdle();
  }

  /// El texto del campo cambió. Se envía tal cual; solo para medir la longitud
  /// se ignoran los espacios exteriores.
  void setQuery(String text) {
    if (_catalog == null) return;
    final current = state;
    if (current is SearchTyping && current.text == text) return;
    if (current is SearchLoading && current.query == text) return;
    if (current is SearchResults && current.query == text) return;

    _cancelPending();
    _generation++;

    if (!_meetsMinimum(text)) {
      _settled = null;
      state = const SearchIdle();
      return;
    }

    // Volver a la consulta ya asentada (p. ej. teclear y borrar una letra) no
    // vuelve a buscar.
    final settled = _settled;
    if ((settled is SearchResults && settled.query == text) ||
        (settled is SearchEmpty && settled.query == text)) {
      state = settled!;
      return;
    }

    state = SearchTyping(text, previous: settled);
    _cancelDebounce = ref
        .read(searchSchedulerProvider)
        .schedule(_policy.debounce, () => _start(text));
  }

  /// El usuario confirmó la búsqueda (acción «buscar» del teclado): salta el
  /// debounce. No repite una consulta que ya tiene resultados o está en curso;
  /// sí relanza una vacía o fallida.
  void submit(String text) {
    if (!_meetsMinimum(text)) {
      setQuery(text);
      return;
    }
    final current = state;
    if (current is SearchResults && current.query == text) return;
    if (current is SearchLoading && current.query == text) return;
    _start(text);
  }

  /// Reintenta la primera página tras un [SearchFailed] (acción explícita).
  void retry() {
    final current = state;
    if (current is SearchFailed) _start(current.query);
  }

  /// Pide la página siguiente. Solo si hay [SearchResults] con `hasMore` y sin
  /// otra carga en curso. Tras un fallo, volver a llamarla lo reintenta.
  Future<void> loadMore() async {
    final catalog = _catalog;
    final current = state;
    if (catalog == null ||
        current is! SearchResults ||
        !current.hasMore ||
        current.loadMore == LoadMoreStatus.loading) {
      return;
    }

    final generation = _generation;
    state = current.withLoadMore(LoadMoreStatus.loading);

    final CatalogResultPage page;
    try {
      page = await catalog(current.query, offset: current.nextOffset);
    } on CatalogSearchFailure {
      if (generation != _generation) return;
      _settle(current.withLoadMore(LoadMoreStatus.failed));
      return;
    }
    if (generation != _generation) return;

    _settle(SearchResults(
      query: current.query,
      items: _withoutRepeats(current.items, page.items),
      // Una página vacía es el fin de la lista, diga lo que diga el catálogo.
      // Se mide sobre la página **tal como llegó**, antes de quitar repetidas:
      // una página no vacía pero toda repetida no es el fin de la lista.
      hasMore: page.items.isNotEmpty && page.hasMore,
      nextOffset: current.nextOffset + catalog.pageSize,
    ));
  }

  /// [existing] seguido de lo de [incoming] cuya identidad no se había visto:
  /// gana la primera aparición y se conserva el orden de llegada (también para
  /// repetidas dentro de la misma página). Solo cuenta `MusicIdentity` (fuente +
  /// id): nunca el título, el artista ni la carátula. No toca la paginación.
  List<CatalogResultItem> _withoutRepeats(
    List<CatalogResultItem> existing,
    List<CatalogResultItem> incoming,
  ) {
    final seen = {for (final item in existing) item.song.musicIdentity};
    return [
      ...existing,
      for (final item in incoming)
        if (seen.add(item.song.musicIdentity)) item,
    ];
  }

  bool _meetsMinimum(String text) =>
      text.trim().runes.length >= _policy.minimumQueryLength;

  void _cancelPending() {
    _cancelDebounce?.call();
    _cancelDebounce = null;
  }

  void _settle(CatalogSearchState next) {
    _settled = next;
    state = next;
  }

  Future<void> _start(String text) async {
    final catalog = _catalog;
    if (catalog == null) return;
    _cancelPending();
    final generation = ++_generation;
    state = SearchLoading(text);

    final CatalogResultPage page;
    try {
      page = await catalog(text);
    } on CatalogSearchFailure catch (failure) {
      if (generation != _generation) return;
      _settle(SearchFailed(text, failure));
      return;
    }
    if (generation != _generation) return;

    if (page.items.isEmpty) {
      _settle(SearchEmpty(text));
      return;
    }
    _settle(SearchResults(
      query: text,
      items: _withoutRepeats(const [], page.items),
      hasMore: page.hasMore,
      nextOffset: catalog.pageSize,
    ));
  }
}
