import 'dart:typed_data';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taki/app/theme/app_theme.dart';
import 'package:taki/core/artwork/artwork_providers.dart';
import 'package:taki/core/domain/ports/artwork_repository.dart';
import 'package:taki/core/theme/taki_colors.dart';
import 'package:taki/core/theme/taki_typography.dart';
import 'package:taki/core/widgets/taki_artwork.dart';
import 'package:taki/core/widgets/taki_button.dart';
import 'package:taki/core/widgets/taki_icon_button.dart';
import 'package:taki/core/widgets/taki_playing_indicator.dart';
import 'package:taki/core/widgets/taki_section_header.dart';
import 'package:taki/core/widgets/taki_song_tile.dart';
import 'package:taki/features/player/domain/entities/playback_state.dart';
import 'package:taki/features/player/presentation/pages/queue_page.dart';
import 'package:taki/features/player/presentation/providers/player_providers.dart';

import '../../../helpers/library_fakes.dart';
import '../../../helpers/player_fakes.dart';

/// Carátulas de prueba: bytes distintos por álbum; cuenta las peticiones.
class _BytesArtworkRepository implements ArtworkRepository {
  final requests = <(int, int)>[];

  @override
  Future<Uint8List?> getAlbumArtwork(int albumId, {required int size}) async {
    requests.add((albumId, size));
    return Uint8List.fromList([albumId, size]);
  }
}

