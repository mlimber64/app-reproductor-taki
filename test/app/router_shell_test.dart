import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taki/app/app.dart';
import 'package:taki/app/router.dart';
import 'package:taki/core/domain/entities/catalog_provider_info.dart';
import 'package:taki/core/domain/services/source_catalog_sources.dart';
import 'package:taki/features/search/presentation/pages/search_page.dart';
import 'package:taki/features/search/presentation/providers/catalog_search_providers.dart';

import '../helpers/catalog_fakes.dart';
import '../helpers/library_fakes.dart';

void main() {
  late FakeCatalogSearch search;

  setUp(() => search = FakeCatalogSearch());

  Future<void> pumpApp(WidgetTester tester, {required bool catalog}) async {
    final permission = MockMediaPermission();
    when(permission.isGranted).thenAnswer((_) async => true);
    final songs = MockSongRepository();
    when(songs.getSongs).thenAnswer((_) async => []);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...libraryOverrides(
            permission: permission,
            songs: songs,
            catalogSources: SourceCatalogSources([
              if (catalog)
                CatalogSourceRegistration(
                  CatalogProviderInfo(source: fakeCatalogSource, label: 'Fake'),
                  search,
                ),
            ]),
          ),
          searchSchedulerProvider.overrideWithValue(ManualSearchScheduler()),
        ],
        child: const TakiApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  NavigationBar bar(WidgetTester tester) =>
      tester.widget<NavigationBar>(find.byType(NavigationBar));

  List<String> labels(WidgetTester tester) => [
        for (final d in bar(tester).destinations)
          (d as NavigationDestination).label,
      ];

  Future<void> goTo(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    ));
    await tester.pumpAndSettle();
  }

  Finder pageTitle(String title) => find.widgetWithText(AppBar, title);

  group('con catálogo disponible', () {
    testWidgets('5 pestañas, «Buscar» entre Biblioteca y Playlists',
        (tester) async {
      await pumpApp(tester, catalog: true);
      expect(labels(tester),
          ['Biblioteca', 'Buscar', 'Playlists', 'Favoritos', 'Ajustes']);
      expect(bar(tester).selectedIndex, 0);
      expect(pageTitle('Biblioteca'), findsOneWidget);
    });

    testWidgets('cada destino abre su página y el índice coincide',
        (tester) async {
      await pumpApp(tester, catalog: true);
      final expected = {
        'Biblioteca': (0, 'Biblioteca'),
        'Buscar': (1, 'Buscar'),
        'Playlists': (2, 'Playlists'),
        'Favoritos': (3, 'Favoritos'),
        'Ajustes': (4, 'Ajustes'),
      };
      for (final entry in expected.entries) {
        await goTo(tester, entry.key);
        expect(bar(tester).selectedIndex, entry.value.$1, reason: entry.key);
        expect(pageTitle(entry.value.$2), findsOneWidget, reason: entry.key);
      }
      // Y de vuelta, en otro orden.
      await goTo(tester, 'Buscar');
      expect(bar(tester).selectedIndex, 1);
      expect(find.byType(SearchPage), findsOneWidget);
      await goTo(tester, 'Biblioteca');
      expect(bar(tester).selectedIndex, 0);
    });

    testWidgets('«Buscar» vive en /search', (tester) async {
      await pumpApp(tester, catalog: true);
      await goTo(tester, 'Buscar');
      final router = GoRouter.of(tester.element(find.byType(SearchPage)));
      expect(router.routeInformationProvider.value.uri.path,
          AppRoutes.search);
      expect(AppRoutes.search, '/search');
    });

    testWidgets('Buscar recibe el foco al entrar y lo suelta al salir',
        (tester) async {
      await pumpApp(tester, catalog: true);
      bool focused() => tester
          .widget<EditableText>(find.byType(EditableText))
          .focusNode
          .hasFocus;

      await goTo(tester, 'Buscar');
      expect(focused(), isTrue);

      await goTo(tester, 'Playlists');
      expect(
        tester
            .widget<EditableText>(
                find.byType(EditableText, skipOffstage: false))
            .focusNode
            .hasFocus,
        isFalse,
      );

      await goTo(tester, 'Buscar');
      expect(focused(), isTrue);
    });

    testWidgets('la búsqueda conserva su estado al cambiar de pestaña',
        (tester) async {
      search.handler = (_) async => fakePage(2);
      await pumpApp(tester, catalog: true);
      await goTo(tester, 'Buscar');
      await tester.enterText(find.byType(TextField), 'beat');
      await tester.pump();
      final container = ProviderScope.containerOf(
          tester.element(find.byType(SearchPage)));
      container.read(catalogSearchProvider.notifier).submit('beat');
      await tester.pump();
      await tester.pump();
      expect(find.text('T1'), findsOneWidget);

      await goTo(tester, 'Favoritos');
      await goTo(tester, 'Buscar');
      expect(find.text('T1'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'beat',
      );
    });

    testWidgets('volver a tocar la pestaña activa no rompe el índice',
        (tester) async {
      await pumpApp(tester, catalog: true);
      await goTo(tester, 'Playlists');
      await goTo(tester, 'Playlists');
      expect(bar(tester).selectedIndex, 2);
      expect(pageTitle('Playlists'), findsOneWidget);
    });
  });

  group('sin catálogo', () {
    testWidgets('conserva las 4 pestañas de siempre', (tester) async {
      await pumpApp(tester, catalog: false);
      expect(labels(tester), ['Biblioteca', 'Playlists', 'Favoritos', 'Ajustes']);
      expect(find.byType(SearchPage, skipOffstage: false), findsNothing);
    });

    testWidgets('los índices no se desalinean sin Buscar', (tester) async {
      await pumpApp(tester, catalog: false);
      final expected = {
        'Biblioteca': 0,
        'Playlists': 1,
        'Favoritos': 2,
        'Ajustes': 3,
      };
      for (final entry in expected.entries) {
        await goTo(tester, entry.key);
        expect(bar(tester).selectedIndex, entry.value, reason: entry.key);
        expect(pageTitle(entry.key), findsOneWidget, reason: entry.key);
      }
    });
  });
}
