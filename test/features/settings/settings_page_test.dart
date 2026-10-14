import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taki/app/theme/app_theme.dart';
import 'package:taki/core/catalog/catalog_sources_providers.dart';
import 'package:taki/core/domain/entities/catalog_provider_info.dart';
import 'package:taki/core/domain/ports/catalog_sources.dart';
import 'package:taki/core/domain/services/source_catalog_sources.dart';
import 'package:taki/features/settings/domain/entities/storage_usage.dart';
import 'package:taki/features/settings/presentation/pages/settings_page.dart';
import 'package:taki/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/catalog_fakes.dart';
import '../../helpers/library_fakes.dart';
import '../../helpers/settings_fakes.dart';

void main() {
  late MockMediaPermission permission;
  late MockSongRepository songs;
  late FakeArtworkCacheStorage cache;
  String? clipboard;

  setUp(() {
    permission = MockMediaPermission();
    songs = MockSongRepository();
    cache = FakeArtworkCacheStorage(
      const StorageUsage(bytes: 4000, fileCount: 2),
    );
    clipboard = null;
    when(permission.isGranted).thenAnswer((_) async => true);
    when(permission.isPermanentlyDenied).thenAnswer((_) async => false);
    when(songs.getSongs).thenAnswer((_) async => []);
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    CatalogSources? catalogSources,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(412 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...libraryOverrides(
            permission: permission,
            songs: songs,
            catalogSources: catalogSources,
          ),
          appInfoPortProvider.overrideWithValue(FakeAppInfo()),
          artworkCacheStorageProvider.overrideWithValue(cache),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows every section with its rows', (tester) async {
    await pumpPage(tester);

    expect(find.text('Ajustes'), findsOneWidget);
    for (final group in [
      'BIBLIOTECA',
      'ALMACENAMIENTO',
      'CATÁLOGO EN LÍNEA',
      'PRIVACIDAD',
      'ACERCA DE',
    ]) {
      expect(find.text(group), findsOneWidget, reason: group);
    }
    expect(find.text('Música en tu teléfono'), findsOneWidget);
    expect(find.text('Volver a escanear'), findsOneWidget);
    expect(find.text('Caché de carátulas'), findsOneWidget);
    expect(find.text('Vaciar caché de carátulas'), findsOneWidget);
    expect(find.text('Licencias de código abierto'), findsOneWidget);
  });

  testWidgets('shows the app version from the app info port', (tester) async {
    await pumpPage(tester);

    expect(find.text('Versión 1.2.3 (45)'), findsOneWidget);
  });

  group('library', () {
    testWidgets('summarizes the scanned songs', (tester) async {
      when(songs.getSongs).thenAnswer(
        (_) async => [buildSong(id: 1), buildSong(id: 2, title: 'Otra')],
      );

      await pumpPage(tester);

      expect(find.text('2 canciones · 6 min'), findsOneWidget);
    });

    testWidgets('without permission, the row asks for it and rescan is off',
        (tester) async {
      when(permission.isGranted).thenAnswer((_) async => false);
      when(permission.request).thenAnswer((_) async => false);

      await pumpPage(tester);

      expect(
        find.text('Sin permiso. Toca para permitir el acceso'),
        findsOneWidget,
      );

      await tester.tap(find.text('Volver a escanear'));
      await tester.pumpAndSettle();
      verifyNever(permission.request);

      await tester.tap(find.text('Música en tu teléfono'));
      await tester.pumpAndSettle();
      verify(permission.request).called(1);
    });

    testWidgets('rescan reloads the library and confirms', (tester) async {
      await pumpPage(tester);
      clearInteractions(songs);

      await tester.tap(find.text('Volver a escanear'));
      await tester.pumpAndSettle();

      verify(songs.getSongs).called(1);
      expect(find.text('Biblioteca actualizada'), findsOneWidget);
    });
  });

  group('storage', () {
    testWidgets('shows the cache size', (tester) async {
      await pumpPage(tester);

      expect(find.text('2 archivos · 4 kB'), findsOneWidget);
    });

    testWidgets('an empty cache says so and cannot be cleared', (tester) async {
      cache.current = StorageUsage.empty;

      await pumpPage(tester);
      expect(find.text('Vacía'), findsOneWidget);

      await tester.tap(find.text('Vaciar caché de carátulas'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(cache.clearCalls, 0);
    });

    testWidgets('clearing asks first and reports what was freed',
        (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('Vaciar caché de carátulas'));
      await tester.pumpAndSettle();
      expect(find.text('¿Vaciar la caché de carátulas?'), findsOneWidget);
      expect(cache.clearCalls, 0, reason: 'nothing is deleted before confirming');

      await tester.tap(find.text('Vaciar'));
      await tester.pumpAndSettle();

      expect(cache.clearCalls, 1);
      expect(find.text('Se liberaron 4 kB'), findsOneWidget);
      expect(find.text('Vacía'), findsOneWidget);
    });

    testWidgets('cancelling keeps the cache', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('Vaciar caché de carátulas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(cache.clearCalls, 0);
      expect(find.text('2 archivos · 4 kB'), findsOneWidget);
    });
  });

  group('online catalog', () {
    testWidgets('without sources, says Taki works with local music only',
        (tester) async {
      await pumpPage(tester, catalogSources: SourceCatalogSources(const []));

      expect(find.text('Sin catálogos en línea'), findsOneWidget);
    });

    testWidgets('lists each registered source by its label', (tester) async {
      await pumpPage(
        tester,
        catalogSources: SourceCatalogSources([
          CatalogSourceRegistration(
            CatalogProviderInfo(source: fakeCatalogSource, label: 'Fake'),
            FakeCatalogSearch(),
          ),
        ]),
      );

      expect(find.text('Fake'), findsOneWidget);
      expect(find.text('Sin catálogos en línea'), findsNothing);
      expect(find.text('Origen y licencia'), findsOneWidget);
    });
  });

  testWidgets('copying diagnostics puts the report on the clipboard',
      (tester) async {
    when(songs.getSongs).thenAnswer((_) async => [buildSong(id: 1)]);

    await pumpPage(tester);
    await tester.tap(find.text('Copiar información de diagnóstico'));
    await tester.pumpAndSettle();

    expect(clipboard, contains('Taki 1.2.3 (45)'));
    expect(clipboard, contains('Platform: Android 16 (API 36)'));
    expect(clipboard, contains('Library: 1 songs'));
    expect(clipboard, contains('Artwork cache: 2 files, 4 kB'));
    expect(clipboard, isNot(contains('Canción')), reason: 'no song titles');
    expect(find.text('Información copiada al portapapeles'), findsOneWidget);
  });

  testWidgets('no overflow at 150 % text scale', (tester) async {
    await pumpPage(tester, textScale: 1.5);

    expect(tester.takeException(), isNull);
  });

  test('the registry exposes no catalog providers by default in tests', () {
    final container = ProviderContainer(overrides: [
      catalogSourcesProvider
          .overrideWithValue(SourceCatalogSources(const [])),
    ]);
    addTearDown(container.dispose);

    expect(container.read(catalogSourcesProvider).available, isEmpty);
  });
}
