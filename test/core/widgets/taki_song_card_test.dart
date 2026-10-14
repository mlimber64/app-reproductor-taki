import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/theme/taki_colors.dart';
import 'package:taki/core/widgets/taki_playing_indicator.dart';
import 'package:taki/core/widgets/taki_song_card.dart';

import 'widget_test_utils.dart';

void main() {
  Widget card({
    String? artist = 'Los Fabulosos Cadillacs',
    TakiNowPlaying playback = TakiNowPlaying.none,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) =>
      Align(
        alignment: Alignment.topLeft,
        child: TakiSongCard(
          song: testSong(artist: artist),
          artworkSize: 160,
          playback: playback,
          onTap: onTap,
          onLongPress: onLongPress,
        ),
      );

  testWidgets('shows the title and the artist under a square cover',
      (tester) async {
    await pumpInScreen(tester, card());

    expect(find.text('Matador'), findsOneWidget);
    expect(find.text('Los Fabulosos Cadillacs'), findsOneWidget);
    final size = tester.getSize(find.byType(TakiSongCard));
    expect(size.width, 160);
  });

  testWidgets('a song without artist shows the neutral label', (tester) async {
    await pumpInScreen(tester, card(artist: null));

    expect(find.text('Artista desconocido'), findsOneWidget);
  });

  testWidgets('tap and long press reach their callbacks', (tester) async {
    var taps = 0;
    var longPresses = 0;
    await pumpInScreen(
      tester,
      card(onTap: () => taps++, onLongPress: () => longPresses++),
    );

    await tester.tap(find.text('Matador'));
    await tester.longPress(find.text('Matador'));

    expect(taps, 1);
    expect(longPresses, 1);
  });

  testWidgets('is announced as one button: "title, artist"', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpInScreen(tester, card(onTap: () {}));

    expect(
      tester.getSemantics(find.byType(TakiSongCard)),
      isSemantics(
        label: 'Matador, Los Fabulosos Cadillacs',
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('the playing card is marked and announced', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpInScreen(
      tester,
      card(playback: TakiNowPlaying.playing, onTap: () {}),
    );

    expect(find.byType(TakiPlayingIndicator), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Matador')).style!.color,
      TakiColors.primary,
    );
    expect(
      tester.getSemantics(find.byType(TakiSongCard)).label,
      'Matador, Los Fabulosos Cadillacs, reproduciendo',
    );
    handle.dispose();
  });

  testWidgets('a paused card says so', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpInScreen(
      tester,
      card(playback: TakiNowPlaying.paused, onTap: () {}),
    );

    expect(
      tester.getSemantics(find.byType(TakiSongCard)).label,
      endsWith(', en pausa'),
    );
    handle.dispose();
  });

  testWidgets('no indicator when it is not the current song', (tester) async {
    await pumpInScreen(tester, card());

    expect(find.byType(TakiPlayingIndicator), findsNothing);
  });

  testWidgets('textBlockHeight grows with the text scale', (tester) async {
    late double normal;
    late double large;
    for (final scale in [1.0, 2.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Builder(
              builder: (context) {
                final height = TakiSongCard.textBlockHeight(context);
                if (scale == 1.0) {
                  normal = height;
                } else {
                  large = height;
                }
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    }

    expect(large, greaterThan(normal));
  });

  testWidgets('does not overflow at 150 % text with long texts',
      (tester) async {
    await pumpInScreen(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: TakiSongCard(
          song: testSong(
            title: 'Un título extremadamente largo que no cabe en la card',
            artist: 'Un artista con un nombre igual de largo para probar',
          ),
          artworkSize: 160,
        ),
      ),
      textScale: 1.5,
    );

    expect(tester.takeException(), isNull);
  });
}
