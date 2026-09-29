import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/theme/taki_colors.dart';
import 'package:taki/core/widgets/taki_button.dart';
import 'package:taki/core/widgets/taki_empty_state.dart';
import 'package:taki/core/widgets/taki_error_state.dart';
import 'package:taki/core/widgets/taki_state_view.dart';

Future<void> _pump(WidgetTester tester, Widget child) =>
    tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));

Color? _circle(WidgetTester tester) {
  final circles = find.byWidgetPredicate(
    (w) =>
        w is Container &&
        w.decoration is ShapeDecoration &&
        (w.decoration as ShapeDecoration).shape is CircleBorder,
  );
  if (circles.evaluate().isEmpty) return null;
  return (tester.widget<Container>(circles).decoration as ShapeDecoration)
      .color;
}

TakiButton _button(WidgetTester tester, String label) => tester.widget<TakiButton>(
      find.ancestor(of: find.text(label), matching: find.byType(TakiButton)),
    );

void main() {
  group('TakiEmptyState', () {
    testWidgets('primer uso: icono en círculo, título, texto y CTA primario',
        (tester) async {
      var created = 0;
      await _pump(
        tester,
        TakiEmptyState(
          icon: Icons.queue_music_rounded,
          title: 'Aún no tienes playlists',
          description: 'Crea la primera para agrupar tus canciones.',
          action: TakiStateAction(
            label: 'Nueva playlist',
            onPressed: () => created++,
          ),
        ),
      );

      expect(find.byIcon(Icons.queue_music_rounded), findsOneWidget);
      expect(_circle(tester), TakiColors.surface);
      expect(find.text('Aún no tienes playlists'), findsOneWidget);
      expect(
        find.text('Crea la primera para agrupar tus canciones.'),
        findsOneWidget,
      );
      expect(_button(tester, 'Nueva playlist').variant, TakiButtonVariant.primary);

      await tester.tap(find.text('Nueva playlist'));
      expect(created, 1);
    });

    testWidgets('acción secundaria terciaria debajo', (tester) async {
      var secondary = 0;
      await _pump(
        tester,
        TakiEmptyState(
          icon: Icons.music_off_rounded,
          title: 'No encontramos canciones',
          action: TakiStateAction(label: 'Reintentar', onPressed: () {}),
          secondaryAction: TakiStateAction(
            label: 'Cómo añadir música',
            onPressed: () => secondary++,
          ),
        ),
      );

      expect(
        _button(tester, 'Cómo añadir música').variant,
        TakiButtonVariant.tertiary,
      );
      expect(
        tester.getTopLeft(find.text('Cómo añadir música')).dy,
        greaterThan(tester.getTopLeft(find.text('Reintentar')).dy),
      );
      await tester.tap(find.text('Cómo añadir música'));
      expect(secondary, 1);
    });

    testWidgets('sin resultados: sin círculo, arriba y acción ligera',
        (tester) async {
      await _pump(
        tester,
        TakiEmptyState(
          kind: TakiEmptyStateKind.noResults,
          icon: Icons.search_off_rounded,
          title: 'Sin resultados para «xyz»',
          action: TakiStateAction(label: 'Limpiar búsqueda', onPressed: () {}),
        ),
      );

      expect(_circle(tester), isNull);
      expect(
        _button(tester, 'Limpiar búsqueda').variant,
        TakiButtonVariant.tertiary,
      );
      // Arriba, no centrado en la pantalla.
      expect(
        tester.getTopLeft(find.byIcon(Icons.search_off_rounded)).dy,
        lessThan(tester.getSize(find.byType(Scaffold)).height / 4),
      );
    });

    testWidgets('una ilustración puede sustituir al icono', (tester) async {
      await _pump(
        tester,
        const TakiEmptyState(
          icon: Icons.favorite_border_rounded,
          title: 'Sin favoritos',
          illustration: SizedBox(key: Key('ilustración'), width: 80, height: 80),
        ),
      );
      expect(find.byKey(const Key('ilustración')), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
    });

    testWidgets('el título se anuncia como encabezado', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const TakiEmptyState(icon: Icons.favorite_border_rounded, title: 'Sin favoritos'),
      );
      expect(
        tester.getSemantics(find.text('Sin favoritos')),
        isSemantics(label: 'Sin favoritos', isHeader: true),
      );
      handle.dispose();
    });

    testWidgets('funciona dentro de una lista (alto sin límite)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(children: const [
            TakiEmptyState(icon: Icons.music_off_rounded, title: 'Vacío'),
          ]),
        ),
      ));
      expect(tester.takeException(), isNull);
      expect(find.text('Vacío'), findsOneWidget);
    });
  });

  group('TakiErrorState', () {
    testWidgets('error: icono de error sobre errorContainer, no solo color',
        (tester) async {
      await _pump(
        tester,
        const TakiErrorState(
          title: 'No pudimos leer tu música',
          message: 'Ocurrió un error al escanear el teléfono.',
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline_rounded));
      expect(icon.color, TakiColors.error);
      expect(_circle(tester), TakiColors.errorContainer);
      expect(find.text('Ocurrió un error al escanear el teléfono.'), findsOneWidget);
    });

    testWidgets('reintentar y acción secundaria', (tester) async {
      final calls = <String>[];
      await _pump(
        tester,
        TakiErrorState(
          title: 'Playlists no disponibles',
          message: 'No pudimos leer tus playlists guardadas.',
          action: TakiStateAction(
            label: 'Reintentar',
            onPressed: () => calls.add('retry'),
          ),
          secondaryAction: TakiStateAction(
            label: 'Ver detalles',
            onPressed: () => calls.add('details'),
          ),
        ),
      );

      expect(_button(tester, 'Reintentar').variant, TakiButtonVariant.primary);
      expect(_button(tester, 'Ver detalles').variant, TakiButtonVariant.tertiary);
      await tester.tap(find.text('Reintentar'));
      await tester.tap(find.text('Ver detalles'));
      expect(calls, ['retry', 'details']);
    });

    testWidgets('permiso: no parece un fallo (icono neutro sobre surface)',
        (tester) async {
      await _pump(
        tester,
        TakiErrorState(
          kind: TakiErrorStateKind.permission,
          title: 'Taki necesita acceso a tu música',
          message: 'Solo leemos las canciones guardadas en tu teléfono.',
          action: TakiStateAction(label: 'Permitir acceso', onPressed: () {}),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.lock_outline_rounded));
      expect(icon.color, TakiColors.iconPrimary);
      expect(_circle(tester), TakiColors.surface);
      expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
    });

    testWidgets('icono propio', (tester) async {
      await _pump(
        tester,
        const TakiErrorState(
          icon: Icons.cloud_off_rounded,
          title: 'Sin conexión',
          message: 'No pudimos cargar el catálogo.',
        ),
      );
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });

    testWidgets('el título es encabezado y el mensaje se lee', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        TakiErrorState(
          title: 'No pudimos leer tu música',
          message: 'Ocurrió un error al escanear el teléfono.',
          action: TakiStateAction(label: 'Reintentar', onPressed: () {}),
        ),
      );

      expect(
        tester.getSemantics(find.text('No pudimos leer tu música')),
        isSemantics(isHeader: true),
      );
      expect(
        find.bySemanticsLabel('Ocurrió un error al escanear el teléfono.'),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Reintentar')),
        isSemantics(isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });
  });

  testWidgets('estado vacío y de error comparten estructura', (tester) async {
    await _pump(
      tester,
      const TakiErrorState(title: 'Error', message: 'Mensaje'),
    );
    expect(find.byType(TakiStateView), findsOneWidget);

    await _pump(
      tester,
      const TakiEmptyState(icon: Icons.music_off_rounded, title: 'Vacío'),
    );
    expect(find.byType(TakiStateView), findsOneWidget);
  });
}
