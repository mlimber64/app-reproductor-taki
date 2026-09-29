import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/theme/taki_colors.dart';
import 'package:taki/core/theme/taki_icon_size.dart';
import 'package:taki/core/widgets/taki_playback_controls.dart';

import 'widget_test_utils.dart';

TakiPlaybackControls _controls({
  bool isPlaying = false,
  bool isLoading = false,
  bool shuffle = false,
  TakiRepeatMode repeat = TakiRepeatMode.off,
  List<String>? calls,
  bool withCallbacks = true,
}) {
  VoidCallback? cb(String name) =>
      withCallbacks ? () => calls?.add(name) : null;
  return TakiPlaybackControls(
    isPlaying: isPlaying,
    isLoading: isLoading,
    isShuffleEnabled: shuffle,
    repeatMode: repeat,
    onPlayPause: cb('playPause'),
    onPrevious: cb('previous'),
    onNext: cb('next'),
    onShuffle: cb('shuffle'),
    onRepeat: cb('repeat'),
  );
}

Finder _control(String tooltip) => find.byTooltip(tooltip);

Icon _iconIn(WidgetTester tester, String tooltip) => tester.widget<Icon>(
      find.descendant(of: _control(tooltip), matching: find.byType(Icon)),
    );

/// Color del círculo detrás del icono de aleatorio o repetir.
Color? _toggleCircle(WidgetTester tester, String tooltip) {
  final container = tester.widget<AnimatedContainer>(find.descendant(
    of: _control(tooltip),
    matching: find.byType(AnimatedContainer),
  ));
  final color = (container.decoration! as ShapeDecoration).color;
  return color == Colors.transparent ? null : color;
}

