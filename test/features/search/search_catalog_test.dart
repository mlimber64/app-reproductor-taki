import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/entities/catalog_search.dart';
import 'package:taki/features/search/domain/entities/catalog_result_item.dart';
import 'package:taki/features/search/domain/entities/catalog_search_state.dart';
import 'package:taki/features/search/domain/usecases/search_catalog.dart';
import 'package:taki/features/search/infrastructure/timer_search_scheduler.dart';

import '../../helpers/catalog_fakes.dart';

void main() {
  group('SearchCatalog', () {
    test('page size por defecto: 20', () {
      expect(SearchCatalog(FakeCatalogSearch()).pageSize, 20);
    });

    test('envía texto tal cual, limit y offset', () async {
      final search = FakeCatalogSearch((_) async => fakePage(0));
      await SearchCatalog(search, pageSize: 7)('  Árbol ', offset: 14);
      final query = search.calls.single;
      expect(query.text, '  Árbol ');
      expect(query.limit, 7);
      expect(query.offset, 14);
      expect(query.artist, isNull);
      expect(query.tag, isNull);
    });

    test('offset por defecto 0 y limit 20', () async {
      final search = FakeCatalogSearch((_) async => fakePage(0));
      await SearchCatalog(search)('beat');
      expect(search.calls.single.offset, 0);
      expect(search.calls.single.limit, 20);
    });

    test('traduce canciones a items con su atribución', () async {
      final search = FakeCatalogSearch(
          (_) async => fakePage(3, hasMore: true, attributedOnly: {1, 3}));
      final page = await SearchCatalog(search)('beat');
      expect(page.hasMore, isTrue);
      expect(page.items, [
        CatalogResultItem(fakeSong(1), attribution: fakeAttribution(1)),
        CatalogResultItem(fakeSong(2)),
        CatalogResultItem(fakeSong(3), attribution: fakeAttribution(3)),
      ]);
    });

    test('página vacía', () async {
      final page = await SearchCatalog(FakeCatalogSearch())('beat');
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test('un CatalogSearchFailure pasa tal cual', () async {
      const failure = CatalogSearchFailure('red', source: 'fake');
      final search = FakeCatalogSearch((_) async => throw failure);
      await expectLater(
        SearchCatalog(search)('beat'),
        throwsA(same(failure)),
      );
    });

    test('un error inesperado se traduce sin detalles', () async {
      final search = FakeCatalogSearch((_) async => throw StateError('boom'));
      await expectLater(
        SearchCatalog(search)('beat'),
        throwsA(isA<CatalogSearchFailure>()
            .having((e) => e.cause, 'cause', StateError)
            .having((e) => e.message, 'message', isNot(contains('boom')))),
      );
    });

    test('una llamada = una petición (sin reintentos)', () async {
      final search =
          FakeCatalogSearch((_) async => throw const CatalogSearchFailure('x'));
      await expectLater(
        SearchCatalog(search)('beat'),
        throwsA(isA<CatalogSearchFailure>()),
      );
      expect(search.calls, hasLength(1));
    });

    test('un texto en blanco es un error de programación, no un fallo', () {
      final search = FakeCatalogSearch();
      expect(SearchCatalog(search)('  '), throwsArgumentError);
      expect(search.calls, isEmpty);
    });
  });

  group('CatalogSearchPage', () {
    test('sin atribuciones por defecto', () {
      const page = CatalogSearchPage([], hasMore: false);
      expect(page.attributions, isEmpty);
    });

    test('attributionOf busca por identidad', () {
      final page = fakePage(2, attributedOnly: {2});
      expect(page.attributionOf(fakeSong(2)), fakeAttribution(2));
      expect(page.attributionOf(fakeSong(1)), isNull);
      expect(page.attributionOf(fakeSong(99)), isNull);
    });
  });

  group('estado', () {
    test('igualdad por valor', () {
      expect(const SearchIdle(), const SearchIdle());
      expect(const SearchUnavailable(), const SearchUnavailable());
      expect(const SearchLoading('a'), const SearchLoading('a'));
      expect(const SearchLoading('a'), isNot(const SearchLoading('b')));
      expect(const SearchEmpty('a'), const SearchEmpty('a'));
      expect(const SearchEmpty('a'), isNot(const SearchEmpty('b')));
      expect(const SearchTyping('a'), const SearchTyping('a'));
      expect(const SearchTyping('a'), isNot(const SearchTyping('b')));
      expect(const SearchTyping('a'),
          isNot(const SearchTyping('a', previous: SearchEmpty('x'))));
      const failure = CatalogSearchFailure('x');
      expect(const SearchFailed('a', failure), const SearchFailed('a', failure));
      expect(const SearchFailed('a', failure),
          isNot(const SearchFailed('b', failure)));
      expect(const SearchFailed('a', failure),
          isNot(const SearchFailed('a', CatalogSearchFailure('y'))));
    });

    test('estados distintos nunca son iguales', () {
      expect(const SearchIdle(), isNot(const SearchUnavailable()));
      expect(const SearchEmpty('a'), isNot(const SearchLoading('a')));
      expect(const SearchEmpty('a'),
          isNot(const SearchFailed('a', CatalogSearchFailure('x'))));
    });

    test('SearchResults: igualdad y withLoadMore', () {
      final base = SearchResults(
        query: 'a',
        items: [CatalogResultItem(fakeSong(1))],
        hasMore: true,
        nextOffset: 20,
      );
      expect(base.loadMore, LoadMoreStatus.idle);
      final failed = base.withLoadMore(LoadMoreStatus.failed);
      expect(failed.loadMore, LoadMoreStatus.failed);
      expect(failed.items, base.items);
      expect(failed.query, 'a');
      expect(failed.hasMore, isTrue);
      expect(failed.nextOffset, 20);
      expect(failed.withLoadMore(LoadMoreStatus.idle), base);
      expect(failed, isNot(base));
      for (final other in [
        SearchResults(query: 'b', items: base.items, hasMore: true, nextOffset: 20),
        SearchResults(query: 'a', items: const [], hasMore: true, nextOffset: 20),
        SearchResults(query: 'a', items: base.items, hasMore: false, nextOffset: 20),
        SearchResults(query: 'a', items: base.items, hasMore: true, nextOffset: 40),
      ]) {
        expect(other, isNot(base));
      }
    });

    test('CatalogResultItem: igualdad', () {
      expect(CatalogResultItem(fakeSong(1)), CatalogResultItem(fakeSong(1)));
      expect(CatalogResultItem(fakeSong(1)),
          isNot(CatalogResultItem(fakeSong(2))));
      expect(CatalogResultItem(fakeSong(1), attribution: fakeAttribution(1)),
          isNot(CatalogResultItem(fakeSong(1))));
    });
  });

  group('TimerSearchScheduler', () {
    test('ejecuta la acción tras la espera', () async {
      var ran = 0;
      const TimerSearchScheduler()
          .schedule(const Duration(milliseconds: 600), () => ran++);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(ran, 0, reason: 'respeta la espera');
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      expect(ran, 1);
    });

    test('cancelar evita la ejecución (y repetir cancelar no falla)', () async {
      var ran = 0;
      final cancel = const TimerSearchScheduler()
          .schedule(const Duration(milliseconds: 10), () => ran++);
      cancel();
      cancel();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(ran, 0);
    });
  });
}
