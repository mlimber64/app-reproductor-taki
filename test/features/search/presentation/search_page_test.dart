import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taki/app/theme/app_theme.dart';
import 'package:taki/core/artwork/artwork_providers.dart';
import 'package:taki/core/domain/entities/catalog_search.dart';
import 'package:taki/core/domain/entities/song.dart';
import 'package:taki/core/widgets/taki_button.dart';
import 'package:taki/core/widgets/taki_empty_state.dart';
import 'package:taki/core/widgets/taki_error_state.dart';
import 'package:taki/core/widgets/taki_search_field.dart';
import 'package:taki/core/widgets/taki_song_tile.dart';
import 'package:taki/features/player/domain/entities/playback_state.dart';
import 'package:taki/features/player/presentation/providers/player_providers.dart';
import 'package:taki/features/search/domain/entities/catalog_search_policy.dart';
import 'package:taki/features/search/domain/entities/catalog_search_state.dart';
import 'package:taki/features/search/presentation/pages/search_page.dart';
import 'package:taki/features/search/presentation/providers/catalog_search_providers.dart';
import 'package:taki/features/search/presentation/search_texts.dart';

import '../../../helpers/catalog_fakes.dart';
import '../../../helpers/library_fakes.dart';
import '../../../helpers/player_fakes.dart';

const _debounce = Duration(milliseconds: 400);

