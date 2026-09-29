import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taki/app/theme/app_theme.dart';
import 'package:taki/core/artwork/artwork_providers.dart';
import 'package:taki/features/player/domain/entities/playback_state.dart';
import 'package:taki/features/player/presentation/pages/queue_page.dart';
import 'package:taki/features/player/presentation/providers/player_providers.dart';

import '../../../helpers/library_fakes.dart';
import '../../../helpers/player_fakes.dart';

void main() {
  late FakeAudioPlayerPort player;

  // Cola A B C D, sonando B (índice 1): "A continuación" = C (2) y D (3).
  final a = buildSong(id: 1, title: 'A', durationMs: 60000);
  final b = buildSong(id: 2, title: 'B', artist: 'Artista B');
  final c = buildSong(id: 3, title: 'C', durationMs: 120000);
  final d = buildSong(id: 4, title: 'D', durationMs: 180000);

  setUp(() => player = FakeAudioPlayerPort());

  Future<void> pumpQueue(
    WidgetTester tester, {
    PlaybackState? state,
    List<Override> overrides = const [],
  }) async {
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
        child: MaterialApp(theme: AppTheme.dark(), home: const QueuePage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder row(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(InkWell)).first;

  Finder removeButtonOf(String title) => find.descendant(
        of: row(title),
        matching: find.byTooltip('Quitar de la cola'),
      );

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

  testWidgets('Limpiar pide confirmación', (tester) async {
    final clear = MockClearUpcoming();
    when(() => clear()).thenAnswer((_) async {});
    await pumpQueue(
      tester,
      overrides: [clearUpcomingProvider.overrideWithValue(clear)],
    );

    await tester.tap(find.text('Limpiar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Limpiar la cola?'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    verifyNever(() => clear());

    await tester.tap(find.text('Limpiar'));
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
    final clear = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Limpiar'),
    );
    expect(clear.onPressed, isNull);
  });

  testWidgets('se actualiza sola al cambiar de canción', (tester) async {
    await pumpQueue(tester);

    player.emitState(PlaybackState(queue: [a, b, c, d], currentIndex: 2));
    await tester.pumpAndSettle();

    expect(find.text('B'), findsNothing);
    expect(find.text('1 canción · 3 min'), findsOneWidget);
  });

  testWidgets('botones con tooltip en español y áreas de 48', (tester) async {
    await pumpQueue(tester);

    expect(find.byTooltip('Cerrar'), findsOneWidget);
    expect(find.byTooltip('Quitar de la cola'), findsNWidgets(2));
    expect(find.byTooltip('Arrastrar para reordenar'), findsNWidgets(2));
    final handleSize = tester.getSize(
      find.byTooltip('Arrastrar para reordenar').first,
    );
    expect(handleSize.width, greaterThanOrEqualTo(48));
    expect(
      tester.getSize(find.widgetWithText(TextButton, 'Limpiar')).height,
      greaterThanOrEqualTo(48),
    );
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
}
