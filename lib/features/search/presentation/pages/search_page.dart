import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/artwork/album_artwork_builder.dart';
import '../../../../core/domain/entities/song.dart';
import '../../../../core/theme/taki_colors.dart';
import '../../../../core/theme/taki_spacing.dart';
import '../../../../core/theme/taki_typography.dart';
import '../../../../core/widgets/song_actions.dart';
import '../../../../core/widgets/taki_button.dart';
import '../../../../core/widgets/taki_empty_state.dart';
import '../../../../core/widgets/taki_error_state.dart';
import '../../../../core/widgets/taki_search_field.dart';
import '../../../../core/widgets/taki_song_tile.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../domain/entities/catalog_search_state.dart';
import '../providers/catalog_search_providers.dart';
import '../search_texts.dart';
import '../widgets/featured_view.dart';

/// Búsqueda en el catálogo (docs/PHASE_3_2C_SEARCH_UI.md).
///
/// Solo presenta el estado de `catalogSearchProvider` (3.2B) y le pasa lo que
/// el usuario hace; no busca, no hace debounce ni reintenta por su cuenta, y no
/// conoce a ningún proveedor.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key, required this.onSongActions});

  static const String title = 'Buscar';

  /// Menú de acciones de una canción (⋯ o pulsación larga). Lo implementa
  /// `app/` (cola, favoritos, playlists) y lo inyecta el router.
  final ShowSongActions onSongActions;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _wasActive = false;

  /// Últimos resultados vistos, para no vaciar la lista mientras se busca una
  /// consulta nueva. Se olvidan al volver a `Idle`, `Empty` o `Failed`.
  SearchResults? _lastResults;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // La pestaña vive en un `IndexedStack`: «activa» = sus tickers corren.
    final active = TickerMode.valuesOf(context).enabled;
    // Al entrar NO se pide el foco: el teclado taparía los carruseles, que son
    // lo primero que se ve. Se abre cuando el usuario toca el campo.
    if (!active && _wasActive) {
      // Al salir, el teclado no se queda abierto sobre otra pestaña.
      _focus.unfocus();
    }
    _wasActive = active;
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _remember(CatalogSearchState state) {
    switch (state) {
      case SearchResults():
        _lastResults = state;
      case SearchIdle() || SearchEmpty() || SearchFailed():
        _lastResults = null;
      case SearchTyping() || SearchLoading() || SearchUnavailable():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(catalogSearchProvider);
    final notifier = ref.read(catalogSearchProvider.notifier);
    _remember(state);

    return Scaffold(
      appBar: AppBar(title: const Text(SearchPage.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TakiSpacing.pageGutter,
              TakiSpacing.sm,
              TakiSpacing.pageGutter,
              TakiSpacing.sm,
            ),
            child: TakiSearchField(
              controller: _controller,
              focusNode: _focus,
              hintText: SearchTexts.hint,
              enabled: state is! SearchUnavailable,
              onChanged: notifier.setQuery,
              onSubmitted: notifier.submit,
            ),
          ),
          Expanded(child: _body(state, notifier)),
        ],
      ),
    );
  }

  Widget _body(CatalogSearchState state, CatalogSearchNotifier notifier) {
    return switch (state) {
      SearchIdle() => _FeaturedSection(onPlayAt: _playFrom, onActions: _actions),
      // Escribiendo: se conservan los resultados anteriores; un vacío o un
      // error anteriores no se muestran (no son de esta consulta).
      SearchTyping(:final previous) => previous is SearchResults
          ? _ResultsList(
              results: previous,
              onPlay: _play,
              onActions: _actions,
            )
          : _FeaturedSection(onPlayAt: _playFrom, onActions: _actions),
      SearchLoading() => switch (_lastResults) {
          final last? => _ResultsList(
              results: last,
              searching: true,
              onPlay: _play,
              onActions: _actions,
            ),
          null => const _LoadingView(),
        },
      SearchResults() =>
        _ResultsList(results: state, onPlay: _play, onActions: _actions),
      SearchEmpty() => const TakiEmptyState(
          kind: TakiEmptyStateKind.noResults,
          icon: Icons.search_off_rounded,
          title: SearchTexts.emptyTitle,
          description: SearchTexts.emptyMessage,
        ),
      SearchFailed() => TakiErrorState(
          title: SearchTexts.failedTitle,
          message: SearchTexts.failedMessage,
          action: TakiStateAction(
            label: SearchTexts.retry,
            onPressed: notifier.retry,
          ),
        ),
      SearchUnavailable() => const TakiEmptyState(
          icon: Icons.cloud_off_rounded,
          title: SearchTexts.unavailableTitle,
          description: SearchTexts.unavailableMessage,
        ),
    };
  }

  /// ⋯ o pulsación larga: el menú de acciones de siempre, con la `Song` tal
  /// cual (su `MusicIdentity` no se toca). No cambia lo que hace el tap.
  Future<void> _actions(Song song) async {
    FocusScope.of(context).unfocus();
    await widget.onSongActions(context, ref, song);
  }

  /// Tap on a featured card: plays the whole featured list starting there, so
  /// the queue follows the grid like in a playlist.
  Future<void> _playFrom(List<Song> songs, int index) async {
    FocusScope.of(context).unfocus();
    await ref.read(playSongsProvider).call(songs, index);
    unawaited(ref.read(notificationPermissionProvider).requestIfNeeded());
  }

  /// Tap en un resultado: cierra el teclado y reproduce con el caso de uso de
  /// siempre. Cómo queda la cola (D7) sigue sin decidirse: hoy `PlaySongs`
  /// reemplaza la cola, y aquí solo se le pasa la canción tocada.
  Future<void> _play(Song song) async {
    FocusScope.of(context).unfocus();
    await ref.read(playSongsProvider).call([song], 0);
    // Después de arrancar: si se rechaza, la música sigue sonando.
    unawaited(ref.read(notificationPermissionProvider).requestIfNeeded());
  }
}