void main() {
  group('play / pausa', () {
    testWidgets('círculo de 72, naranja, icono de 40', (tester) async {
      await pumpInScreen(tester, _controls());

      final play = find.byType(TakiPlayPauseButton);
      expect(tester.getSize(play), const Size.square(TakiPlayPauseButton.size));
      final circle = tester.widget<Container>(
        find.descendant(of: play, matching: find.byType(Container)),
      );
      expect((circle.decoration! as ShapeDecoration).color, TakiColors.primary);
      final icon = tester.widget<Icon>(find.byIcon(Icons.play_arrow_rounded));
      expect(icon.size, TakiIconSize.hero.value);
      expect(icon.color, TakiColors.onPrimary);
    });

    testWidgets('en pausa muestra play; sonando, pausa', (tester) async {
      await pumpInScreen(tester, _controls());
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(_control(TakiPlaybackControls.playLabel), findsOneWidget);

      await pumpInScreen(tester, _controls(isPlaying: true));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(_control(TakiPlaybackControls.pauseLabel), findsOneWidget);
    });

    testWidgets('pulsado: primaryPressed', (tester) async {
      await pumpInScreen(tester, _controls());
      final play = find.byType(TakiPlayPauseButton);
      final gesture = await tester.startGesture(tester.getCenter(play));
      await tester.pump(const Duration(milliseconds: 100));

      final circle = tester.widget<Container>(
        find.descendant(of: play, matching: find.byType(Container)),
      );
      expect(
        (circle.decoration! as ShapeDecoration).color,
        TakiColors.primaryPressed,
      );
      await gesture.up();
    });

    testWidgets('cargando: spinner y "Cargando", pero sigue respondiendo',
        (tester) async {
      final calls = <String>[];
      final handle = tester.ensureSemantics();
      await pumpInScreen(
        tester,
        _controls(isPlaying: true, isLoading: true, calls: calls),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Se puede pausar sin esperar a que termine de cargar.
      await tester.tap(find.byType(TakiPlayPauseButton));
      expect(calls, ['playPause']);
      expect(
        tester.getSemantics(find.byType(TakiPlayPauseButton)),
        isSemantics(
          label: TakiPlaybackControls.pauseLabel,
          value: TakiPlaybackControls.loadingValue,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });

  testWidgets('cada control llama a su callback', (tester) async {
    final calls = <String>[];
    await pumpInScreen(tester, _controls(calls: calls));

    for (final label in [
      TakiPlaybackControls.shuffleLabel,
      TakiPlaybackControls.previousLabel,
      TakiPlaybackControls.playLabel,
      TakiPlaybackControls.nextLabel,
      TakiPlaybackControls.repeatLabel,
    ]) {
      await tester.tap(_control(label));
    }
    expect(calls, ['shuffle', 'previous', 'playPause', 'next', 'repeat']);
  });

  testWidgets('sin callbacks: deshabilitados al 38 % y sin respuesta',
      (tester) async {
    await pumpInScreen(tester, _controls(withCallbacks: false));

    for (final label in [
      TakiPlaybackControls.shuffleLabel,
      TakiPlaybackControls.previousLabel,
      TakiPlaybackControls.nextLabel,
      TakiPlaybackControls.repeatLabel,
    ]) {
      expect(
        _iconIn(tester, label).color!.a,
        closeTo(TakiColors.disabledContentOpacity, 0.01),
        reason: label,
      );
    }
    final circle = tester.widget<Container>(find.descendant(
      of: find.byType(TakiPlayPauseButton),
      matching: find.byType(Container),
    ));
    expect(
      (circle.decoration! as ShapeDecoration).color,
      TakiColors.disabledContainer,
    );
  });

  group('aleatorio', () {
    testWidgets('apagado: gris y sin círculo', (tester) async {
      await pumpInScreen(tester, _controls());
      expect(
        _iconIn(tester, TakiPlaybackControls.shuffleLabel).color,
        TakiColors.iconSecondary,
      );
      expect(_toggleCircle(tester, TakiPlaybackControls.shuffleLabel), isNull);
    });

    testWidgets('activo: naranja **y** círculo (no solo color)',
        (tester) async {
      await pumpInScreen(tester, _controls(shuffle: true));
      await tester.pumpAndSettle();
      expect(
        _iconIn(tester, TakiPlaybackControls.shuffleLabel).color,
        TakiColors.active,
      );
      expect(
        _toggleCircle(tester, TakiPlaybackControls.shuffleLabel),
        TakiColors.primaryContainer,
      );
    });
  });

  group('repetir', () {
    testWidgets('off: icono normal, gris, sin círculo', (tester) async {
      await pumpInScreen(tester, _controls());
      expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);
      expect(_toggleCircle(tester, TakiPlaybackControls.repeatLabel), isNull);
    });

    testWidgets('todas: repeat con círculo', (tester) async {
      await pumpInScreen(tester, _controls(repeat: TakiRepeatMode.all));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);
      expect(
        _toggleCircle(tester, TakiPlaybackControls.repeatLabel),
        TakiColors.primaryContainer,
      );
    });

    testWidgets('una: icono propio (repeat_one) con círculo', (tester) async {
      await pumpInScreen(tester, _controls(repeat: TakiRepeatMode.one));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.repeat_one_rounded), findsOneWidget);
      expect(find.byIcon(Icons.repeat_rounded), findsNothing);
      expect(
        _toggleCircle(tester, TakiPlaybackControls.repeatLabel),
        TakiColors.primaryContainer,
      );
    });
  });

  group('semántica', () {
    testWidgets('interruptores con estado y modo de repetición',
        (tester) async {
      final handle = tester.ensureSemantics();

      for (final mode in TakiRepeatMode.values) {
        await pumpInScreen(tester, _controls(repeat: mode, shuffle: true));
        expect(
          tester.getSemantics(
            find.bySemanticsLabel(TakiPlaybackControls.repeatLabel),
          ),
          isSemantics(
            isButton: true,
            hasToggledState: true,
            isToggled: mode != TakiRepeatMode.off,
            value: mode.semanticValue,
          ),
          reason: mode.name,
        );
      }
      expect(
        tester.getSemantics(
          find.bySemanticsLabel(TakiPlaybackControls.shuffleLabel),
        ),
        isSemantics(isButton: true, hasToggledState: true, isToggled: true),
      );
      handle.dispose();
    });

    testWidgets('play/pausa anuncia la acción que hará', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpInScreen(tester, _controls(isPlaying: true));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byType(TakiPlayPauseButton)),
        isSemantics(
          label: TakiPlaybackControls.pauseLabel,
          isButton: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('anterior y siguiente son botones con etiqueta',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpInScreen(tester, _controls());
      for (final label in [
        TakiPlaybackControls.previousLabel,
        TakiPlaybackControls.nextLabel,
      ]) {
        expect(
          tester.getSemantics(find.bySemanticsLabel(label)),
          isSemantics(isButton: true, hasTapAction: true),
          reason: label,
        );
      }
      handle.dispose();
    });
  });

  testWidgets('todas las áreas táctiles miden al menos 48', (tester) async {
    await pumpInScreen(tester, _controls());
    for (final label in [
      TakiPlaybackControls.shuffleLabel,
      TakiPlaybackControls.previousLabel,
      TakiPlaybackControls.playLabel,
      TakiPlaybackControls.nextLabel,
      TakiPlaybackControls.repeatLabel,
    ]) {
      final size = tester.getSize(_control(label));
      expect(size.width, greaterThanOrEqualTo(48), reason: label);
      expect(size.height, greaterThanOrEqualTo(48), reason: label);
    }
  });

  testWidgets('cabe en un móvil estrecho sin desbordar', (tester) async {
    await pumpInScreen(tester, _controls(), width: 320);
    expect(tester.takeException(), isNull);
  });
}