void main() {
  late FakeCatalogSearch search;
  late ManualSearchScheduler clock;
  late FakeAudioPlayerPort player;
  late FakeNotificationPermission notifications;
  late MockPlaySongs playSongs;
  late ProviderContainer container;

  /// Canciones para las que se abrió el menú de acciones.
  late List<Song> actionSongs;

  setUpAll(() => registerFallbackValue(<Song>[]));

  setUp(() {
    actionSongs = [];
    search = FakeCatalogSearch((_) async => fakePage(3));
    clock = ManualSearchScheduler();
    player = FakeAudioPlayerPort();
    notifications = FakeNotificationPermission();
    playSongs = MockPlaySongs();
    when(() => playSongs(any(), any())).thenAnswer((_) async {});
  });

  /// Monta la página con el catálogo [search] (o sin catálogo si
  /// [available] es `false`).
  Future<void> pumpPage(
    WidgetTester tester, {
    bool available = true,
    Widget Function(Widget page)? wrap,
    CatalogSearchPolicy? policy,
  }) async {
    container = catalogContainer(
      search: available ? search : null,
      scheduler: clock,
      policy: policy,
      overrides: [
        artworkRepositoryProvider.overrideWithValue(NoArtworkRepository()),
        audioPlayerPortProvider.overrideWithValue(player),
        notificationPermissionProvider.overrideWithValue(notifications),
        playSongsProvider.overrideWithValue(playSongs),
      ],
    );
    addTearDown(container.dispose);
    final page = SearchPage(
      onSongActions: (context, ref, song, {extraActions = const []}) async {
        actionSongs.add(song);
      },
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: wrap == null ? page : wrap(page),
        ),
      ),
    );
    await tester.pump();
  }

  /// Escribe [text]; si [wait], deja pasar el debounce y la respuesta.
  Future<void> type(WidgetTester tester, String text, {bool wait = true}) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    if (!wait) return;
    clock.advance(_debounce);
    await tester.pump();
    await tester.pump();
  }

  CatalogSearchState state() => container.read(catalogSearchProvider);

  Finder tiles() => find.byType(TakiSongTile);

  Finder byText(String text) => find.text(text);

  /// Desplaza la lista hasta el final y deja que reaccione.
  Future<void> scrollToEnd(WidgetTester tester) async {
    await tester.fling(find.byType(CustomScrollView), const Offset(0, -3000), 3000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
  }

  group('estructura', () {
    testWidgets('AppBar «Buscar» y campo con la pista', (tester) async {
      await pumpPage(tester);
      expect(find.widgetWithText(AppBar, 'Buscar'), findsOneWidget);
      expect(find.byType(TakiSearchField), findsOneWidget);
      expect(find.text(SearchTexts.hint), findsOneWidget);
    });

    testWidgets('no menciona a ningún proveedor', (tester) async {
      await pumpPage(tester);
      await type(tester, 'beat');
      final texts = [
        for (final t in tester.widgetList<Text>(find.byType(Text)))
          (t.data ?? '').toLowerCase(),
      ];
      expect(texts.where((t) => t.contains('jamendo')), isEmpty);
    });
  });

  group('Idle', () {
    testWidgets('estado inicial limpio con el mínimo de la política',
        (tester) async {
      await pumpPage(tester);
      expect(state(), const SearchIdle());
      expect(find.byType(TakiEmptyState), findsOneWidget);
      expect(byText(SearchTexts.idleTitle), findsOneWidget);
      expect(byText('Escribe al menos 2 caracteres para empezar.'),
          findsOneWidget);
      expect(tiles(), findsNothing);
      expect(search.calls, isEmpty);
    });

    testWidgets('una consulta corta no busca ni muestra error ni vacío',
        (tester) async {
      await pumpPage(tester);
      await type(tester, 'a');
      expect(state(), const SearchIdle());
      expect(byText(SearchTexts.idleTitle), findsOneWidget);
      expect(find.byType(TakiErrorState), findsNothing);
      expect(find.text(SearchTexts.emptyTitle), findsNothing);
      expect(search.calls, isEmpty);
    });
  });

  group('teclado', () {
    testWidgets('«buscar» del teclado salta el debounce', (tester) async {
      await pumpPage(tester);
      await tester.enterText(find.byType(TextField), 'beat');
      await tester.pump();
      expect(search.calls, isEmpty);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump();
      expect(search.calls.single.text, 'beat');
      expect(tiles(), findsNWidgets(3));
      expect(clock.pending, 0);
    });

    testWidgets('el mínimo mostrado sale de la política', (tester) async {
      await pumpPage(
        tester,
        policy: const CatalogSearchPolicy(minimumQueryLength: 4),
      );
      expect(byText('Escribe al menos 4 caracteres para empezar.'),
          findsOneWidget);
      await type(tester, 'abc');
      expect(search.calls, isEmpty);
    });
  });

  group('Unavailable', () {
    testWidgets('informa, sin Reintentar y con el campo deshabilitado',
        (tester) async {
      await pumpPage(tester, available: false);
      expect(state(), const SearchUnavailable());
      expect(byText(SearchTexts.unavailableTitle), findsOneWidget);
      expect(byText(SearchTexts.unavailableMessage), findsOneWidget);
      expect(find.byType(TakiButton), findsNothing);
      expect(find.byType(TakiErrorState), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    });

    testWidgets('no es un vacío', (tester) async {
      await pumpPage(tester, available: false);
      expect(find.text(SearchTexts.emptyTitle), findsNothing);
      expect(byText(SearchTexts.idleTitle), findsNothing);
    });
  });

  group('Typing', () {
    testWidgets('sin resultados previos: no muestra vacío ni error',
        (tester) async {
      await pumpPage(tester);
      await type(tester, 'be', wait: false);
      expect(state(), isA<SearchTyping>());
      expect(search.calls, isEmpty);
      expect(find.byType(TakiErrorState), findsNothing);
      expect(find.text(SearchTexts.emptyTitle), findsNothing);
    });

    testWidgets('conserva los resultados anteriores mientras se teclea',
        (tester) async {
      await pumpPage(tester);
      await type(tester, 'beat');
      expect(tiles(), findsNWidgets(3));
      await type(tester, 'beats', wait: false);
      expect(state(), isA<SearchTyping>());
      expect(tiles(), findsNWidgets(3));
      expect(find.text(SearchTexts.emptyTitle), findsNothing);
      expect(search.calls, hasLength(1));
    });

    testWidgets('tras un vacío, teclear no enseña «sin resultados» viejo',
        (tester) async {
      search.handler = (_) async => fakePage(0);
      await pumpPage(tester);
      await type(tester, 'zz');
      expect(find.text(SearchTexts.emptyTitle), findsOneWidget);
      await type(tester, 'zzz', wait: false);
      expect(find.text(SearchTexts.emptyTitle), findsNothing);
      expect(byText(SearchTexts.idleTitle), findsOneWidget);
    });

    testWidgets('tras un error, teclear no enseña el error viejo',
        (tester) async {
      search.handler = (_) async => throw const CatalogSearchFailure('x');
      await pumpPage(tester);
      await type(tester, 'zz');
      expect(find.byType(TakiErrorState), findsOneWidget);
      await type(tester, 'zzz', wait: false);
      expect(find.byType(TakiErrorState), findsNothing);
    });
  });

  group('Loading', () {
    testWidgets('primera búsqueda: indicador de carga, sin lista',
        (tester) async {
      final pending = Completer<CatalogSearchPage>();
      search.handler = (_) => pending.future;
      await pumpPage(tester);
      await type(tester, 'beat');
      expect(state(), isA<SearchLoading>());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tiles(), findsNothing);
      expect(find.byType(TakiEmptyState), findsNothing);
      expect(find.byType(TakiErrorState), findsNothing);
      pending.complete(fakePage(1));
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tiles(), findsOneWidget);
    });

    testWidgets('con resultados previos, la lista no desaparece',
        (tester) async {
      await pumpPage(tester);
      await type(tester, 'beat');
      expect(tiles(), findsNWidgets(3));

      final pending = Completer<CatalogSearchPage>();
      search.handler = (_) => pending.future;
      await type(tester, 'beats');
      expect(state(), isA<SearchLoading>());
      expect(tiles(), findsNWidgets(3));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(SearchTexts.emptyTitle), findsNothing);

      pending.complete(fakePage(1, from: 50));
      await tester.pump();
      await tester.pump();
      expect(tiles(), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('mientras busca otra consulta no pide más páginas',
        (tester) async {
      search.handler = (q) async => fakePage(20, hasMore: true);
      await pumpPage(tester);
      await type(tester, 'beat');
      final pending = Completer<CatalogSearchPage>();
      search.handler = (_) => pending.future;
      await type(tester, 'beats');
      await scrollToEnd(tester);
      expect(search.calls, hasLength(2));
    });

    testWidgets('tras un vacío, cargar muestra el spinner (no el vacío)',
        (tester) async {
      search.handler = (_) async => fakePage(0);
      await pumpPage(tester);
      await type(tester, 'zz');
      final pending = Completer<CatalogSearchPage>();
      search.handler = (_) => pending.future;
      await type(tester, 'zzz');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(SearchTexts.emptyTitle), findsNothing);
      pending.complete(fakePage(0));
      await tester.pump();
      await tester.pump();
    });

    testWidgets('tras Empty, Failed o Idle se olvidan los resultados viejos',
        (tester) async {
      // Results → Empty → Loading
      await pumpPage(tester);
      await type(tester, 'beat');
      search.handler = (_) async => fakePage(0);
      await type(tester, 'zzzz');
      final pending = Completer<CatalogSearchPage>();
      search.handler = (_) => pending.future;
      await type(tester, 'zzzzz');
      expect(tiles(), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.complete(fakePage(0));
      await tester.pump();
      await tester.pump();

      // Results → Failed → Loading (reintentar)
      search.handler = (_) async => fakePage(2);
      await type(tester, 'beat');
      expect(tiles(), findsNWidgets(2));
      search.handler = (_) async => throw const CatalogSearchFailure('x');
      await type(tester, 'beats');
      expect(find.byType(TakiErrorState), findsOneWidget);
      final retryPending = Completer<CatalogSearchPage>();
      search.handler = (_) => retryPending.future;
      await tester.tap(find.text(SearchTexts.retry));
      await tester.pump();
      expect(tiles(), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      retryPending.complete(fakePage(1));
      await tester.pump();
      await tester.pump();

      // Results → Idle → Loading
      await tester.tap(find.byTooltip(TakiSearchField.clearLabel));
      await tester.pump();
      expect(state(), const SearchIdle());
      final idlePending = Completer<CatalogSearchPage>();
      search.handler = (_) => idlePending.future;
      await type(tester, 'abc');
      expect(tiles(), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      idlePending.complete(fakePage(0));
      await tester.pump();
      await tester.pump();
    });

    testWidgets('si la nueva consulta termina vacía, reemplaza la lista',
        (tester) async {
      await pumpPage(tester);
      await type(tester, 'beat');
      search.handler = (_) async => fakePage(0);
      await type(tester, 'beatz');
      expect(tiles(), findsNothing);
      expect(find.text(SearchTexts.emptyTitle), findsOneWidget);
    });
  });

  group('Results', () {
    testWidgets('lista de TakiSongTile con título y artista', (tester) async {
      await pumpPage(tester);
      await type(tester, 'beat');
      expect(state(), isA<SearchResults>());
      expect(tiles(), findsNWidgets(3));
      expect(byText('T1'), findsOneWidget);
      expect(byText('T3'), findsOneWidget);
      expect(find.text('Artista'), findsNWidgets(3));
      expect(find.byType(TakiEmptyState), findsNothing);
      expect(search.calls.single.text, 'beat');
    });

    testWidgets('el campo conserva el texto escrito', (tester) async {
      await pumpPage(tester);
      await type(tester, 'beat');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'beat',
      );
    });

    testWidgets('la canción que suena se marca como tal', (tester) async {
      await pumpPage(tester);
      await type(tester, 'beat');
      player.emitState(PlaybackState(
        queue: [fakeSong(2)],
        currentIndex: 0,
        isPlaying: true,
      ));
      await tester.pump();
      await tester.pump();
      final playing = [
        for (final t in tester.widgetList<TakiSongTile>(tiles()))
          t.playback == TakiNowPlaying.none ? '' : t.song.title,
      ];
      expect(playing, ['', 'T2', '']);
    });

    testWidgets('borrar el campo vuelve al estado inicial', (tester) async {
      await pumpPage(tester);
      await type(tester, 'beat');
      await tester.tap(find.byTooltip(TakiSearchField.clearLabel));
      await tester.pump();
      expect(state(), const SearchIdle());
      expect(tiles(), findsNothing);
      expect(byText(SearchTexts.idleTitle), findsOneWidget);
    });
  });

  group('Empty', () {
    setUp(() => search = FakeCatalogSearch((_) async => fakePage(0)));

    testWidgets('TakiEmptyState noResults con la consulta, sin Reintentar',
        (tester) async {
      await pumpPage(tester);
      await type(tester, '  zz ');
      expect(state(), isA<SearchEmpty>());
      final empty = tester.widget<TakiEmptyState>(find.byType(TakiEmptyState));
      expect(empty.kind, TakiEmptyStateKind.noResults);
      expect(empty.action, isNull);
      expect(empty.secondaryAction, isNull);
      expect(find.text(SearchTexts.emptyTitle), findsOneWidget);
      expect(find.byType(TakiButton), findsNothing);
      expect(find.byType(TakiErrorState), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('Failed', () {
    testWidgets('TakiErrorState con Reintentar; reintenta la misma consulta',
        (tester) async {
      search.handler = (_) async => throw const CatalogSearchFailure('x');
      await pumpPage(tester);
      await type(tester, 'beat');
      expect(state(), isA<SearchFailed>());
      expect(find.byType(TakiErrorState), findsOneWidget);
      expect(byText(SearchTexts.failedTitle), findsOneWidget);
      expect(find.byType(TakiEmptyState), findsNothing);
      expect(search.calls, hasLength(1));

      search.handler = (_) async => fakePage(2);
      await tester.tap(find.text(SearchTexts.retry));
      await tester.pump();
      await tester.pump();
      expect(search.calls.map((c) => c.text), ['beat', 'beat']);
      expect(tiles(), findsNWidgets(2));
      expect(find.byType(TakiErrorState), findsNothing);
    });

    testWidgets('no reintenta solo', (tester) async {
      search.handler = (_) async => throw const CatalogSearchFailure('x');
      await pumpPage(tester);
      await type(tester, 'beat');
      clock.advance(const Duration(minutes: 5));
      await tester.pump(const Duration(minutes: 5));
      expect(search.calls, hasLength(1));
    });

    testWidgets('un fallo no se muestra como vacío', (tester) async {
      search.handler = (_) async => throw const CatalogSearchFailure('x');
      await pumpPage(tester);
      await type(tester, 'beat');
      expect(find.text(SearchTexts.emptyTitle), findsNothing);
    });
  });

  group('paginación', () {
    CatalogSearchPage pageFor(CatalogSearchQuery q) =>
        fakePage(20, from: q.offset + 1, hasMore: q.offset < 20);

    setUp(() => search = FakeCatalogSearch((q) async => pageFor(q)));

    testWidgets('al llegar al final pide la siguiente página, una vez',
        (tester) async {
      await pumpPage(tester);
      await type(tester, 'beat');
      expect(search.calls, hasLength(1));

      await scrollToEnd(tester);
      expect(search.calls.map((c) => (c.offset, c.limit)), [(0, 20), (20, 20)]);
      final results = state() as SearchResults;
      expect(results.items, hasLength(40));
      expect(results.hasMore, isFalse);
      expect(results.loadMore, LoadMoreStatus.idle);
    });

    testWidgets('no pide nada hasta acercarse al final', (tester) async {
      await pumpPage(tester);
      await type(tester, 'beat');
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -200));
      await tester.pump();
      expect(search.calls, hasLength(1));
    });

    testWidgets('mientras carga muestra el loader al pie', (tester) async {
      await pumpPage(tester);
      await type(tester, 'beat');
      final pending = Completer<CatalogSearchPage>();
      search.handler = (_) => pending.future;
      await scrollToEnd(tester);
      expect((state() as SearchResults).loadMore, LoadMoreStatus.loading);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == SearchTexts.loadingMore), findsOneWidget);
      pending.complete(fakePage(20, from: 21));
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('sin más resultados no hace llamadas adicionales',
        (tester) async {
      search.handler = (q) async => fakePage(20, hasMore: false);
      await pumpPage(tester);
      await type(tester, 'beat');
      await scrollToEnd(tester);
      await scrollToEnd(tester);
      expect(search.calls, hasLength(1));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('página posterior vacía: fin de lista, sin vacío ni error',
        (tester) async {
      search.handler = (q) async =>
          q.offset == 0 ? fakePage(20, hasMore: true) : fakePage(0, hasMore: true);
      await pumpPage(tester);
      await type(tester, 'beat');
      await scrollToEnd(tester);
      expect(search.calls, hasLength(2));
      expect(find.byType(TakiEmptyState), findsNothing);
      expect(find.byType(TakiErrorState), findsNothing);
      expect(find.text(SearchTexts.retry), findsNothing);
      expect((state() as SearchResults).items, hasLength(20));
      expect((state() as SearchResults).hasMore, isFalse);
      await scrollToEnd(tester);
      expect(search.calls, hasLength(2));
      expect(find.text('T20'), findsOneWidget);
    });

    group('fallo de la página siguiente', () {
      setUp(() {
        search = FakeCatalogSearch((q) async =>
            q.offset == 0 ? fakePage(20, hasMore: true) : throw const CatalogSearchFailure('x'));
      });

      testWidgets('conserva la lista y muestra Reintentar al pie',
          (tester) async {
        await pumpPage(tester);
        await type(tester, 'beat');
        await scrollToEnd(tester);

        expect(state(), isA<SearchResults>());
        expect((state() as SearchResults).loadMore, LoadMoreStatus.failed);
        expect(byText(SearchTexts.loadMoreFailed), findsOneWidget);
        expect(find.text(SearchTexts.retry), findsOneWidget);
        expect(find.text('T20'), findsOneWidget);
        expect(find.byType(TakiErrorState), findsNothing);
        expect(find.byType(TakiEmptyState), findsNothing);
      });

      testWidgets('no reintenta al seguir desplazando', (tester) async {
        await pumpPage(tester);
        await type(tester, 'beat');
        await scrollToEnd(tester);
        await scrollToEnd(tester);
        await tester.fling(find.byType(CustomScrollView), const Offset(0, 300), 1000);
        await tester.pump(const Duration(milliseconds: 600));
        await scrollToEnd(tester);
        expect(search.calls, hasLength(2));
      });

      testWidgets('al buscar otra consulta, el pie fallido no se muestra',
          (tester) async {
        await pumpPage(tester);
        await type(tester, 'beat');
        await scrollToEnd(tester);
        expect(find.text(SearchTexts.loadMoreFailed), findsOneWidget);

        final pending = Completer<CatalogSearchPage>();
        search.handler = (_) => pending.future;
        await type(tester, 'beats');
        expect(state(), isA<SearchLoading>());
        expect(tiles(), findsWidgets);
        expect(find.text(SearchTexts.loadMoreFailed), findsNothing);
        expect(find.text(SearchTexts.retry), findsNothing);
        pending.complete(fakePage(1));
        await tester.pump();
        await tester.pump();
      });

      testWidgets('Reintentar pide exactamente la misma página',
          (tester) async {
        await pumpPage(tester);
        await type(tester, 'beat');
        await scrollToEnd(tester);

        search.handler = (q) async => fakePage(20, from: 21);
        await tester.tap(find.text(SearchTexts.retry));
        await tester.pump();
        await tester.pump();

        expect(search.calls.map((c) => c.offset), [0, 20, 20]);
        final results = state() as SearchResults;
        expect(results.items, hasLength(40));
        expect(results.loadMore, LoadMoreStatus.idle);
        expect(find.text(SearchTexts.retry), findsNothing);
      });

      testWidgets('Reintentar que vuelve a fallar conserva todo', (tester) async {
        await pumpPage(tester);
        await type(tester, 'beat');
        await scrollToEnd(tester);
        await tester.tap(find.text(SearchTexts.retry));
        await tester.pump();
        await tester.pump();
        expect(search.calls.map((c) => c.offset), [0, 20, 20]);
        expect((state() as SearchResults).items, hasLength(20));
        expect(find.text(SearchTexts.retry), findsOneWidget);
      });
    });
  });

  group('reproducir', () {
    testWidgets('tap: cierra el teclado y reproduce la canción tocada',
        (tester) async {
      await pumpPage(tester);
      await type(tester, 'beat');
      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.focusNode.hasFocus, isTrue);

      await tester.tap(byText('T2'));
      await tester.pump();

      expect(field.focusNode.hasFocus, isFalse);
      final captured =
          verify(() => playSongs(captureAny(), captureAny())).captured;
      expect((captured[0] as List<Song>).single, fakeSong(2));
      expect(captured[1], 0);
      expect(notifications.requests, 1);
    });

    testWidgets('tap NO abre el menú de acciones', (tester) async {
      await pumpPage(tester);
      await type(tester, 'beat');
      await tester.tap(byText('T1'));
      await tester.pump();
      expect(actionSongs, isEmpty);
    });

    testWidgets('cada fila tiene ⋯ y pulsación larga (3.2F)', (tester) async {
      await pumpPage(tester);
      await type(tester, 'beat');
      for (final tile in tester.widgetList<TakiSongTile>(tiles())) {
        expect(tile.onLongPress, isNotNull);
        expect(tile.onMore, isNotNull);
      }
      expect(find.byTooltip(TakiSongTile.moreLabel), findsNWidgets(3));
    });

    testWidgets('⋯ abre las acciones con la canción de esa fila (identidad '
        'intacta) y NO reproduce', (tester) async {
      await pumpPage(tester);
      await type(tester, 'beat');
      final more = find.descendant(
        of: find.ancestor(of: byText('T2'), matching: tiles()),
        matching: find.byTooltip(TakiSongTile.moreLabel),
      );
      await tester.tap(more);
      await tester.pump();

      expect(actionSongs.single, fakeSong(2));
      expect(actionSongs.single.musicIdentity, fakeIdentity(2));
      verifyNever(() => playSongs(any(), any()));
    });

    testWidgets('pulsación larga abre las acciones de esa fila',
        (tester) async {
      await pumpPage(tester);
      await type(tester, 'beat');
      await tester.longPress(byText('T3'));
      await tester.pump();
      expect(actionSongs.single.musicIdentity, fakeIdentity(3));
      verifyNever(() => playSongs(any(), any()));
    });

    testWidgets('el tap usa un solo caso de uso (sin resolver URLs)',
        (tester) async {
      await pumpPage(tester);
      await type(tester, 'beat');
      await tester.tap(byText('T1'));
      await tester.pump();
      verify(() => playSongs(any(), any())).called(1);
      expect(search.calls, hasLength(1));
    });
  });

  group('foco y teclado', () {
    bool focused(WidgetTester tester) =>
        tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus;

    testWidgets('al entrar, el campo recibe el foco tras el primer frame',
        (tester) async {
      await pumpPage(tester);
      expect(focused(tester), isTrue);
    });

    testWidgets('un rebuild no vuelve a pedir el foco', (tester) async {
      await pumpPage(tester);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(focused(tester), isFalse);

      // Cambia el estado (reconstruye la página) sin que el usuario enfoque.
      container.read(catalogSearchProvider.notifier).setQuery('beat');
      await tester.pump();
      clock.advance(_debounce);
      await tester.pump();
      await tester.pump();
      expect(state(), isA<SearchResults>());
      expect(focused(tester), isFalse);
    });

    testWidgets('cambiar la consulta no roba ni suelta el foco', (tester) async {
      await pumpPage(tester);
      await type(tester, 'be');
      expect(focused(tester), isTrue);
      await type(tester, 'beat');
      expect(focused(tester), isTrue);
    });

    testWidgets('salir de la pantalla libera foco y controller sin errores',
        (tester) async {
      await pumpPage(tester);
      expect(focused(tester), isTrue);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(tester.takeException(), isNull);
      expect(find.byType(EditableText), findsNothing);
    });

    testWidgets('la pestaña inactiva suelta el foco y al volver lo recupera',
        (tester) async {
      final active = ValueNotifier(true);
      addTearDown(active.dispose);
      await pumpPage(
        tester,
        wrap: (page) => ValueListenableBuilder<bool>(
          valueListenable: active,
          builder: (_, on, _) => TickerMode(enabled: on, child: page),
        ),
      );
      expect(focused(tester), isTrue);

      active.value = false;
      await tester.pump();
      expect(focused(tester), isFalse);

      active.value = true;
      await tester.pump();
      await tester.pump();
      expect(focused(tester), isTrue);
    });

    testWidgets('entrar con la pestaña inactiva no pide el foco',
        (tester) async {
      await pumpPage(
        tester,
        wrap: (page) => TickerMode(enabled: false, child: page),
      );
      expect(focused(tester), isFalse);
    });
  });
}