/// The featured grid with the playback state it needs to mark the playing
/// card. It lives here, next to the page's own Player import, so the grid
/// widget itself stays free of other features.
class _FeaturedSection extends ConsumerWidget {
  const _FeaturedSection({required this.onPlayAt, required this.onActions});

  final Future<void> Function(List<Song> songs, int index) onPlayAt;
  final Future<void> Function(Song song) onActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIdentity = ref.watch(
      currentSongProvider.select((song) => song.valueOrNull?.musicIdentity),
    );
    final isPlaying = ref.watch(
          playbackStateProvider.select((state) => state.valueOrNull?.isPlaying),
        ) ??
        false;

    return FeaturedView(
      fallback: const _IdleView(),
      currentIdentity: currentIdentity,
      isPlaying: isPlaying,
      onPlayAt: onPlayAt,
      onActions: onActions,
    );
  }
}

class _IdleView extends ConsumerWidget {
  const _IdleView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final minimum = ref.watch(catalogSearchPolicyProvider).minimumQueryLength;
    return TakiEmptyState(
      icon: Icons.search_rounded,
      title: SearchTexts.idleTitle,
      description: SearchTexts.idleMessage(minimum),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: SearchTexts.searching,
        liveRegion: true,
        child: const CircularProgressIndicator(),
      ),
    );
  }
}

/// Lista de resultados con su pie de paginación.
///
/// [searching]: se está buscando otra consulta; la lista sigue visible, con un
/// avance fino arriba, y no pide más páginas.
class _ResultsList extends ConsumerWidget {
  const _ResultsList({
    required this.results,
    required this.onPlay,
    required this.onActions,
    this.searching = false,
  });

  final SearchResults results;
  final bool searching;
  final Future<void> Function(Song song) onPlay;
  final Future<void> Function(Song song) onActions;

  /// Cuánto falta por desplazar para pedir la siguiente página (≈ 5 filas).
  static const double _loadMoreExtent = 5 * TakiSongTile.minHeight;

