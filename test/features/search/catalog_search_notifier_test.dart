import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/entities/catalog_provider_info.dart';
import 'package:taki/core/domain/entities/catalog_search.dart';
import 'package:taki/core/domain/services/source_catalog_sources.dart';
import 'package:taki/features/search/domain/entities/catalog_search_policy.dart';
import 'package:taki/features/search/domain/entities/catalog_search_state.dart';
import 'package:taki/features/search/presentation/providers/catalog_search_providers.dart';

import '../../helpers/catalog_fakes.dart';

const _debounce = Duration(milliseconds: 400);

void main() {
  late FakeCatalogSearch search;
  late ManualSearchScheduler clock;
  late ProviderContainer container;

  CatalogSearchNotifier notifier() =>
      container.read(catalogSearchProvider.notifier);
  CatalogSearchState state() => container.read(catalogSearchProvider);

  /// Deja terminar las respuestas ya resueltas.
  Future<void> settle() => pumpEventQueue();

  /// Teclea [text], espera el debounce y deja terminar la búsqueda.
  Future<void> typeAndSearch(String text) async {
    notifier().setQuery(text);
    clock.advance(_debounce);
    await settle();
  }

  setUp(() {
    search = FakeCatalogSearch((_) async => fakePage(3));
    clock = ManualSearchScheduler();
    container = catalogContainer(search: search, scheduler: clock);
    addTearDown(container.dispose);
  });

  group('política (decisiones D2–D4)', () {
    test('rechaza valores inválidos', () {
      expect(() => CatalogSearchPolicy(minimumQueryLength: 0),
          throwsAssertionError);
      expect(() => CatalogSearchPolicy(pageSize: 0), throwsAssertionError);
      expect(const CatalogSearchPolicy(minimumQueryLength: 1, pageSize: 1),
          isNotNull);
    });

    test('reconstruir el controlador olvida lo asentado', () async {
      await typeAndSearch('beat');
      container.invalidate(catalogSearchProvider);
      expect(state(), const SearchIdle());
      notifier().setQuery('beat');
      expect((state() as SearchTyping).previous, isNull);
    });

    test('valores por defecto', () {
      const policy = CatalogSearchPolicy();
      expect(policy.minimumQueryLength, 2);
      expect(policy.debounce, const Duration(milliseconds: 400));
      expect(policy.pageSize, 20);
    });
  });

  group('estados iniciales', () {
    test('con catálogo: Idle', () {
      expect(state(), const SearchIdle());
      expect(search.calls, isEmpty);
    });

    test('sin catálogo: Unavailable (no es Empty ni Failed)', () {
      container = catalogContainer(scheduler: clock);
      addTearDown(container.dispose);
      expect(state(), const SearchUnavailable());
      expect(state(), isNot(isA<SearchEmpty>()));
      expect(state(), isNot(isA<SearchFailed>()));
    });

    test('Unavailable ignora setQuery, submit, retry y loadMore', () async {
      container = catalogContainer(scheduler: clock);
      addTearDown(container.dispose);
      notifier().setQuery('beat');
      notifier().submit('beat');
      notifier().retry();
      await notifier().loadMore();
      clock.advance(const Duration(seconds: 5));
      await settle();
      expect(state(), const SearchUnavailable());
      expect(clock.pending, 0);
    });

    test('con varias fuentes usa la primera registrada', () async {
      final first = FakeCatalogSearch((_) async => fakePage(1));
      final second = FakeCatalogSearch((_) async => fakePage(2));
      container = catalogContainer(scheduler: clock, registrations: [
        CatalogSourceRegistration(
            CatalogProviderInfo(source: 'a', label: 'A'), first),
        CatalogSourceRegistration(
            CatalogProviderInfo(source: 'b', label: 'B'), second),
      ]);
      addTearDown(container.dispose);
      await typeAndSearch('beat');
      expect(first.calls, hasLength(1));
      expect(second.calls, isEmpty);
    });
  });

  group('longitud mínima', () {
    for (final text in ['', 'a', ' ', '  a  ', 'ñ', '😀']) {
      test('«$text» no busca ni cambia de Idle', () async {
        await typeAndSearch(text);
        expect(state(), const SearchIdle());
        expect(search.calls, isEmpty);
        expect(clock.pending, 0);
      });
    }

    for (final text in ['ab', ' ab ', '😀😀', 'beat']) {
      test('«$text» pasa a Typing y busca tras el debounce', () async {
        notifier().setQuery(text);
        expect(state(), SearchTyping(text));
        clock.advance(_debounce);
        await settle();
        expect(search.calls.single.text, text);
      });
    }

    test('submit con consulta corta no busca y queda Idle', () async {
      notifier().submit('a');
      await settle();
      expect(state(), const SearchIdle());
      expect(search.calls, isEmpty);
    });

    test('el texto se envía tal cual, sin recortar ni normalizar', () async {
      await typeAndSearch('  Árbol  ');
      expect(search.calls.single.text, '  Árbol  ');
      expect((state() as SearchResults).query, '  Árbol  ');
    });

    test('bajar del mínimo descarta resultados y vuelve a Idle', () async {
      await typeAndSearch('beat');
      expect(state(), isA<SearchResults>());
      notifier().setQuery('b');
      expect(state(), const SearchIdle());
      // Y al volver a escribir, no restaura los resultados viejos.
      notifier().setQuery('beat');
      expect(state(), isA<SearchTyping>());
      expect((state() as SearchTyping).previous, isNull);
    });

    test('borrar el texto cancela el debounce pendiente', () async {
      notifier().setQuery('beat');
      notifier().setQuery('');
      expect(state(), const SearchIdle());
      clock.advance(const Duration(seconds: 2));
      await settle();
      expect(search.calls, isEmpty);
    });

    test('mínimo configurable', () async {
      container = catalogContainer(
        search: search,
        scheduler: clock,
        policy: const CatalogSearchPolicy(minimumQueryLength: 4),
      );
      addTearDown(container.dispose);
      await typeAndSearch('abc');
      expect(state(), const SearchIdle());
      await typeAndSearch('abcd');
      expect(search.calls, hasLength(1));
    });
  });

  group('debounce de 400 ms', () {
    test('«a» → «ab» → 400 ms: una sola búsqueda', () async {
      notifier().setQuery('a');
      notifier().setQuery('ab');
      clock.advance(_debounce);
      await settle();
      expect(search.calls, hasLength(1));
      expect(search.calls.single.text, 'ab');
    });

    test('a 399 ms todavía no busca; a 400 ms sí', () async {
      notifier().setQuery('ab');
      clock.advance(const Duration(milliseconds: 399));
      await settle();
      expect(search.calls, isEmpty);
      expect(state(), isA<SearchTyping>());
      clock.advance(const Duration(milliseconds: 1));
      expect(state(), const SearchLoading('ab'));
      await settle();
      expect(search.calls, hasLength(1));
    });

    test('teclear reinicia la espera', () async {
      notifier().setQuery('ab');
      clock.advance(const Duration(milliseconds: 300));
      notifier().setQuery('abc');
      clock.advance(const Duration(milliseconds: 300));
      await settle();
      expect(search.calls, isEmpty);
      clock.advance(const Duration(milliseconds: 100));
      await settle();
      expect(search.calls.map((c) => c.text), ['abc']);
    });

    test('no duplica la búsqueda al pasar el tiempo', () async {
      await typeAndSearch('ab');
      clock.advance(const Duration(seconds: 10));
      await settle();
      expect(search.calls, hasLength(1));
    });

    test('repetir el mismo texto no reinicia la espera', () async {
      notifier().setQuery('ab');
      clock.advance(const Duration(milliseconds: 300));
      notifier().setQuery('ab');
      clock.advance(const Duration(milliseconds: 100));
      await settle();
      expect(search.calls, hasLength(1));
    });

    test('Typing conserva el estado asentado anterior', () async {
      await typeAndSearch('beat');
      final results = state();
      notifier().setQuery('beats');
      expect(state(), SearchTyping('beats', previous: results));
    });

    test('desde Idle, previous es null', () {
      notifier().setQuery('beat');
      expect((state() as SearchTyping).previous, isNull);
    });

    test('Typing conserva un Empty y un Failed previos', () async {
      search.handler = (_) async => fakePage(0);
      await typeAndSearch('zz');
      expect((state()), const SearchEmpty('zz'));
      notifier().setQuery('zzz');
      expect((state() as SearchTyping).previous, const SearchEmpty('zz'));

      search.handler = (_) async => throw const CatalogSearchFailure('x');
      await typeAndSearch('zzzz');
      expect(state(), isA<SearchFailed>());
      notifier().setQuery('zzzzz');
      expect((state() as SearchTyping).previous, isA<SearchFailed>());
    });

    test('debounce configurable', () async {
      container = catalogContainer(
        search: search,
        scheduler: clock,
        policy: const CatalogSearchPolicy(debounce: Duration(milliseconds: 100)),
      );
      addTearDown(container.dispose);
      notifier().setQuery('ab');
      clock.advance(const Duration(milliseconds: 100));
      await settle();
      expect(search.calls, hasLength(1));
    });

    test('volver a la consulta asentada no vuelve a buscar', () async {
      await typeAndSearch('ab');
      final results = state();
      notifier().setQuery('abc');
      notifier().setQuery('ab');
      expect(state(), same(results));
      clock.advance(const Duration(seconds: 2));
      await settle();
      expect(search.calls, hasLength(1));
      expect(state(), same(results));
    });

    test('volver a una consulta vacía asentada tampoco busca', () async {
      search.handler = (_) async => fakePage(0);
      await typeAndSearch('zz');
      notifier().setQuery('zzz');
      notifier().setQuery('zz');
      expect(state(), const SearchEmpty('zz'));
      clock.advance(const Duration(seconds: 2));
      await settle();
      expect(search.calls, hasLength(1));
    });

    test('repetir el texto de Results/Empty no hace nada', () async {
      await typeAndSearch('ab');
      final results = state();
      notifier().setQuery('ab');
      expect(state(), same(results));
      expect(clock.pending, 0);

      search.handler = (_) async => fakePage(0);
      await typeAndSearch('zz');
      notifier().setQuery('zz');
      expect(state(), const SearchEmpty('zz'));
      expect(clock.pending, 0);
    });

    test('repetir el texto durante Loading no reinicia la búsqueda', () async {
      final pending = Completer<CatalogSearchPage>();
      search.handler = (_) => pending.future;
      notifier().setQuery('ab');
      clock.advance(_debounce);
      notifier().setQuery('ab');
      expect(state(), const SearchLoading('ab'));
      pending.complete(fakePage(1));
      await settle();
      expect(state(), isA<SearchResults>());
      expect(search.calls, hasLength(1));
    });

    test('un Failed con el mismo texto no se restaura: se vuelve a buscar',
        () async {
      search.handler = (_) async => throw const CatalogSearchFailure('x');
      await typeAndSearch('ab');
      final failed = state();
      notifier().setQuery('abc');
      notifier().setQuery('ab');
      expect(state(), SearchTyping('ab', previous: failed));
      search.handler = (_) async => fakePage(1);
      clock.advance(_debounce);
      await settle();
      expect(state(), isA<SearchResults>());
      expect(search.calls, hasLength(2));
    });
  });

  group('submit', () {
    test('salta el debounce y cancela la espera pendiente', () async {
      notifier().setQuery('ab');
      notifier().submit('ab');
      expect(state(), const SearchLoading('ab'));
      expect(clock.pending, 0);
      await settle();
      clock.advance(const Duration(seconds: 2));
      await settle();
      expect(search.calls, hasLength(1));
      expect(state(), isA<SearchResults>());
    });

    test('no repite una consulta con resultados', () async {
      await typeAndSearch('ab');
      final results = state();
      notifier().submit('ab');
      await settle();
      expect(search.calls, hasLength(1));
      expect(state(), same(results));
    });

    test('no repite una consulta en curso', () async {
      final pending = Completer<CatalogSearchPage>();
      search.handler = (_) => pending.future;
      notifier().submit('ab');
      notifier().submit('ab');
      expect(search.calls, hasLength(1));
      pending.complete(fakePage(1));
      await settle();
    });

    test('relanza una consulta vacía', () async {
      search.handler = (_) async => fakePage(0);
      await typeAndSearch('zz');
      expect(state(), const SearchEmpty('zz'));
      notifier().submit('zz');
      expect(state(), const SearchLoading('zz'));
      await settle();
      expect(search.calls, hasLength(2));
    });

    test('relanza una consulta fallida', () async {
      search.handler = (_) async => throw const CatalogSearchFailure('x');
      await typeAndSearch('ab');
      notifier().submit('ab');
      await settle();
      expect(search.calls, hasLength(2));
    });

    test('con otro texto busca el nuevo', () async {
      await typeAndSearch('ab');
      notifier().submit('abc');
      await settle();
      expect(search.calls.map((c) => c.text), ['ab', 'abc']);
      expect((state() as SearchResults).query, 'abc');
    });
  });

  group('Loading / Results / Empty / Failed', () {
    test('Loading mientras la primera página está en curso', () async {
      final pending = Completer<CatalogSearchPage>();
      search.handler = (_) => pending.future;
      notifier().setQuery('ab');
      clock.advance(_debounce);
      expect(state(), const SearchLoading('ab'));
      pending.complete(fakePage(2));
      await settle();
      expect(state(), isA<SearchResults>());
    });

    test('Results guarda query, items, hasMore y paginación', () async {
      search.handler = (_) async => fakePage(20, hasMore: true);
      await typeAndSearch('beat');
      final results = state() as SearchResults;
      expect(results.query, 'beat');
      expect(results.items, hasLength(20));
      expect(results.hasMore, isTrue);
      expect(results.nextOffset, 20);
      expect(results.loadMore, LoadMoreStatus.idle);
      expect(results.items.first.song.musicIdentity, fakeIdentity(1));
    });

    test('Results sin más páginas', () async {
      search.handler = (_) async => fakePage(5);
      await typeAndSearch('beat');
      expect((state() as SearchResults).hasMore, isFalse);
    });

    test('Empty: búsqueda válida sin resultados (no es Failed)', () async {
      search.handler = (_) async => fakePage(0);
      await typeAndSearch('zzzz');
      expect(state(), const SearchEmpty('zzzz'));
      expect(state(), isNot(isA<SearchFailed>()));
      expect(state(), isNot(isA<SearchUnavailable>()));
    });

    test('primera página vacía con hasMore=true sigue siendo Empty', () async {
      search.handler = (_) async => fakePage(0, hasMore: true);
      await typeAndSearch('zzzz');
      expect(state(), const SearchEmpty('zzzz'));
    });

    test('Failed: fallo del catálogo, con la consulta y el fallo', () async {
      const failure = CatalogSearchFailure('red', source: 'fake');
      search.handler = (_) async => throw failure;
      await typeAndSearch('beat');
      expect(state(), const SearchFailed('beat', failure));
      expect(state(), isNot(isA<SearchEmpty>()));
    });

    test('un error inesperado también es Failed, sin detalle técnico',
        () async {
      search.handler = (_) async => throw StateError('boom');
      await typeAndSearch('beat');
      final failed = state() as SearchFailed;
      expect(failed.failure.cause, StateError);
      expect(failed.failure.message, isNot(contains('boom')));
    });

    test('un fallo es exactamente una llamada lógica (sin reintentos)',
        () async {
      search.handler = (_) async => throw const CatalogSearchFailure('x');
      await typeAndSearch('beat');
      clock.advance(const Duration(minutes: 5));
      await settle();
      expect(search.calls, hasLength(1));
      expect(clock.pending, 0);
    });

    test('retry relanza la misma consulta fallida, una vez', () async {
      search.handler = (_) async => throw const CatalogSearchFailure('x');
      await typeAndSearch('beat');
      search.handler = (_) async => fakePage(2);
      notifier().retry();
      expect(state(), const SearchLoading('beat'));
      await settle();
      expect(search.calls.map((c) => c.text), ['beat', 'beat']);
      expect(state(), isA<SearchResults>());
    });

    test('retry fuera de Failed no hace nada', () async {
      notifier().retry();
      await typeAndSearch('beat');
      notifier().retry();
      await settle();
      expect(search.calls, hasLength(1));
      expect(state(), isA<SearchResults>());
    });

    test('la petición usa limit 20 y offset 0', () async {
      await typeAndSearch('beat');
      expect(search.calls.single.limit, 20);
      expect(search.calls.single.offset, 0);
    });

    test('page size configurable', () async {
      container = catalogContainer(
        search: search,
        scheduler: clock,
        policy: const CatalogSearchPolicy(pageSize: 5),
      );
      addTearDown(container.dispose);
      search.handler = (_) async => fakePage(5, hasMore: true);
      await typeAndSearch('beat');
      expect(search.calls.single.limit, 5);
      expect((state() as SearchResults).nextOffset, 5);
    });
  });

  group('generación / respuestas obsoletas', () {
    late Map<String, Completer<CatalogSearchPage>> pending;

    setUp(() {
      pending = {};
      search.handler =
          (q) => (pending[q.text!] = Completer<CatalogSearchPage>()).future;
    });

    test('«be» responde después de «beat»: no sobrescribe', () async {
      notifier().submit('be');
      notifier().submit('beat');
      pending['beat']!.complete(fakePage(2, from: 100));
      await settle();
      pending['be']!.complete(fakePage(5, from: 1));
      await settle();
      final results = state() as SearchResults;
      expect(results.query, 'beat');
      expect(results.items.map((i) => i.song.musicIdentity),
          [fakeIdentity(100), fakeIdentity(101)]);
    });

    test('«be» responde antes de «beat»: sigue Loading hasta «beat»', () async {
      notifier().submit('be');
      notifier().submit('beat');
      pending['be']!.complete(fakePage(5));
      await settle();
      expect(state(), const SearchLoading('beat'));
      pending['beat']!.complete(fakePage(2, from: 100));
      await settle();
      expect((state() as SearchResults).query, 'beat');
    });

    test('un fallo obsoleto no pisa el resultado vigente', () async {
      notifier().submit('be');
      notifier().submit('beat');
      pending['beat']!.complete(fakePage(1));
      await settle();
      pending['be']!.completeError(const CatalogSearchFailure('x'));
      await settle();
      expect(state(), isA<SearchResults>());
    });

    test('un vacío obsoleto no pisa el resultado vigente', () async {
      notifier().submit('be');
      notifier().submit('beat');
      pending['beat']!.complete(fakePage(1));
      await settle();
      pending['be']!.complete(fakePage(0));
      await settle();
      expect(state(), isA<SearchResults>());
    });

    test('un fallo obsoleto no pisa un Loading vigente', () async {
      notifier().submit('be');
      notifier().submit('beat');
      pending['be']!.completeError(const CatalogSearchFailure('x'));
      await settle();
      expect(state(), const SearchLoading('beat'));
      pending['beat']!.complete(fakePage(1));
      await settle();
    });

    test('borrar la consulta en vuelo descarta la respuesta', () async {
      notifier().submit('beat');
      notifier().setQuery('');
      pending['beat']!.complete(fakePage(3));
      await settle();
      expect(state(), const SearchIdle());
    });

    test('teclear en vuelo descarta la respuesta (queda Typing)', () async {
      notifier().submit('beat');
      notifier().setQuery('beats');
      pending['beat']!.complete(fakePage(3));
      await settle();
      expect(state(), const SearchTyping('beats'));
    });

    test('reconstruir el controlador invalida lo que estaba en vuelo', () async {
      notifier().submit('beat');
      container.invalidate(catalogSearchProvider);
      expect(state(), const SearchIdle());
      pending['beat']!.complete(fakePage(3));
      await settle();
      expect(state(), const SearchIdle());
    });

    test('desechar el contenedor en vuelo no falla', () async {
      notifier().submit('beat');
      container.dispose();
      pending['beat']!.complete(fakePage(3));
      await settle();
    });

    test('desechar el contenedor cancela el debounce', () async {
      notifier().setQuery('beat');
      container.dispose();
      clock.advance(_debounce);
      await settle();
      expect(search.calls, isEmpty);
    });
  });

  group('paginación', () {
    test('20 resultados → hasMore; loadMore pide offset 20', () async {
      search.handler = (q) async =>
          q.offset == 0 ? fakePage(20, hasMore: true) : fakePage(20, from: 21);
      await typeAndSearch('beat');
      await notifier().loadMore();
      expect(search.calls.map((c) => (c.offset, c.limit)),
          [(0, 20), (20, 20)]);
      final results = state() as SearchResults;
      expect(results.items, hasLength(40));
      expect(results.items.last.song.musicIdentity, fakeIdentity(40));
      expect(results.nextOffset, 40);
      expect(results.hasMore, isFalse);
      expect(results.loadMore, LoadMoreStatus.idle);
    });

    test('la segunda página conserva el query', () async {
      search.handler = (q) async => fakePage(1, hasMore: q.offset == 0);
      await typeAndSearch('Beat ');
      await notifier().loadMore();
      expect(search.calls.last.text, 'Beat ');
    });

    test('mientras carga, el estado es Results(loading) con los items',
        () async {
      search.handler = (q) async => fakePage(2, hasMore: true);
      await typeAndSearch('beat');
      final pending = Completer<CatalogSearchPage>();
      search.handler = (_) => pending.future;
      final future = notifier().loadMore();
      final loading = state() as SearchResults;
      expect(loading.loadMore, LoadMoreStatus.loading);
      expect(loading.items, hasLength(2));
      pending.complete(fakePage(1, from: 3));
      await future;
      expect((state() as SearchResults).items, hasLength(3));
    });

    test('un loadMore en curso ignora otro', () async {
      search.handler = (q) async => fakePage(2, hasMore: true);
      await typeAndSearch('beat');
      final pending = Completer<CatalogSearchPage>();
      search.handler = (_) => pending.future;
      final first = notifier().loadMore();
      await notifier().loadMore();
      expect(search.calls, hasLength(2));
      pending.complete(fakePage(1, from: 3));
      await first;
    });

    test('con hasMore=false no pide nada', () async {
      search.handler = (_) async => fakePage(2);
      await typeAndSearch('beat');
      await notifier().loadMore();
      expect(search.calls, hasLength(1));
    });

    test('segunda página vacía = fin de lista, no Empty', () async {
      search.handler =
          (q) async => q.offset == 0 ? fakePage(20, hasMore: true) : fakePage(0, hasMore: true);
      await typeAndSearch('beat');
      await notifier().loadMore();
      final results = state() as SearchResults;
      expect(results.items, hasLength(20));
      expect(results.hasMore, isFalse);
      expect(results.loadMore, LoadMoreStatus.idle);
      await notifier().loadMore();
      expect(search.calls, hasLength(2));
    });

    test('hasMore de la página nueva manda si trae canciones', () async {
      search.handler = (q) async =>
          fakePage(20, from: q.offset + 1, hasMore: q.offset < 40);
      await typeAndSearch('beat');
      await notifier().loadMore();
      expect((state() as SearchResults).hasMore, isTrue);
      await notifier().loadMore();
      expect((state() as SearchResults).hasMore, isFalse);
      expect((state() as SearchResults).items, hasLength(60));
    });

    test('offset avanza por limit aunque la fuente descarte canciones',
        () async {
      search.handler = (q) async => fakePage(17, from: q.offset + 1, hasMore: true);
      await typeAndSearch('beat');
      await notifier().loadMore();
      expect(search.calls.last.offset, 20);
      expect((state() as SearchResults).nextOffset, 40);
    });

    test('loadMore fuera de Results no hace nada', () async {
      Future<void> expectNoNewCall(String reason) async {
        final before = search.calls.length;
        await notifier().loadMore();
        expect(search.calls.length, before, reason: reason);
      }

      await expectNoNewCall('Idle');
      notifier().setQuery('beat');
      await expectNoNewCall('Typing');
      final pending = Completer<CatalogSearchPage>();
      search.handler = (_) => pending.future;
      clock.advance(_debounce);
      expect(state(), isA<SearchLoading>());
      await expectNoNewCall('Loading');
      pending.complete(fakePage(0, hasMore: true));
      await settle();
      expect(state(), isA<SearchEmpty>());
      await expectNoNewCall('Empty');
      search.handler = (_) async => throw const CatalogSearchFailure('x');
      await typeAndSearch('beatz');
      expect(state(), isA<SearchFailed>());
      await expectNoNewCall('Failed');
    });

    test('teclear durante loadMore descarta la página', () async {
      search.handler = (q) async => fakePage(2, hasMore: true);
      await typeAndSearch('beat');
      final pending = Completer<CatalogSearchPage>();
      search.handler = (_) => pending.future;
      final future = notifier().loadMore();
      notifier().setQuery('beats');
      pending.complete(fakePage(5, from: 10));
      await future;
      expect(state(), isA<SearchTyping>());
      // Y al volver a la consulta asentada, el loadMore está en reposo.
      notifier().setQuery('beat');
      expect((state() as SearchResults).loadMore, LoadMoreStatus.idle);
      expect((state() as SearchResults).items, hasLength(2));
    });

    test('repetir el texto durante loadMore no lo cancela', () async {
      search.handler = (q) async => fakePage(2, hasMore: true);
      await typeAndSearch('beat');
      final pending = Completer<CatalogSearchPage>();
      search.handler = (_) => pending.future;
      final future = notifier().loadMore();
      notifier().setQuery('beat');
      pending.complete(fakePage(1, from: 3));
      await future;
      expect((state() as SearchResults).items, hasLength(3));
    });

    test('un fallo de loadMore tras teclear se descarta', () async {
      search.handler = (q) async => fakePage(2, hasMore: true);
      await typeAndSearch('beat');
      final pending = Completer<CatalogSearchPage>();
      search.handler = (_) => pending.future;
      final future = notifier().loadMore();
      notifier().setQuery('beats');
      pending.completeError(const CatalogSearchFailure('x'));
      await future;
      expect(state(), isA<SearchTyping>());
    });
  });

  group('fallo de loadMore', () {
    late SearchResults before;

    setUp(() async {
      search.handler = (q) async => fakePage(20, hasMore: true);
      await typeAndSearch('beat');
      before = state() as SearchResults;
      search.handler = (_) async => throw const CatalogSearchFailure('x');
    });

    test('conserva los resultados y expone loadMoreFailed', () async {
      await notifier().loadMore();
      final results = state() as SearchResults;
      expect(state(), isNot(isA<SearchFailed>()));
      expect(results.loadMore, LoadMoreStatus.failed);
      expect(results.items, before.items);
      expect(results.hasMore, isTrue);
      expect(results.nextOffset, before.nextOffset);
      expect(results.query, 'beat');
    });

    test('no reintenta solo', () async {
      await notifier().loadMore();
      clock.advance(const Duration(minutes: 5));
      await settle();
      expect(search.calls, hasLength(2));
      expect(clock.pending, 0);
    });

    test('loadMore de nuevo reintenta la misma página', () async {
      await notifier().loadMore();
      search.handler = (_) async => fakePage(20, from: 21);
      await notifier().loadMore();
      expect(search.calls.map((c) => c.offset), [0, 20, 20]);
      final results = state() as SearchResults;
      expect(results.items, hasLength(40));
      expect(results.loadMore, LoadMoreStatus.idle);
    });

    test('un error inesperado también conserva la lista', () async {
      search.handler = (_) async => throw StateError('boom');
      await notifier().loadMore();
      final results = state() as SearchResults;
      expect(results.loadMore, LoadMoreStatus.failed);
      expect(results.items, hasLength(20));
    });

    test('tras el fallo, teclear y volver a la consulta restaura el fallo',
        () async {
      await notifier().loadMore();
      notifier().setQuery('beats');
      notifier().setQuery('beat');
      expect((state() as SearchResults).loadMore, LoadMoreStatus.failed);
    });
  });

  group('atribución', () {
    test('resultado con atribución', () async {
      search.handler = (_) async => fakePage(2, withAttribution: true);
      await typeAndSearch('beat');
      final items = (state() as SearchResults).items;
      expect(items[0].attribution, fakeAttribution(1));
      expect(items[1].attribution, fakeAttribution(2));
      expect(items[0].song, fakeSong(1));
    });

    test('resultado sin atribución', () async {
      search.handler = (_) async => fakePage(2);
      await typeAndSearch('beat');
      expect((state() as SearchResults).items.map((i) => i.attribution),
          [null, null]);
    });

    test('atribución parcial: solo quien la trae', () async {
      search.handler = (_) async => fakePage(3, attributedOnly: {2});
      await typeAndSearch('beat');
      expect((state() as SearchResults).items.map((i) => i.attribution),
          [null, fakeAttribution(2), null]);
    });

    test('no se pierde al paginar', () async {
      search.handler = (q) async => q.offset == 0
          ? fakePage(2, hasMore: true, withAttribution: true)
          : fakePage(2, from: 3, attributedOnly: {4});
      await typeAndSearch('beat');
      await notifier().loadMore();
      final items = (state() as SearchResults).items;
      expect(items.map((i) => i.attribution), [
        fakeAttribution(1),
        fakeAttribution(2),
        null,
        fakeAttribution(4),
      ]);
    });

    test('se conserva al restaurar la consulta asentada', () async {
      search.handler = (_) async => fakePage(1, withAttribution: true);
      await typeAndSearch('beat');
      notifier().setQuery('beats');
      notifier().setQuery('beat');
      expect((state() as SearchResults).items.single.attribution,
          fakeAttribution(1));
    });

    test('la identidad viaja en cada resultado', () async {
      search.handler = (_) async => fakePage(2);
      await typeAndSearch('beat');
      expect(
        (state() as SearchResults).items.map((i) => i.song.musicIdentity),
        [fakeIdentity(1), fakeIdentity(2)],
      );
    });
  });
}
