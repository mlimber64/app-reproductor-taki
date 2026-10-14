import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taki/app/theme/app_theme.dart';
import 'package:taki/core/theme/taki_colors.dart';
import 'package:taki/core/widgets/taki_icon_button.dart';
import 'package:taki/core/widgets/taki_search_field.dart';

void main() {
  late TextEditingController controller;
  late FocusNode focus;
  late List<String> changes;
  late List<String> submits;

  setUp(() {
    controller = TextEditingController();
    focus = FocusNode();
    changes = [];
    submits = [];
  });

  tearDown(() {
    focus.dispose();
    controller.dispose();
  });

  Future<void> pumpField(
    WidgetTester tester, {
    bool enabled = true,
    String hint = 'Buscar canciones',
    TextEditingController? override,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: TakiSearchField(
              controller: override ?? controller,
              focusNode: focus,
              hintText: hint,
              enabled: enabled,
              onChanged: changes.add,
              onSubmitted: submits.add,
            ),
          ),
        ),
      ),
    );
  }

  ShapeDecoration decoration(WidgetTester tester) {
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(TakiSearchField),
        matching: find.byType(Container),
      ),
    );
    return container.decoration! as ShapeDecoration;
  }

  Finder clearButton() => find.byWidgetPredicate(
        (w) =>
            w is TakiIconButton &&
            w.semanticLabel == TakiSearchField.clearLabel,
      );

  testWidgets('muestra la lupa y la pista', (tester) async {
    await pumpField(tester);
    expect(find.text('Buscar canciones'), findsOneWidget);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(clearButton(), findsNothing);
  });

  testWidgets('la pista es configurable', (tester) async {
    await pumpField(tester, hint: 'Otra');
    expect(find.text('Otra'), findsOneWidget);
    expect(find.text('Buscar canciones'), findsNothing);
  });

  testWidgets('alto mínimo 48 y píldora sobre surface', (tester) async {
    await pumpField(tester);
    expect(tester.getSize(find.byType(TakiSearchField)).height,
        greaterThanOrEqualTo(TakiSearchField.minHeight));
    final shape = decoration(tester);
    expect(shape.color, TakiColors.surface);
    expect(shape.shape, isA<StadiumBorder>());
  });

  testWidgets('escribir avisa con onChanged y actualiza el controller',
      (tester) async {
    await pumpField(tester);
    await tester.enterText(find.byType(TextField), 'beat');
    expect(changes, ['beat']);
    expect(controller.text, 'beat');
  });

  testWidgets('enviar avisa con onSubmitted', (tester) async {
    await pumpField(tester);
    await tester.enterText(find.byType(TextField), 'beat');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    expect(submits, ['beat']);
  });

  testWidgets('la acción del teclado es «buscar»', (tester) async {
    await pumpField(tester);
    expect(tester.widget<TextField>(find.byType(TextField)).textInputAction,
        TextInputAction.search);
  });

  testWidgets('con texto aparece «Borrar búsqueda»', (tester) async {
    await pumpField(tester);
    await tester.enterText(find.byType(TextField), 'be');
    await tester.pump();
    expect(clearButton(), findsOneWidget);
    expect(find.byTooltip(TakiSearchField.clearLabel), findsOneWidget);
  });

  testWidgets('borrar vacía el campo, avisa con onChanged("") y deja el foco',
      (tester) async {
    await pumpField(tester);
    await tester.enterText(find.byType(TextField), 'beat');
    await tester.pump();
    focus.unfocus();
    await tester.pump();

    await tester.tap(clearButton());
    await tester.pump();

    expect(controller.text, isEmpty);
    expect(changes, ['beat', '']);
    expect(clearButton(), findsNothing);
    expect(focus.hasFocus, isTrue);
  });

  testWidgets('el botón sigue al texto cuando cambia el controller por fuera',
      (tester) async {
    await pumpField(tester);
    controller.text = 'x';
    await tester.pump();
    expect(clearButton(), findsOneWidget);
    controller.clear();
    await tester.pump();
    expect(clearButton(), findsNothing);
  });

  testWidgets('cambiar de controller reengancha el escucha', (tester) async {
    await pumpField(tester);
    final other = TextEditingController(text: 'otro');
    addTearDown(other.dispose);
    await pumpField(tester, override: other);
    expect(clearButton(), findsOneWidget);
    controller.text = 'ignorado';
    await tester.pump();
    other.clear();
    await tester.pump();
    expect(clearButton(), findsNothing);
  });

  testWidgets('foco: anillo primary al enfocar, invisible al salir',
      (tester) async {
    await pumpField(tester);
    ShapeDecoration shape() => decoration(tester);
    Color ring() => (shape().shape as StadiumBorder).side.color;

    expect(ring(), TakiColors.surface);
    focus.requestFocus();
    await tester.pump();
    expect(ring(), TakiColors.focusRing);
    // Mismo ancho enfocado o no: la fila no se mueve.
    expect((shape().shape as StadiumBorder).side.width, 2);

    focus.unfocus();
    await tester.pump();
    expect(ring(), TakiColors.surface);
    expect((shape().shape as StadiumBorder).side.width, 2);
  });

  testWidgets('deshabilitado: no edita, sin borrar y al 38 %', (tester) async {
    controller.text = 'algo';
    await pumpField(tester, enabled: false);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(clearButton(), findsNothing);
    final opacity = tester.widget<Opacity>(find.descendant(
      of: find.byType(TakiSearchField),
      matching: find.byType(Opacity),
    ));
    expect(opacity.opacity, TakiColors.disabledContentOpacity);
    // No muestra el anillo aunque se le pida el foco.
    focus.requestFocus();
    await tester.pump();
    expect((decoration(tester).shape as StadiumBorder).side.color,
        TakiColors.surface);
  });

  testWidgets('habilitado: opacidad completa', (tester) async {
    await pumpField(tester);
    final opacity = tester.widget<Opacity>(find.descendant(
      of: find.byType(TakiSearchField),
      matching: find.byType(Opacity),
    ));
    expect(opacity.opacity, 1);
  });

  testWidgets('semántica: etiqueta = pista, o la indicada', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpField(tester);
    expect(tester.getSemantics(find.byType(TakiSearchField)).label,
        contains('Buscar canciones'));

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: TakiSearchField(
          controller: controller,
          hintText: 'Pista',
          semanticLabel: 'Etiqueta propia',
        ),
      ),
    ));
    expect(tester.getSemantics(find.byType(TakiSearchField)).label,
        contains('Etiqueta propia'));
    handle.dispose();
  });

  testWidgets('al desmontarlo deja de escuchar al controller', (tester) async {
    await pumpField(tester);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    controller.text = 'tarde';
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('tras cambiar de controller, el viejo ya no se escucha',
      (tester) async {
    await pumpField(tester);
    final other = TextEditingController(text: 'otro');
    addTearDown(other.dispose);
    await pumpField(tester, override: other);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    controller.text = 'tarde';
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('el botón se llama «Borrar búsqueda»', (tester) async {
    await pumpField(tester);
    await tester.enterText(find.byType(TextField), 'a');
    await tester.pump();
    expect(find.byTooltip('Borrar búsqueda'), findsOneWidget);
  });

  testWidgets('con texto muy pequeño sigue midiendo 48 de alto',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(0.5)),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: TakiSearchField(controller: controller),
            ),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(TakiSearchField)).height, 48);
  });

  testWidgets('si se deshabilita con el foco puesto, el anillo desaparece',
      (tester) async {
    await pumpField(tester);
    focus.requestFocus();
    await tester.pump();
    expect((decoration(tester).shape as StadiumBorder).side.color,
        TakiColors.focusRing);
    await pumpField(tester, enabled: false);
    await tester.pump();
    expect((decoration(tester).shape as StadiumBorder).side.color,
        TakiColors.surface);
  });

  testWidgets('sin focusNode, borrar no falla', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: TakiSearchField(controller: controller, onChanged: changes.add),
      ),
    ));
    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pump();
    await tester.tap(clearButton());
    await tester.pump();
    expect(controller.text, isEmpty);
    expect(changes.last, '');
  });
}