  /// Alto reservado para el avance de búsqueda: la lista no salta al aparecer.
  static const double _progressHeight = 2;

  /// Solo con la carga en reposo: tras un fallo, la página se reintenta con el
  /// botón, nunca por desplazarse. (Que haya más páginas o que no se esté
  /// buscando otra consulta lo vigila el controlador.)
  bool get _canPaginate => results.loadMore == LoadMoreStatus.idle;

  void _maybeLoadMore(WidgetRef ref, ScrollMetrics metrics) {
    if (!_canPaginate || metrics.extentAfter >= _loadMoreExtent) return;
    // Fuera del layout/notificación en curso.
    scheduleMicrotask(
      () => ref.read(catalogSearchProvider.notifier).loadMore(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = results.items;
    final currentIdentity = ref.watch(
      currentSongProvider.select((song) => song.valueOrNull?.musicIdentity),
    );
    final isPlaying = ref.watch(
          playbackStateProvider.select((state) => state.valueOrNull?.isPlaying),
        ) ??
        false;

    return Column(
      children: [
        SizedBox(
          height: _progressHeight,
          child: searching
              ? Semantics(
                  label: SearchTexts.searching,
                  liveRegion: true,
                  child: const LinearProgressIndicator(
                    minHeight: _progressHeight,
                    color: TakiColors.primary,
                    backgroundColor: TakiColors.surface,
                  ),
                )
              : null,
        ),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              _maybeLoadMore(ref, notification.metrics);
              return false;
            },
            child: NotificationListener<ScrollMetricsNotification>(
              onNotification: (notification) {
                _maybeLoadMore(ref, notification.metrics);
                return false;
              },
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverPrototypeExtentList.builder(
                    prototypeItem: TakiSongTile(song: items.first.song),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final song = items[index].song;
                      return AlbumArtworkBuilder.reference(
                        reference: song.artwork,
                        size: TakiSongTile.artworkSize,
                        builder: (_, artwork) => TakiSongTile(
                          song: song,
                          artwork: artwork,
                          playback: song.musicIdentity != currentIdentity
                              ? TakiNowPlaying.none
                              : isPlaying
                                  ? TakiNowPlaying.playing
                                  : TakiNowPlaying.paused,
                          onTap: () => onPlay(song),
                          onLongPress: () => onActions(song),
                          onMore: () => onActions(song),
                        ),
                      );
                    },
                  ),
                  SliverToBoxAdapter(
                    child: searching
                        ? const SizedBox.shrink()
                        : _Footer(results: results),
                  ),
                  // Aire al final para que la última fila no quede pegada al
                  // mini player.
                  const SliverToBoxAdapter(
                    child: SizedBox(height: TakiSpacing.lg),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Pie de la lista: cargando más, fallo con «Reintentar», o nada.
class _Footer extends ConsumerWidget {
  const _Footer({required this.results});

  final SearchResults results;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (results.loadMore) {
      LoadMoreStatus.idle => const SizedBox.shrink(),
      LoadMoreStatus.loading => Padding(
          padding: const EdgeInsets.all(TakiSpacing.lg),
          child: Center(
            child: Semantics(
              label: SearchTexts.loadingMore,
              liveRegion: true,
              child: const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
      LoadMoreStatus.failed => Padding(
          padding: const EdgeInsets.all(TakiSpacing.lg),
          child: Column(
            children: [
              Text(
                SearchTexts.loadMoreFailed,
                textAlign: TextAlign.center,
                style: TakiTypography.body
                    .copyWith(color: TakiColors.textSecondary),
              ),
              const SizedBox(height: TakiSpacing.sm),
              TakiButton(
                label: SearchTexts.retry,
                variant: TakiButtonVariant.tertiary,
                onPressed: () =>
                    ref.read(catalogSearchProvider.notifier).loadMore(),
              ),
            ],
          ),
        ),
    };
  }
}
