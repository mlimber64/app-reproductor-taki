import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/entities/catalog_search.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/core/domain/entities/provider_attribution.dart';
import 'package:taki/core/domain/entities/song.dart';
import 'package:taki/features/search/domain/entities/catalog_search_state.dart';
import 'package:taki/features/search/presentation/providers/catalog_search_providers.dart';

import '../../helpers/catalog_fakes.dart';
import '../../helpers/universal_song.dart';

const _debounce = Duration(milliseconds: 400);

/// Canción con identidad `source:id` y título propio.
Song song(String source, String id, {String? title}) => buildUniversalSong(
      MusicIdentity(source, id),
      title: title ?? 'T$id',
    );

CatalogSearchPage page(
  List<Song> songs, {
  bool hasMore = false,
  Map<MusicIdentity, ProviderAttribution>? attributions,
}) =>
    CatalogSearchPage(songs, hasMore: hasMore, attributions: attributions ?? const {});

void main() {
  late FakeCatalogSearch search;
  late ManualSearchScheduler clock;
  late ProviderContainer container;

  CatalogSearchNotifier notifier() =>
      container.read(catalogSearchProvider.notifier);
  SearchResults results() => container.read(catalogSearchProvider) as SearchResults;
  List<String> ids() => [
        for (final i in results().items)
          '${i.song.musicIdentity.source}:${i.song.musicIdentity.externalId}',
      ];

  Future<void> typeAndSearch(String text) async {
    notifier().setQuery(text);
    clock.advance(_debounce);
    await pumpEventQueue();
  }

  void serve(Map<int, CatalogSearchPage> pages) {
    search = FakeCatalogSearch((q) async => pages[q.offset] ?? page([]));
    container = catalogContainer(search: search, scheduler: clock);
    addTearDown(container.dispose);
  }

  setUp(() => clock = ManualSearchScheduler());

  group('sin repetidas', () {
    test('todo se conserva en orden', () async {
      serve({0: page([song('f', 'A'), song('f', 'B'), song('f', 'C')], hasMore: true),
             20: page([song('f', 'D'), song('f', 'E')])});
      await typeAndSearch('beat');
      await notifier().loadMore();
      expect(ids(), ['f:A', 'f:B', 'f:C', 'f:D', 'f:E']);
    });
  });

  group('repetidas', () {
    test('dentro de la misma página (primera): gana la primera aparición',
        () async {
      serve({0: page([song('f', 'A'), song('f', 'B'), song('f', 'A'), song('f', 'C'), song('f', 'B')])});
      await typeAndSearch('beat');
      expect(ids(), ['f:A', 'f:B', 'f:C']);
    });

    test('dentro de una página posterior', () async {
      serve({0: page([song('f', 'A')], hasMore: true),
             20: page([song('f', 'B'), song('f', 'B'), song('f', 'C'), song('f', 'B')])});
      await typeAndSearch('beat');
      await notifier().loadMore();
      expect(ids(), ['f:A', 'f:B', 'f:C']);
    });

    test('entre páginas: A B C + C D E = A B C D E', () async {
      serve({0: page([song('f', 'A'), song('f', 'B'), song('f', 'C')], hasMore: true),
             20: page([song('f', 'C'), song('f', 'D'), song('f', 'E')])});
      await typeAndSearch('beat');
      await notifier().loadMore();
      expect(ids(), ['f:A', 'f:B', 'f:C', 'f:D', 'f:E']);
    });

    test('repetida en la primera posición de la página posterior', () async {
      serve({0: page([song('f', 'A'), song('f', 'B')], hasMore: true),
             20: page([song('f', 'B'), song('f', 'C')])});
      await typeAndSearch('beat');
      await notifier().loadMore();
      expect(ids(), ['f:A', 'f:B', 'f:C']);
    });

    test('misma identidad con distinto título: se queda la primera', () async {
      serve({0: page([song('f', 'A', title: 'Original')], hasMore: true),
             20: page([song('f', 'A', title: 'Otro título'), song('f', 'B')])});
      await typeAndSearch('beat');
      await notifier().loadMore();
      expect(ids(), ['f:A', 'f:B']);
      expect(results().items.first.song.title, 'Original');
    });

    test('mismo título con identidades distintas: ambas permanecen', () async {
      serve({0: page([song('f', 'A', title: 'Igual'), song('f', 'B', title: 'Igual')], hasMore: true),
             20: page([song('f', 'C', title: 'Igual')])});
      await typeAndSearch('beat');
      await notifier().loadMore();
      expect(ids(), ['f:A', 'f:B', 'f:C']);
    });

    test('misma externalId en fuentes distintas nunca colisiona', () async {
      serve({0: page([song('local', '42'), song('jamendo', '42')], hasMore: true),
             20: page([song('local', '42'), song('jamendo', '42'), song('other', '42')])});
      await typeAndSearch('beat');
      await notifier().loadMore();
      expect(ids(), ['local:42', 'jamendo:42', 'other:42']);
    });

    test('solo cuenta la identidad: no el artista, la carátula ni la duración',
        () async {
      final a = buildUniversalSong(MusicIdentity('f', 'A'), title: 'X', artist: 'Y', durationMs: 1);
      final b = buildUniversalSong(MusicIdentity('f', 'B'), title: 'X', artist: 'Y', durationMs: 1);
      serve({0: page([a, b])});
      await typeAndSearch('beat');
      expect(ids(), ['f:A', 'f:B']);
    });
  });

  group('atribución', () {
    test('se conserva la de la primera aparición', () async {
      final first = fakeAttribution('A');
      final second = ProviderAttribution(
          identity: fakeIdentity('A'), providerName: 'Otra');
      serve({
        0: page([fakeSong('A')], hasMore: true, attributions: {fakeIdentity('A'): first}),
        20: page([fakeSong('A'), fakeSong('B')],
            attributions: {fakeIdentity('A'): second, fakeIdentity('B'): fakeAttribution('B')}),
      });
      await typeAndSearch('beat');
      await notifier().loadMore();
      final items = results().items;
      expect(items, hasLength(2));
      expect(items[0].attribution, first);
      expect(items[1].attribution, fakeAttribution('B'));
    });
  });

  group('paginación y deduplicación', () {
    test('el offset avanza por limit, no por lo visible', () async {
      serve({0: page([song('f', 'A'), song('f', 'B'), song('f', 'C')], hasMore: true),
             20: page([song('f', 'C'), song('f', 'D'), song('f', 'E')], hasMore: true),
             40: page([song('f', 'F')])});
      await typeAndSearch('beat');
      await notifier().loadMore();
      await notifier().loadMore();
      expect(search.calls.map((c) => c.offset), [0, 20, 40]);
      expect(results().nextOffset, 60);
      expect(ids(), ['f:A', 'f:B', 'f:C', 'f:D', 'f:E', 'f:F']);
    });

    test('menos de 20 visibles no provoca volver a pedir la página', () async {
      serve({0: page([song('f', 'A'), song('f', 'A'), song('f', 'A')], hasMore: false)});
      await typeAndSearch('beat');
      expect(ids(), ['f:A']);
      await notifier().loadMore();
      expect(search.calls, hasLength(1));
    });

    test('página posterior completamente repetida: 0 nuevos, sigue la paginación',
        () async {
      serve({0: page([song('f', 'A'), song('f', 'B')], hasMore: true),
             20: page([song('f', 'A'), song('f', 'B')], hasMore: true),
             40: page([song('f', 'C')])});
      await typeAndSearch('beat');
      await notifier().loadMore();

      var r = results();
      expect(ids(), ['f:A', 'f:B']);
      expect(r.hasMore, isTrue, reason: 'la página no estaba vacía');
      expect(r.nextOffset, 40);
      expect(r.loadMore, LoadMoreStatus.idle);
      expect(container.read(catalogSearchProvider), isNot(isA<SearchEmpty>()));

      await notifier().loadMore();
      expect(search.calls.map((c) => c.offset), [0, 20, 40]);
      expect(ids(), ['f:A', 'f:B', 'f:C']);
      r = results();
      expect(r.hasMore, isFalse);
    });

    test('página completamente repetida con hasMore=false: fin de lista',
        () async {
      serve({0: page([song('f', 'A')], hasMore: true),
             20: page([song('f', 'A')], hasMore: false)});
      await typeAndSearch('beat');
      await notifier().loadMore();
      expect(results().hasMore, isFalse);
      await notifier().loadMore();
      expect(search.calls, hasLength(2));
    });

    test('página posterior vacía sigue siendo fin de lista', () async {
      serve({0: page([song('f', 'A')], hasMore: true),
             20: page([], hasMore: true)});
      await typeAndSearch('beat');
      await notifier().loadMore();
      expect(ids(), ['f:A']);
      expect(results().hasMore, isFalse);
      expect(container.read(catalogSearchProvider), isA<SearchResults>());
    });

    test('sin bucles: cada loadMore hace exactamente una llamada', () async {
      serve({0: page([song('f', 'A')], hasMore: true),
             20: page([song('f', 'A')], hasMore: true),
             40: page([song('f', 'A')], hasMore: true)});
      await typeAndSearch('beat');
      await notifier().loadMore();
      await notifier().loadMore();
      await pumpEventQueue();
      clock.advance(const Duration(minutes: 5));
      await pumpEventQueue();
      expect(search.calls, hasLength(3));
    });

    test('primera página toda repetida (A A A) no es Empty', () async {
      serve({0: page([song('f', 'A'), song('f', 'A'), song('f', 'A')], hasMore: true)});
      await typeAndSearch('beat');
      expect(container.read(catalogSearchProvider), isA<SearchResults>());
      expect(ids(), ['f:A']);
      expect(results().hasMore, isTrue);
      expect(results().nextOffset, 20);
    });

    test('la primera página vacía sigue siendo Empty', () async {
      serve({0: page([], hasMore: true)});
      await typeAndSearch('beat');
      expect(container.read(catalogSearchProvider), const SearchEmpty('beat'));
    });

    test('una búsqueda nueva empieza sin memoria de identidades anteriores',
        () async {
      search = FakeCatalogSearch((q) async =>
          q.text == 'uno' ? page([song('f', 'A')]) : page([song('f', 'A'), song('f', 'B')]));
      container = catalogContainer(search: search, scheduler: clock);
      addTearDown(container.dispose);
      await typeAndSearch('uno');
      expect(ids(), ['f:A']);
      await typeAndSearch('dos');
      expect(ids(), ['f:A', 'f:B']);
    });

    test('un fallo de loadMore no altera lo deduplicado', () async {
      var fail = false;
      search = FakeCatalogSearch((q) async {
        if (q.offset == 0) {
          return page([song('f', 'A'), song('f', 'A')], hasMore: true);
        }
        if (fail) throw const CatalogSearchFailure('x');
        return page([song('f', 'A'), song('f', 'B')]);
      });
      container = catalogContainer(search: search, scheduler: clock);
      addTearDown(container.dispose);
      await typeAndSearch('beat');
      fail = true;
      await notifier().loadMore();
      expect(ids(), ['f:A']);
      expect(results().loadMore, LoadMoreStatus.failed);
      fail = false;
      await notifier().loadMore();
      expect(ids(), ['f:A', 'f:B']);
    });
  });
}
