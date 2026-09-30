import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taki/app/app.dart';
import 'package:taki/core/artwork/artwork_providers.dart';
import 'package:taki/core/domain/entities/song.dart';
import 'package:taki/core/domain/ports/artwork_repository.dart';
import 'package:taki/core/widgets/taki_artwork.dart';
import 'package:taki/core/widgets/taki_button.dart';
import 'package:taki/core/widgets/taki_empty_state.dart';
import 'package:taki/core/widgets/taki_error_state.dart';
import 'package:taki/core/widgets/taki_playlist_card.dart';
import 'package:taki/core/widgets/taki_section_header.dart';
import 'package:taki/features/playlists/domain/entities/playlist.dart';
import 'package:taki/features/playlists/presentation/pages/playlist_detail_page.dart';
import 'package:taki/features/playlists/presentation/pages/playlists_page.dart';
import 'package:taki/features/playlists/presentation/providers/playlists_providers.dart';

import '../../../helpers/library_fakes.dart';
import '../../../helpers/playlists_fakes.dart';

void main() {
  late _GatedPlaylistsRepository playlists;

  final a = buildSong(id: 1, title: 'A', durationMs: 120000);
  final b = buildSong(id: 2, title: 'B', durationMs: 180000);

  setUp(() => playlists = _GatedPlaylistsRepository());

  /// Abre la app y va a la pestaña Playlists.
  Future<void> openPlaylistsTab(
    WidgetTester tester, {
    List<Song>? songs,
    List<Override> overrides = const [],
    Size? size,
    double textScale = 1,
    bool settle = true,
  }) async {
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    if (textScale != 1) {
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }
    final permission = MockMediaPermission();
    when(permission.isGranted).thenAnswer((_) async => true);
    final library = MockSongRepository();
    when(library.getSongs).thenAnswer((_) async => songs ?? [a, b]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...libraryOverrides(
            permission: permission,
            songs: library,
            playlists: playlists,
          ),
          ...overrides,
        ],
        child: const TakiApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Playlists'),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
  }

  TextButton dialogButton(WidgetTester tester, String label) =>
      tester.widget<TextButton>(find.widgetWithText(TextButton, label));

  testWidgets('estado vacío', (tester) async {
    await openPlaylistsTab(tester);

    expect(find.text('Nueva playlist'), findsOneWidget);
    expect(
      find.text('Aún no tienes playlists. Crea la primera para agrupar tus '
          'canciones.'),
      findsOneWidget,
    );
  });

  testWidgets('crear valida el nombre y abre el detalle', (tester) async {
    await openPlaylistsTab(tester);

    await tester.tap(find.text('Nueva playlist'));
    await tester.pumpAndSettle();
    expect(find.text('Crear'), findsOneWidget);
    expect(dialogButton(tester, 'Crear').onPressed, isNull);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(find.text('Escribe un nombre'), findsOneWidget);
    expect(dialogButton(tester, 'Crear').onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'x' * 61);
    await tester.pump();
    expect(find.text('Máximo 60 caracteres'), findsOneWidget);
    expect(dialogButton(tester, 'Crear').onPressed, isNull);

    await tester.enterText(find.byType(TextField), '  Para correr ');
    await tester.pump();
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();

    expect(playlists.namesInOrder(), ['Para correr']);
    expect(find.byType(PlaylistDetailPage), findsOneWidget);
    expect(find.text('PLAYLIST'), findsOneWidget);
    // El detalle está dentro de la pestaña: la barra inferior sigue visible.
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('lista las playlists con su resumen', (tester) async {
    playlists
      ..seed('Vacía')
      ..seed('Con canciones', songs: [a, b]);
    await openPlaylistsTab(tester);

    expect(find.text('TUS PLAYLISTS'), findsOneWidget);
    expect(find.text('2 canciones · 5 min'), findsOneWidget);
    expect(find.text('0 canciones'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Con canciones')).dy,
      lessThan(tester.getTopLeft(find.text('Vacía')).dy),
      reason: 'la modificada más recientemente primero',
    );
  });

  testWidgets('renombrar desde la pulsación larga', (tester) async {
    playlists.seed('Vieja');
    await openPlaylistsTab(tester);

    await tester.longPress(find.text('Vieja'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Renombrar'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Vieja',
    );
    await tester.enterText(find.byType(TextField), 'Nueva');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(playlists.namesInOrder(), ['Nueva']);
    expect(find.text('Nueva'), findsOneWidget);
  });

  testWidgets('eliminar pide confirmación', (tester) async {
    playlists.seed('Adiós');
    await openPlaylistsTab(tester);

    await tester.longPress(find.text('Adiós'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar «Adiós»?'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(playlists.namesInOrder(), ['Adiós']);

    await tester.longPress(find.text('Adiós'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(playlists.namesInOrder(), isEmpty);
    expect(find.text('Playlist eliminada'), findsOneWidget);
  });

  testWidgets('base no disponible: error y Reintentar', (tester) async {
    playlists
      ..seed('Guardada')
      ..failing = true;
    await openPlaylistsTab(tester);

    expect(find.text('Playlists no disponibles'), findsOneWidget);

    playlists.failing = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Guardada'), findsOneWidget);
  });

  group('Design System (Fase 1.7C-1)', () {
    // Canciones con álbumes distintos para las portadas.
    final s11 = buildSong(id: 11, title: 's11', albumId: 11, durationMs: 60000);
    final s22 = buildSong(id: 22, title: 's22', albumId: 22, durationMs: 60000);
    final s33 = buildSong(id: 33, title: 's33', albumId: 33, durationMs: 60000);
    final s44 = buildSong(id: 44, title: 's44', albumId: 44, durationMs: 60000);
    final s11b = buildSong(id: 12, title: 's11b', albumId: 11);
    final noAlbum = buildSong(id: 50, title: 'sin álbum', albumId: null);
    final library = [s11, s22, s33, s44, s11b, noAlbum];

    Finder cardFinder(String title) => find.ancestor(
          of: find.text(title),
          matching: find.byType(TakiPlaylistCard),
        );

    TakiPlaylistCard cardOf(WidgetTester tester, String title) =>
        tester.widget<TakiPlaylistCard>(cardFinder(title));

    TakiArtwork coverOf(WidgetTester tester, String title) =>
        tester.widget<TakiArtwork>(
          find.descendant(
            of: cardFinder(title),
            matching: find.byType(TakiArtwork),
          ),
        );

    List<int?> coverBytes(WidgetTester tester, String title) => [
          for (final image in coverOf(tester, title).mosaic!)
            (image as MemoryImage?)?.bytes.first,
        ];

    ProviderContainer containerOf(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(PlaylistsPage)));

    /// Solo el spinner de carga.
    Finder loadingSpinner() => find.byWidgetPredicate(
          (w) => w.runtimeType == CircularProgressIndicator,
        );

    group('tarjetas', () {
      testWidgets('cada playlist es una TakiPlaylistCard con título y resumen',
          (tester) async {
        playlists
          ..seed('Vacía')
          ..seed('Con canciones', songs: [a, b]);
        await openPlaylistsTab(tester);

        expect(find.byType(TakiPlaylistCard), findsNWidgets(2));
        final full = cardOf(tester, 'Con canciones');
        expect(full.title, 'Con canciones');
        expect(full.subtitle, '2 canciones · 5 min');
        // El resumen va entero en subtitle: sin songCount no dice "Vacía".
        expect(full.songCount, isNull);
        expect(full.showChevron, isTrue);
        expect(full.onTap, isNotNull);
        expect(full.onLongPress, isNotNull);
        expect(cardOf(tester, 'Vacía').subtitle, '0 canciones');
        expect(find.text(TakiPlaylistCard.emptyLabel), findsOneWidget,
            reason: 'solo el nombre de la playlist "Vacía"');
      });

      testWidgets('respeta el orden del provider (modificada más reciente '
          'primero)', (tester) async {
        playlists
          ..seed('Uno')
          ..seed('Dos')
          ..seed('Tres');
        await openPlaylistsTab(tester);
        final byProvider = containerOf(tester)
            .read(playlistsProvider)
            .requireValue
            .map((p) => p.name)
            .toList();
        expect(byProvider, ['Tres', 'Dos', 'Uno']);

        final rendered = tester
            .widgetList<TakiPlaylistCard>(find.byType(TakiPlaylistCard))
            .map((c) => c.title)
            .toList();
        expect(rendered, byProvider);

        // Renombrar "Uno" la sube al principio.
        await tester.longPress(find.text('Uno'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Renombrar'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Uno bis');
        await tester.tap(find.text('Guardar'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widgetList<TakiPlaylistCard>(find.byType(TakiPlaylistCard))
              .map((c) => c.title),
          ['Uno bis', 'Tres', 'Dos'],
        );
      });

      testWidgets('el songCount de la base incluye canciones ausentes',
          (tester) async {
        final ghost = buildSong(id: 99, title: 'fuera', durationMs: 60000);
        playlists.seed('Mixta', songs: [a, ghost]);
        await openPlaylistsTab(tester);

        expect(cardOf(tester, 'Mixta').subtitle, '2 canciones · 3 min');
      });

      testWidgets('tocar una tarjeta abre el detalle de esa playlist',
          (tester) async {
        playlists
          ..seed('Primera', songs: [a])
          ..seed('Segunda', songs: [b]);
        await openPlaylistsTab(tester);

        await tester.tap(find.text('Primera'));
        await tester.pumpAndSettle();

        final detail =
            tester.widget<PlaylistDetailPage>(find.byType(PlaylistDetailPage));
        expect(detail.playlistId, 1);
        expect(find.text('Primera'), findsOneWidget);
      });

      testWidgets('la pulsación larga abre Renombrar / Eliminar',
          (tester) async {
        playlists.seed('Mía');
        await openPlaylistsTab(tester);

        await tester.longPress(find.text('Mía'));
        await tester.pumpAndSettle();

        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.text('Renombrar'), findsOneWidget);
        expect(find.text('Eliminar'), findsOneWidget);
        expect(find.byType(PlaylistDetailPage), findsNothing);
      });
    });

    group('portadas', () {
      testWidgets('vacía: mosaico sin imágenes (placeholder con borde)',
          (tester) async {
        playlists.seed('Nada');
        await openPlaylistsTab(tester, songs: library);

        final cover = coverOf(tester, 'Nada');
        expect(cover.mosaic, isEmpty);
        expect(cover.kind, TakiArtworkKind.playlist);
        expect(cover.size, TakiPlaylistCard.artworkSize);
      });

      testWidgets('un álbum: su carátula (bytes → MemoryImage)',
          (tester) async {
        final artwork = _BytesArtworkRepository();
        playlists.seed('Uno', songs: [s11, s11b]);
        await openPlaylistsTab(
          tester,
          songs: library,
          overrides: [artworkRepositoryProvider.overrideWithValue(artwork)],
        );

        expect(coverBytes(tester, 'Uno'), [11]);
      });

      testWidgets('varios álbumes (menos de 4): distintos, en orden',
          (tester) async {
        final artwork = _BytesArtworkRepository();
        playlists.seed('Dos', songs: [s22, s11, s22, s11b]);
        await openPlaylistsTab(
          tester,
          songs: library,
          overrides: [artworkRepositoryProvider.overrideWithValue(artwork)],
        );

        // TakiArtwork.mosaic con menos de 4 muestra la primera.
        expect(coverBytes(tester, 'Dos'), [22, 11]);
      });

      testWidgets('4 álbumes distintos: mosaico 2×2', (tester) async {
        final artwork = _BytesArtworkRepository();
        playlists.seed('Cuatro', songs: [s11, s22, s33, s44]);
        await openPlaylistsTab(
          tester,
          songs: library,
          overrides: [artworkRepositoryProvider.overrideWithValue(artwork)],
        );

        expect(coverBytes(tester, 'Cuatro'), [11, 22, 33, 44]);
        final images = find.descendant(
          of: cardFinder('Cuatro'),
          matching: find.byType(Image),
        );
        expect(images, findsNWidgets(4));
      });

      testWidgets('con canciones sin carátula: una pieza sin imagen',
          (tester) async {
        playlists.seed('Sin arte', songs: [noAlbum]);
        await openPlaylistsTab(tester, songs: library);

        expect(coverOf(tester, 'Sin arte').mosaic, [null]);
      });

      testWidgets('las carátulas no se vuelven a pedir al reconstruir',
          (tester) async {
        final artwork = _BytesArtworkRepository();
        playlists
          ..seed('Cuatro', songs: [s11, s22, s33, s44])
          ..seed('Otra', songs: [s11]);
        await openPlaylistsTab(
          tester,
          songs: library,
          overrides: [artworkRepositoryProvider.overrideWithValue(artwork)],
        );
        final before = artwork.requests.length;
        expect(artwork.requests.map((r) => r.$1).toSet(), {11, 22, 33, 44});

        // Renombrar emite una lista nueva y reordena las tarjetas.
        await tester.longPress(find.text('Cuatro'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Renombrar'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Cuatro bis');
        await tester.tap(find.text('Guardar'));
        await tester.pumpAndSettle();

        expect(find.text('Cuatro bis'), findsOneWidget);
        expect(artwork.requests.length, before);
      });
    });

    group('Nueva playlist', () {
      testWidgets('es un TakiButton secundario con icono, alineado al inicio; '
          'el área táctil es la píldora visible', (tester) async {
        final handle = tester.ensureSemantics();
        await openPlaylistsTab(tester, size: const Size(360, 800));

        final button = find.widgetWithText(TakiButton, 'Nueva playlist');
        final widget = tester.widget<TakiButton>(button);
        expect(widget.variant, TakiButtonVariant.secondary);
        expect(widget.icon, Icons.add_rounded);
        final rect = tester.getRect(button);
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(rect.left, 16);
        // La píldora dibujada (el Container con la forma) ocupa exactamente
        // el área del botón: nada táctil a su derecha.
        final pill = find.descendant(
          of: button,
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.decoration is ShapeDecoration,
          ),
        );
        expect(tester.getRect(pill), rect);
        expect(rect.width, lessThan(360 - 2 * 16));

        await tester.tapAt(Offset(rect.right + 24, rect.center.dy));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        await tester.tapAt(rect.center);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(button),
          isSemantics(
            label: 'Nueva playlist',
            isButton: true,
            hasTapAction: true,
          ),
        );
        handle.dispose();
      });

      testWidgets('si falla al crear avisa y no navega', (tester) async {
        await openPlaylistsTab(tester);
        playlists.failCreate = true;

        await tester.tap(find.text('Nueva playlist'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Rota');
        await tester.pump();
        await tester.tap(find.text('Crear'));
        await tester.pumpAndSettle();

        expect(find.text('No se pudo crear la playlist'), findsOneWidget);
        expect(find.byType(PlaylistDetailPage), findsNothing);
        expect(playlists.namesInOrder(), isEmpty);
      });

      testWidgets('Cancelar no crea nada', (tester) async {
        await openPlaylistsTab(tester);

        await tester.tap(find.text('Nueva playlist'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();

        expect(playlists.namesInOrder(), isEmpty);
        expect(find.byType(PlaylistDetailPage), findsNothing);
      });
    });

    group('estados', () {
      testWidgets('vacío: TakiEmptyState en línea, bajo "Nueva playlist" y '
          'sin repetir la acción', (tester) async {
        await openPlaylistsTab(tester);

        final state =
            tester.widget<TakiEmptyState>(find.byType(TakiEmptyState));
        expect(state.kind, TakiEmptyStateKind.firstUse);
        expect(state.icon, Icons.queue_music_rounded);
        expect(state.action, isNull);
        expect(state.secondaryAction, isNull);
        expect(find.text('Nueva playlist'), findsOneWidget);
        expect(find.byType(TakiButton), findsOneWidget);
        expect(
          tester.getTopLeft(find.byType(TakiEmptyState)).dy,
          greaterThanOrEqualTo(
            tester.getBottomLeft(find.byType(TakiButton)).dy,
          ),
        );
        expect(find.byType(TakiSectionHeader), findsNothing);
      });

      testWidgets('con datos: "TUS PLAYLISTS" es un TakiSectionHeader de grupo',
          (tester) async {
        final handle = tester.ensureSemantics();
        playlists.seed('Una');
        await openPlaylistsTab(tester);

        final header =
            tester.widget<TakiSectionHeader>(find.byType(TakiSectionHeader));
        expect(header.variant, TakiSectionHeaderVariant.group);
        expect(find.text('TUS PLAYLISTS'), findsOneWidget);
        expect(
          tester.getSemantics(find.bySemanticsLabel('Tus playlists')),
          isSemantics(isHeader: true),
        );
        expect(find.byType(TakiEmptyState), findsNothing);
        handle.dispose();
      });

      testWidgets('error: TakiErrorState de error, sin pull-to-refresh; '
          'Reintentar usa retryPlaylists', (tester) async {
        playlists
          ..seed('Guardada')
          ..failing = true;
        await openPlaylistsTab(tester);

        final state =
            tester.widget<TakiErrorState>(find.byType(TakiErrorState));
        expect(state.kind, TakiErrorStateKind.error);
        expect(state.title, 'Playlists no disponibles');
        expect(state.action!.label, 'Reintentar');
        expect(find.byType(RefreshIndicator), findsNothing);
        expect(
          tester.getSize(find.widgetWithText(TakiButton, 'Reintentar')).height,
          greaterThanOrEqualTo(48),
        );

        playlists.failing = false;
        await tester.tap(find.widgetWithText(TakiButton, 'Reintentar'));
        await tester.pumpAndSettle();
        expect(cardOf(tester, 'Guardada').title, 'Guardada');
      });

      testWidgets('sin permiso de música no hay estado propio: lista igual',
          (tester) async {
        playlists.seed('Guardada', songs: [a]);
        final permission = MockMediaPermission();
        when(permission.isGranted).thenAnswer((_) async => false);
        when(permission.isPermanentlyDenied).thenAnswer((_) async => false);
        final songs = MockSongRepository();
        await tester.pumpWidget(
          ProviderScope(
            overrides: libraryOverrides(
              permission: permission,
              songs: songs,
              playlists: playlists,
            ),
            child: const TakiApp(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Playlists'),
        ));
        await tester.pumpAndSettle();

        expect(cardOf(tester, 'Guardada').subtitle, '1 canción · 2 min');
        // Sin biblioteca no hay carátulas: una pieza sin imagen.
        expect(coverOf(tester, 'Guardada').mosaic, [null]);
      });

      testWidgets('al recalcular con datos no muestra el spinner',
          (tester) async {
        playlists.seed('Una');
        await openPlaylistsTab(tester);

        playlists.gate = Completer<void>();
        containerOf(tester).invalidate(playlistsProvider);
        await tester.pump();
        await tester.pump();

        expect(containerOf(tester).read(playlistsProvider).isLoading, isTrue);
        expect(loadingSpinner(), findsNothing);
        expect(find.text('Una'), findsOneWidget);

        playlists.gate!.complete();
        await tester.pumpAndSettle();
        expect(containerOf(tester).read(playlistsProvider).isLoading, isFalse);
        expect(find.text('Una'), findsOneWidget);
      });

      testWidgets('carga inicial: spinner', (tester) async {
        playlists
          ..seed('Una')
          ..gate = Completer<void>();
        await openPlaylistsTab(tester, settle: false);

        expect(loadingSpinner(), findsOneWidget);
        playlists.gate!.complete();
        await tester.pumpAndSettle();
        expect(loadingSpinner(), findsNothing);
        expect(find.text('Una'), findsOneWidget);
      });
    });

    testWidgets('semántica: botón con título y resumen, pulsación larga con '
        'la pista "Renombrar o eliminar"', (tester) async {
      final handle = tester.ensureSemantics();
      playlists.seed('Con canciones', songs: [a, b]);
      await openPlaylistsTab(tester);

      expect(
        tester.getSemantics(cardFinder('Con canciones')),
        isSemantics(
          label: 'Con canciones, 2 canciones · 5 min',
          isButton: true,
          hasTapAction: true,
          hasLongPressAction: true,
          onLongPressHint: 'Renombrar o eliminar',
        ),
      );
      expect(
        tester.getSize(cardFinder('Con canciones')).height,
        greaterThanOrEqualTo(TakiPlaylistCard.minHeight),
      );
      handle.dispose();
    });

    testWidgets('con cientos de playlists solo construye las visibles',
        (tester) async {
      for (var i = 0; i < 400; i++) {
        playlists.seed('P${i.toString().padLeft(3, '0')}');
      }
      await openPlaylistsTab(tester);

      // La más reciente arriba; la más antigua no se construye.
      expect(find.text('P399'), findsOneWidget);
      expect(find.text('P000'), findsNothing);
      expect(find.byType(TakiPlaylistCard).evaluate().length, lessThan(20));
    });

    group('pantallas', () {
      const longName = 'Una playlist con un nombre larguísimo que no cabe '
          'de ninguna manera';

      // Texto al 150 % solo a 412: a 360, con la fuente de pruebas (cada letra
      // tan ancha como alta) "Nueva playlist" no cabe en TakiButton (gap de
      // core documentado en 1.7A). Con las fuentes reales cabe (validación
      // visual).
      for (final (name, size, scale) in [
        ('360x800', const Size(360, 800), 1.0),
        ('412x915', const Size(412, 915), 1.0),
        ('412x915 con texto al 150 %', const Size(412, 915), 1.5),
      ]) {
        testWidgets('$name: sin desbordes; nombre y resumen largos',
            (tester) async {
          // 100 canciones de 1 h: resumen largo.
          final many = [
            for (var i = 0; i < 100; i++)
              buildSong(id: 100 + i, title: 'L$i', durationMs: 3600000),
          ];
          playlists
            ..seed('Vacía')
            ..seed(longName, songs: many);
          await openPlaylistsTab(
            tester,
            songs: many,
            size: size,
            textScale: scale,
          );

          expect(tester.takeException(), isNull);
          final card = tester.getRect(cardFinder(longName));
          expect(card.height, greaterThanOrEqualTo(TakiPlaylistCard.minHeight));
          expect(card.right, lessThanOrEqualTo(size.width));
          for (final text in [longName, '100 canciones · 100 h 00 min']) {
            final rect = tester.getRect(find.text(text));
            expect(rect.right, lessThanOrEqualTo(size.width), reason: text);
            expect(rect.bottom, lessThanOrEqualTo(card.bottom), reason: text);
          }
          final button =
              tester.getRect(find.widgetWithText(TakiButton, 'Nueva playlist'));
          expect(button.height, greaterThanOrEqualTo(48));
          expect(button.right, lessThanOrEqualTo(size.width));
        });
      }

      for (final (name, size, scale) in [
        ('vacío a 360x800', const Size(360, 800), 1.0),
        ('vacío a 412x915 con texto al 150 %', const Size(412, 915), 1.5),
        ('vacío a 412x915', const Size(412, 915), 1.0),
      ]) {
        testWidgets('$name sin desbordes', (tester) async {
          await openPlaylistsTab(tester, size: size, textScale: scale);
          expect(tester.takeException(), isNull);
          expect(find.byType(TakiEmptyState), findsOneWidget);
        });
      }

      // A escala 1: con la fuente de pruebas el texto de TakiButton no cabe
      // al 150 % (gap de core documentado en 1.7A).
      for (final size in [const Size(360, 800), const Size(412, 915)]) {
        testWidgets('error a ${size.width.toInt()} sin desbordes',
            (tester) async {
          playlists.failing = true;
          await openPlaylistsTab(tester, size: size);
          expect(find.byType(TakiErrorState), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    });
  });
}

/// [FakePlaylistsRepository] cuyo stream puede quedar retenido con [gate] y
/// cuya creación puede fallar sola con [failCreate].
class _GatedPlaylistsRepository extends FakePlaylistsRepository {
  Completer<void>? gate;
  bool failCreate = false;

  @override
  Stream<List<Playlist>> watchPlaylists() async* {
    final gate = this.gate;
    if (gate != null) await gate.future;
    yield* super.watchPlaylists();
  }

  @override
  Future<int> create(String name) async {
    if (failCreate) throw StateError('Base no disponible');
    return super.create(name);
  }
}

/// Carátulas de prueba: bytes con el álbum pedido; cuenta las peticiones.
class _BytesArtworkRepository implements ArtworkRepository {
  final requests = <(int, int)>[];

  @override
  Future<Uint8List?> getAlbumArtwork(int albumId, {required int size}) async {
    requests.add((albumId, size));
    return Uint8List.fromList([albumId, size]);
  }
}
