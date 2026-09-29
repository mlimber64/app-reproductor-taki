import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/theme/taki_colors.dart';
import 'package:taki/core/widgets/taki_artwork.dart';
import 'package:taki/core/widgets/taki_icon_button.dart';
import 'package:taki/core/widgets/taki_mini_player.dart';

import 'widget_test_utils.dart';

TakiMiniPlayer _player({
  bool isPlaying = true,
  VoidCallback? onPlayPause,
  VoidCallback? onOpen,
  double progress = 0,
  VoidCallback? onNext,
  VoidCallback? onToggleFavorite,
  bool isFavorite = false,
  String title = 'Matador',
}) {
  return TakiMiniPlayer(
    song: testSong(title: title),
    isPlaying: isPlaying,
    onPlayPause: onPlayPause ?? () {},
    onOpen: onOpen ?? () {},
    progress: progress,
    onNext: onNext,
    onToggleFavorite: onToggleFavorite,
    isFavorite: isFavorite,
  );
}

Finder _playButton() => find.byWidgetPredicate(
      (w) => w is TakiIconButton && w.variant == TakiIconButtonVariant.inverse,
    );

void main() {
  testWidgets('canción, artista y carátula', (tester) async {
    await pumpInScreen(tester, _player());

    expect(find.text('Matador'), findsOneWidget);
    expect(find.text('Los Fabulosos Cadillacs'), findsOneWidget);
    expect(find.byType(TakiArtwork), findsOneWidget);
  });

  group('play / pausa', () {
    testWidgets('sonando muestra pausa; en pausa, play', (tester) async {
      await pumpInScreen(tester, _player());
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      await pumpInScreen(tester, _player(isPlaying: false));
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('es blanco, no naranja (no compite con la pantalla)',
        (tester) async {
      await pumpInScreen(tester, _player());
      expect(_playButton(), findsOneWidget);
      final icon = tester.widget<Icon>(
        find.descendant(of: _playButton(), matching: find.byType(Icon)),
      );
      expect(icon.color, TakiColors.onTextPrimary);
    });

    testWidgets('pulsarlo no abre Reproduciendo', (tester) async {
      final calls = <String>[];
      await pumpInScreen(
        tester,
        _player(
          onPlayPause: () => calls.add('playPause'),
          onOpen: () => calls.add('open'),
        ),
      );
      await tester.tap(_playButton());
      expect(calls, ['playPause']);
    });
  });

  group('abrir Reproduciendo', () {
    testWidgets('al tocar', (tester) async {
      var opened = 0;
      await pumpInScreen(tester, _player(onOpen: () => opened++));
      await tester.tap(find.text('Matador'));
      expect(opened, 1);
    });

    testWidgets('al deslizar hacia arriba', (tester) async {
      var opened = 0;
      await pumpInScreen(tester, _player(onOpen: () => opened++));
      await tester.fling(find.text('Matador'), const Offset(0, -80), 1000);
      await tester.pumpAndSettle();
      expect(opened, 1);
    });
  });

  group('acciones opcionales', () {
    testWidgets('favorito solo si hay callback; se anuncia como interruptor',
        (tester) async {
      await pumpInScreen(tester, _player());
      expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);

      final handle = tester.ensureSemantics();
      var toggles = 0;
      await pumpInScreen(
        tester,
        _player(isFavorite: true, onToggleFavorite: () => toggles++),
      );
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel(TakiMiniPlayer.favoriteLabel)),
        isSemantics(hasToggledState: true, isToggled: true),
      );
      await tester.tap(find.byIcon(Icons.favorite_rounded));
      expect(toggles, 1);
      handle.dispose();
    });

    testWidgets('siguiente solo con callback y ancho ≥ 400', (tester) async {
      await pumpInScreen(tester, _player(onNext: () {}), width: 360);
      expect(find.byIcon(Icons.skip_next_rounded), findsNothing);

      var next = 0;
      await pumpInScreen(tester, _player(onNext: () => next++), width: 412);
      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      expect(next, 1);
    });
  });

  testWidgets('progreso: fracción y límites', (tester) async {
    double factor() => tester
        .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
        .widthFactor!;

    await pumpInScreen(tester, _player(progress: 0.25));
    expect(factor(), 0.25);

    await pumpInScreen(tester, _player(progress: 1.4));
    expect(factor(), 1);
  });

  testWidgets('alto estable de 64 con textos largos', (tester) async {
    await pumpInScreen(
      tester,
      _player(title: 'Un título larguísimo que no cabe en el mini player'),
      width: 320,
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(TakiMiniPlayer)).height,
      TakiMiniPlayer.height,
    );
  });

  group('semántica', () {
    testWidgets('canción, artista, estado y acción principal', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpInScreen(tester, _player());

      expect(
        tester.getSemantics(find.byType(TakiMiniPlayer)),
        isSemantics(
          label: 'Matador, Los Fabulosos Cadillacs',
          value: TakiMiniPlayer.playingLabel,
          isButton: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel(TakiMiniPlayer.pauseLabel)),
        isSemantics(isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('en pausa se anuncia "En pausa" y el botón "Reproducir"',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpInScreen(tester, _player(isPlaying: false));

      expect(
        tester.getSemantics(find.byType(TakiMiniPlayer)),
        isSemantics(value: TakiMiniPlayer.pausedLabel),
      );
      expect(find.bySemanticsLabel(TakiMiniPlayer.playLabel), findsOneWidget);
      handle.dispose();
    });
  });
}