void main() {
  late FakeAudioPlayerPort player;

  // Cola A B C D, sonando B (índice 1): "A continuación" = C (2) y D (3).
  final a = buildSong(id: 1, title: 'A', durationMs: 60000);
  final b = buildSong(id: 2, title: 'B', artist: 'Artista B');
  final c = buildSong(id: 3, title: 'C', durationMs: 120000, albumId: 30);
  final d = buildSong(id: 4, title: 'D', durationMs: 180000, albumId: 40);

  setUp(() => player = FakeAudioPlayerPort());

  Future<void> pumpQueue(
    WidgetTester tester, {
    PlaybackState? state,
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
    player.emitState(
      state ?? PlaybackState(queue: [a, b, c, d], currentIndex: 1),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioPlayerPortProvider.overrideWithValue(player),
          artworkRepositoryProvider.overrideWithValue(NoArtworkRepository()),
          ...overrides,
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: const QueuePage(),
        ),
      ),
    );
    // Sonando, las barras se animan sin fin: pump en vez de pumpAndSettle.
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
    }
  }

  Finder row(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(TakiSongTile));

  TakiSongTile tileOf(WidgetTester tester, String title) =>
      tester.widget<TakiSongTile>(row(title));

  Finder removeButtonOf(String title) => find.descendant(
        of: row(title),
        matching: find.byTooltip('Quitar de la cola'),
      );

  Finder clearButton() => find.widgetWithText(TakiButton, 'Limpiar');

  testWidgets('muestra "Sonando ahora" y solo lo que viene después',
      (tester) async {
    await pumpQueue(tester);

    expect(find.text('SONANDO AHORA'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('Artista B'), findsOneWidget);
    expect(find.text('A CONTINUACIÓN'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    expect(find.text('D'), findsOneWidget);
    expect(find.text('A'), findsNothing, reason: 'ya se reprodujo');
    expect(find.text('2 canciones · 5 min'), findsOneWidget);
  });

  testWidgets('la canción actual usa el color de acento', (tester) async {
    await pumpQueue(tester);

    final title = tester.widget<Text>(find.text('B'));
    final accent =
        Theme.of(tester.element(find.text('B'))).colorScheme.primary;
    expect(title.style?.color, accent);
  });

  group('Design System (Fase 1.6D)', () {
    testWidgets('cada canción es una TakiSongTile', (tester) async {
      await pumpQueue(tester);

      // B (actual) + C y D (a continuación).
      expect(find.byType(TakiSongTile), findsNWidgets(3));
      for (final title in ['B', 'C', 'D']) {
        expect(row(title), findsOneWidget, reason: title);
        expect(tileOf(tester, title).showDuration, isFalse, reason: title);
      }
    });

    testWidgets('la actual: estado sonando, barras y no solo color',
        (tester) async {
      await pumpQueue(
        tester,
        state: PlaybackState(queue: [a, b, c, d], currentIndex: 1, isPlaying: true),
        settle: false,
      );

      expect(tileOf(tester, 'B').playback, TakiNowPlaying.playing);
      expect(tileOf(tester, 'C').playback, TakiNowPlaying.none);
      expect(tileOf(tester, 'D').playback, TakiNowPlaying.none);
      final bars = find.descendant(
        of: row('B'),
        matching: find.byType(TakiPlayingIndicator),
      );
      expect(bars, findsOneWidget);
      expect(tester.widget<TakiPlayingIndicator>(bars).animate, isTrue);
      // Ninguna otra fila lleva barras.
      expect(find.byType(TakiPlayingIndicator), findsOneWidget);
    });

    testWidgets('en pausa: la actual queda marcada con barras quietas',
        (tester) async {
      await pumpQueue(tester);

      expect(tileOf(tester, 'B').playback, TakiNowPlaying.paused);
      expect(
        tester
            .widget<TakiPlayingIndicator>(find.byType(TakiPlayingIndicator))
            .animate,
        isFalse,
      );
    });

    testWidgets('semántica: la actual anuncia "Reproduciendo"',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpQueue(
        tester,
        state: PlaybackState(queue: [a, b, c, d], currentIndex: 1, isPlaying: true),
        settle: false,
      );

      expect(
        tester.getSemantics(row('B')),
        isSemantics(value: TakiSongTile.playingLabel),
      );
      expect(
        tester.getSemantics(row('D')),
        isSemantics(isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('cabeceras de grupo, título titleLarge y resumen caption',
        (tester) async {
      await pumpQueue(tester);

      final headers = tester
          .widgetList<TakiSectionHeader>(find.byType(TakiSectionHeader))
          .toList();
      expect(headers.map((h) => h.title), ['Sonando ahora', 'A continuación']);
      expect(
        headers.map((h) => h.variant),
        everyElement(TakiSectionHeaderVariant.group),
      );

      final title = tester.widget<Text>(find.text('Cola')).style!;
      expect(title.fontFamily, TakiTypography.titleLarge.fontFamily);
      expect(title.fontSize, TakiTypography.titleLarge.fontSize);
      expect(title.color, TakiColors.textPrimary);

      final summary =
          tester.widget<Text>(find.text('2 canciones · 5 min')).style!;
      expect(summary.fontSize, TakiTypography.caption.fontSize);
      expect(summary.color, TakiColors.textMuted);
    });

    testWidgets('carátulas desde ArtworkCache (bytes → MemoryImage) a 48',
        (tester) async {
      final artwork = _BytesArtworkRepository();
      await pumpQueue(
        tester,
        overrides: [artworkRepositoryProvider.overrideWithValue(artwork)],
      );

      for (final (title, albumId) in [('B', 10), ('C', 30), ('D', 40)]) {
        final art = tester.widget<TakiArtwork>(
          find.descendant(of: row(title), matching: find.byType(TakiArtwork)),
        );
        expect(art.size, TakiSongTile.artworkSize, reason: title);
        final image = art.image! as MemoryImage;
        expect(image.bytes.first, albumId, reason: title);
      }
      // Una petición por álbum y tamaño (la caché deduplica).
      expect(artwork.requests.toSet().length, artwork.requests.length);
    });

    testWidgets('sin carátula: placeholder de TakiArtwork', (tester) async {
      await pumpQueue(tester);

      final art = tester.widget<TakiArtwork>(
        find.descendant(of: row('C'), matching: find.byType(TakiArtwork)),
      );
      expect(art.image, isNull);
    });

    testWidgets('cerrar vuelve a la pantalla anterior', (tester) async {
      player.emitState(PlaybackState(queue: [a, b, c, d], currentIndex: 1));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioPlayerPortProvider.overrideWithValue(player),
            artworkRepositoryProvider.overrideWithValue(NoArtworkRepository()),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const QueuePage()),
                  ),
                  child: const Text('Base'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Base'));
      await tester.pumpAndSettle();
      expect(find.byType(QueuePage), findsOneWidget);

      await tester.tap(find.byTooltip('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.byType(QueuePage), findsNothing);
    });

    testWidgets('cerrar, quitar y Limpiar son componentes Taki',
        (tester) async {
      await pumpQueue(tester);

      final close = tester.widget<TakiIconButton>(
        find.ancestor(
          of: find.byIcon(Icons.keyboard_arrow_down_rounded),
          matching: find.byType(TakiIconButton),
        ),
      );
      expect(close.variant, TakiIconButtonVariant.tonal);
      expect(
        tester.widget<TakiButton>(clearButton()).variant,
        TakiButtonVariant.tertiary,
      );
      final remove = tester.widget<TakiIconButton>(
        find.ancestor(
          of: removeButtonOf('C'),
          matching: find.byType(TakiIconButton),
        ),
      );
      expect(remove.variant, TakiIconButtonVariant.subtle);
    });
  });

  testWidgets('quitar llama a RemoveFromQueue con el índice de la cola real',
      (tester) async {
    final remove = MockRemoveFromQueue();
    when(() => remove(any())).thenAnswer((_) async {});
    await pumpQueue(
      tester,
      overrides: [removeFromQueueProvider.overrideWithValue(remove)],
    );

    await tester.tap(removeButtonOf('D'));
    await tester.pump();

    verify(() => remove(3)).called(1);
    expect(find.text('Quitada de la cola'), findsOneWidget);
  });

  testWidgets('Deshacer vuelve a poner la canción en su sitio', (tester) async {
    await pumpQueue(tester);

    await tester.tap(removeButtonOf('C'));
    await tester.pumpAndSettle();
    expect(player.state.queue, [a, b, d]);

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();

    expect(player.state.queue, [a, b, c, d]);
    expect(find.text('C'), findsOneWidget);
  });

  testWidgets('reordenar traduce los índices a los de la cola real',
      (tester) async {
    final move = MockMoveInQueue();
    when(() => move(any(), any())).thenAnswer((_) async {});
    await pumpQueue(
      tester,
      overrides: [moveInQueueProvider.overrideWithValue(move)],
    );

    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    // Flutter informa el destino antes de quitar el elemento: C (fila 0)
    // soltada después de D (fila 1) llega como (0, 2).
    list.onReorder(0, 2);
    // D (fila 1) soltada antes de C (fila 0).
    list.onReorder(1, 0);

    verifyInOrder([() => move(2, 3), () => move(3, 2)]);
  });

  testWidgets('se reordena arrastrando el asa', (tester) async {
    await pumpQueue(tester);

    final handle = find.descendant(
      of: row('C'),
      matching: find.byIcon(Icons.drag_handle_rounded),
    );
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 100));
    // Movimiento progresivo, como un dedo real, hasta pasar la fila de D.
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(0, 12));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(player.state.queue, [a, b, d, c]);
  });

  testWidgets('tocar una fila salta a esa canción', (tester) async {
    await pumpQueue(tester);

    await tester.tap(find.text('D'));
    await tester.pumpAndSettle();

    expect(player.calls, contains('skipToIndex(3)'));
  });

  testWidgets('tocar la canción actual no hace nada (como antes)',
      (tester) async {
    await pumpQueue(tester);

    expect(tileOf(tester, 'B').onTap, isNull);
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    expect(player.calls, isEmpty);
  });

  testWidgets('Limpiar pide confirmación', (tester) async {
    final clear = MockClearUpcoming();
    when(() => clear()).thenAnswer((_) async {});
    await pumpQueue(
      tester,
      overrides: [clearUpcomingProvider.overrideWithValue(clear)],
    );

    await tester.tap(clearButton());
    await tester.pumpAndSettle();
    expect(find.text('¿Limpiar la cola?'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    verifyNever(() => clear());

    await tester.tap(clearButton());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Limpiar').last);
    await tester.pumpAndSettle();
    verify(() => clear()).called(1);
  });

  testWidgets('sin nada por venir: mensaje y Limpiar deshabilitado',
      (tester) async {
    await pumpQueue(
      tester,
      state: PlaybackState(queue: [a, b], currentIndex: 1),
    );

    expect(find.text('No hay más canciones en la cola'), findsOneWidget);
    expect(tester.widget<TakiButton>(clearButton()).onPressed, isNull);
    expect(find.text('A CONTINUACIÓN'), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'^\d+ canci')),
      findsNothing,
      reason: 'sin resumen',
    );
  });

  testWidgets('sin canción actual: mensaje en "Sonando ahora"',
      (tester) async {
    await pumpQueue(tester, state: PlaybackState.empty);

    expect(find.text('No está sonando nada'), findsOneWidget);
    expect(find.text('No hay más canciones en la cola'), findsOneWidget);
    expect(find.byType(TakiSongTile), findsNothing);
    final message = tester.widget<Text>(find.text('No está sonando nada'));
    expect(message.style!.fontSize, TakiTypography.body.fontSize);
    expect(message.style!.color, TakiColors.textSecondary);
  });

  testWidgets('se actualiza sola al cambiar de canción', (tester) async {
    await pumpQueue(tester);

    player.emitState(PlaybackState(queue: [a, b, c, d], currentIndex: 2));
    await tester.pumpAndSettle();

    expect(find.text('B'), findsNothing);
    expect(find.text('1 canción · 3 min'), findsOneWidget);
    expect(tileOf(tester, 'C').playback, TakiNowPlaying.paused);
  });

  testWidgets('botones con tooltip en español y áreas de 48', (tester) async {
    await pumpQueue(tester);

    expect(find.byTooltip('Cerrar'), findsOneWidget);
    expect(find.byTooltip('Quitar de la cola'), findsNWidgets(2));
    expect(find.byTooltip('Arrastrar para reordenar'), findsNWidgets(2));
    for (final finder in [
      find.byTooltip('Cerrar'),
      find.byTooltip('Quitar de la cola').first,
      find.byTooltip('Arrastrar para reordenar').first,
      clearButton(),
    ]) {
      final size = tester.getSize(finder);
      expect(size.width, greaterThanOrEqualTo(48), reason: '$finder');
      expect(size.height, greaterThanOrEqualTo(48), reason: '$finder');
    }
    expect(tester.getSize(row('C')).height, greaterThanOrEqualTo(64));
  });

  testWidgets('con miles de canciones solo construye las visibles',
      (tester) async {
    final many = [for (var i = 0; i < 5000; i++) buildSong(id: i, title: 'S$i')];
    await pumpQueue(
      tester,
      state: PlaybackState(queue: many, currentIndex: 0),
    );

    expect(find.text('4999 canciones · 249 h 57 min'), findsOneWidget);
    expect(find.text('S1'), findsOneWidget);
    expect(find.text('S4999'), findsNothing);
    expect(
      find.byTooltip('Quitar de la cola').evaluate().length,
      lessThan(30),
    );
  });

  group('pantallas', () {
    final long = buildSong(
      id: 9,
      title: 'Un título larguísimo que no cabe en una sola línea de la cola',
      artist: 'Un artista con un nombre también bastante largo',
    );

    for (final (name, size, scale) in [
      ('móvil 360x800', const Size(360, 800), 1.0),
      ('móvil 412x915', const Size(412, 915), 1.0),
      ('360x800 con texto grande (1.5)', const Size(360, 800), 1.5),
    ]) {
      testWidgets('$name: sin desbordes', (tester) async {
        await pumpQueue(
          tester,
          size: size,
          textScale: scale,
          state: PlaybackState(queue: [a, long, c, long, d], currentIndex: 1),
        );

        expect(tester.takeException(), isNull);
        // Las filas crecen con el texto en lugar de recortarse.
        final rowHeight = tester.getSize(row('C')).height;
        expect(rowHeight, greaterThanOrEqualTo(64));
        final title = tester.getRect(find.text('C'));
        expect(title.bottom, lessThanOrEqualTo(tester.getRect(row('C')).bottom));
      });
    }
  });
}
