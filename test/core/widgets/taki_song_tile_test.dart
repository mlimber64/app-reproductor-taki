import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/theme/taki_colors.dart';
import 'package:taki/core/widgets/taki_artwork.dart';
import 'package:taki/core/widgets/taki_playing_indicator.dart';
import 'package:taki/core/widgets/taki_song_tile.dart';

import 'widget_test_utils.dart';

Text _text(WidgetTester tester, String value) =>
    tester.widget<Text>(find.text(value));

void main() {
  group('contenido', () {
    testWidgets('título, artista y duración', (tester) async {
      await pumpInScreen(tester, TakiSongTile(song: testSong()));

      expect(find.text('Matador'), findsOneWidget);
      expect(find.text('Los Fabulosos Cadillacs'), findsOneWidget);
      expect(find.text('3:05'), findsOneWidget);
      expect(find.byType(TakiArtwork), findsOneWidget);
    });

    testWidgets('álbum opcional detrás del artista', (tester) async {
      await pumpInScreen(
        tester,
        TakiSongTile(song: testSong(), showAlbum: true),
      );
      expect(find.text('Los Fabulosos Cadillacs · Vasos vacíos'), findsOneWidget);
    });

    testWidgets('sin artista: "Artista desconocido"; duración opcional',
        (tester) async {
      await pumpInScreen(
        tester,
        TakiSongTile(song: testSong(artist: null), showDuration: false),
      );
      expect(find.text(TakiSongTile.unknownArtist), findsOneWidget);
      expect(find.text('3:05'), findsNothing);
    });
  });

  group('callbacks', () {
    testWidgets('tocar, mantener pulsado y ⋯', (tester) async {
      final calls = <String>[];
      await pumpInScreen(
        tester,
        TakiSongTile(
          song: testSong(),
          onTap: () => calls.add('tap'),
          onLongPress: () => calls.add('long'),
          onMore: () => calls.add('more'),
        ),
      );

      await tester.tap(find.text('Matador'));
      await tester.longPress(find.text('Matador'));
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      expect(calls, ['tap', 'long', 'more']);
    });

    testWidgets('sin onMore no hay botón ⋯', (tester) async {
      await pumpInScreen(tester, TakiSongTile(song: testSong(), onTap: () {}));
      expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
    });
  });

  group('sonando', () {
    testWidgets('título en naranja **y** barras en movimiento', (tester) async {
      await pumpInScreen(
        tester,
        TakiSongTile(song: testSong(), playback: TakiNowPlaying.playing),
      );

      expect(_text(tester, 'Matador').style!.color, TakiColors.active);
      final indicator =
          tester.widget<TakiPlayingIndicator>(find.byType(TakiPlayingIndicator));
      expect(indicator.animate, isTrue);
    });

    testWidgets('en pausa: barras quietas', (tester) async {
      await pumpInScreen(
        tester,
        TakiSongTile(song: testSong(), playback: TakiNowPlaying.paused),
      );
      expect(
        tester
            .widget<TakiPlayingIndicator>(find.byType(TakiPlayingIndicator))
            .animate,
        isFalse,
      );
    });

    testWidgets('si no es la actual no hay indicador', (tester) async {
      await pumpInScreen(tester, TakiSongTile(song: testSong()));
      expect(find.byType(TakiPlayingIndicator), findsNothing);
      expect(_text(tester, 'Matador').style!.color, TakiColors.textPrimary);
    });
  });

  testWidgets('favorita: corazón relleno (forma, no solo color)',
      (tester) async {
    await pumpInScreen(tester, TakiSongTile(song: testSong(), isFavorite: true));
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

    await pumpInScreen(tester, TakiSongTile(song: testSong()));
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
  });

  testWidgets('seleccionada: fondo selected y marca en lugar de la carátula',
      (tester) async {
    await pumpInScreen(tester, TakiSongTile(song: testSong(), selected: true));

    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byType(TakiArtwork), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) => w is Container && w.color == TakiColors.selected,
      ),
      findsOneWidget,
    );
  });

  group('no disponible', () {
    testWidgets('subtítulo "No disponible" y contenido al 38 %',
        (tester) async {
      await pumpInScreen(
        tester,
        TakiSongTile(song: testSong(), available: false, isFavorite: true),
      );

      expect(find.text(TakiSongTile.unavailableLabel), findsOneWidget);
      expect(find.text('Los Fabulosos Cadillacs'), findsNothing);
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
      expect(
        tester
            .widgetList<Opacity>(find.byType(Opacity))
            .every((o) => o.opacity == TakiColors.disabledContentOpacity),
        isTrue,
      );
    });

    testWidgets('se puede pulsar (para explicar por qué)', (tester) async {
      var taps = 0;
      await pumpInScreen(
        tester,
        TakiSongTile(song: testSong(), available: false, onTap: () => taps++),
      );
      await tester.tap(find.byType(TakiSongTile));
      expect(taps, 1);
    });
  });

  group('semántica', () {
    testWidgets('se lee como una unidad: título, artista y duración',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpInScreen(
        tester,
        TakiSongTile(song: testSong(), onTap: () {}, onMore: () {}),
      );

      expect(
        tester.getSemantics(find.byType(TakiSongTile)),
        isSemantics(
          label: 'Matador, Los Fabulosos Cadillacs, 3:05',
          isButton: true,
          hasTapAction: true,
        ),
      );
      // ⋯ es un botón aparte.
      expect(
        tester.getSemantics(find.bySemanticsLabel(TakiSongTile.moreLabel)),
        isSemantics(isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('anuncia sonando, favorita y seleccionada', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpInScreen(
        tester,
        TakiSongTile(
          song: testSong(),
          playback: TakiNowPlaying.playing,
          isFavorite: true,
          selected: true,
          onTap: () {},
        ),
      );

      expect(
        tester.getSemantics(find.byType(TakiSongTile)),
        isSemantics(
          value: '${TakiSongTile.playingLabel}, ${TakiSongTile.favoriteLabel}',
          isSelected: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('anuncia "No disponible"', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpInScreen(
        tester,
        TakiSongTile(song: testSong(), available: false),
      );
      expect(
        tester.getSemantics(find.byType(TakiSongTile)),
        isSemantics(value: TakiSongTile.unavailableLabel),
      );
      handle.dispose();
    });
  });

  group('espacio reducido', () {
    testWidgets('título y artista con elipsis; nunca desborda', (tester) async {
      await pumpInScreen(
        tester,
        TakiSongTile(
          song: testSong(
            title: 'Un título larguísimo que no cabe en una pantalla estrecha',
            artist: 'Un artista con un nombre también muy largo',
          ),
          showAlbum: true,
          onMore: () {},
        ),
        width: 280,
      );

      expect(tester.takeException(), isNull);
      final title = _text(tester, 'Un título larguísimo que no cabe en una pantalla estrecha');
      expect(title.maxLines, 1);
      expect(title.overflow, TextOverflow.ellipsis);
      // El álbum va al final del subtítulo: es lo primero que se recorta.
      expect(
        find.text('Un artista con un nombre también muy largo · Vasos vacíos'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    });

    testWidgets('alto mínimo 64; crece con el texto grande', (tester) async {
      await pumpInScreen(tester, TakiSongTile(song: testSong()));
      expect(
        tester.getSize(find.byType(TakiSongTile)).height,
        TakiSongTile.minHeight,
      );

      await pumpInScreen(tester, TakiSongTile(song: testSong()), textScale: 2);
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(TakiSongTile)).height,
        greaterThan(TakiSongTile.minHeight),
      );
    });
  });
}
