import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/catalog/catalog_sources_providers.dart';
import '../../../../core/domain/entities/catalog_search.dart';
import '../../../../core/domain/entities/catalog_section.dart';
import '../../domain/entities/catalog_result_item.dart';
import '../../domain/entities/catalog_search_policy.dart';
import '../../domain/entities/catalog_search_state.dart';
import '../../domain/ports/search_scheduler.dart';
import '../../domain/usecases/get_featured_songs.dart';
import '../../domain/usecases/search_catalog.dart';
import '../../infrastructure/timer_search_scheduler.dart';

final catalogSearchPolicyProvider =
    Provider<CatalogSearchPolicy>((ref) => const CatalogSearchPolicy());

final searchSchedulerProvider =
    Provider<SearchScheduler>((ref) => const TimerSearchScheduler());

/// The source the user picked in the search screen, or `null` for "the
/// default". It is only a preference: [activeCatalogSourceProvider] decides
/// what is really used.
final selectedCatalogSourceProvider =
    NotifierProvider<SelectedCatalogSource, String?>(SelectedCatalogSource.new);

class SelectedCatalogSource extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String source) => state = source;
}

/// The source search and discovery use: the picked one while it is still
/// registered, otherwise the first registered. `null` when there is none.
final activeCatalogSourceProvider = Provider<String?>((ref) {
  final available = ref.watch(catalogSourcesProvider).available;
  if (available.isEmpty) return null;
  final selected = ref.watch(selectedCatalogSourceProvider);
  for (final info in available) {
    if (info.source == selected) return selected;
  }
  return available.first.source;
});

/// Search over the active source, or `null` if there is no catalog. Results of
/// different sources are never mixed (the multi-source ranking policy, D6, is
/// still open): the user picks the source.
final searchCatalogProvider = Provider<SearchCatalog?>((ref) {
  final sources = ref.watch(catalogSourcesProvider);
  final policy = ref.watch(catalogSearchPolicyProvider);
  final active = ref.watch(activeCatalogSourceProvider);
  if (active == null) return null;
  return SearchCatalog(
    sources.searchIn(active),
    pageSize: policy.pageSize,
  );
});

/// Featured songs of the active source when it can be browsed, else of the
/// first registered source that can; `null` when none can (the screen then
/// keeps its plain idle view).
final featuredCatalogProvider = Provider<GetFeaturedSongs?>((ref) {
  final sources = ref.watch(catalogSourcesProvider);
  final active = ref.watch(activeCatalogSourceProvider);
  final order = [
    ?active,
    for (final info in sources.available)
      if (info.source != active) info.source,
  ];
  for (final source in order) {
    final browse = sources.browseIn(source);
    if (browse != null) return GetFeaturedSongs(browse);
  }
  return null;
});

/// The songs of one discovery section, loaded the first time a carousel asks
/// for them and kept for the session. Each section is independent: one that
/// fails does not affect the others, and `ref.invalidate` refreshes one.
/// Failures surface as [CatalogSearchFailure] in the `AsyncValue`.
final featuredSectionSongsProvider =
    FutureProvider.family<List<CatalogResultItem>, CatalogSection>(
  (ref, section) {
    final featured = ref.watch(featuredCatalogProvider);
    if (featured == null) return const <CatalogResultItem>[];
    return featured(section);
  },
);

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
