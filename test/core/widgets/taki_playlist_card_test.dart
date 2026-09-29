import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/widgets/taki_artwork.dart';
import 'package:taki/core/widgets/taki_playing_indicator.dart';
import 'package:taki/core/widgets/taki_playlist_card.dart';

import 'widget_test_utils.dart';

void main() {
  group('contenido', () {
    testWidgets('nombre y metadata "N canciones · resto"', (tester) async {
      await pumpInScreen(
        tester,
        const TakiPlaylistCard(
          title: 'Rock en español',
          songCount: 12,
          subtitle: '48 min',
        ),
      );

      expect(find.text('Rock en español'), findsOneWidget);
      expect(find.text('12 canciones · 48 min'), findsOneWidget);
    });

    test('número de canciones', () {
      expect(TakiPlaylistCard.songCountLabel(0), TakiPlaylistCard.emptyLabel);
      expect(TakiPlaylistCard.songCountLabel(1), '1 canción');
      expect(TakiPlaylistCard.songCountLabel(7), '7 canciones');
    });

    testWidgets('solo subtítulo, o sin metadata', (tester) async {
      await pumpInScreen(
        tester,
        const TakiPlaylistCard(title: 'Online', subtitle: 'Taki'),
      );
      expect(find.text('Taki'), findsOneWidget);

      await pumpInScreen(tester, const TakiPlaylistCard(title: 'Sola'));
      expect(find.byType(Text), findsOneWidget);
    });
  });

  group('portada', () {
    testWidgets('con 4 carátulas, mosaico 2×2', (tester) async {
      await pumpInScreen(
        tester,
        const TakiPlaylistCard(
          title: 'Mix',
          artwork: [null, null, null, null],
        ),
      );
      expect(find.byIcon(Icons.queue_music_rounded), findsNWidgets(4));
    });

    testWidgets('con menos de 4, una sola', (tester) async {
      await pumpInScreen(
        tester,
        const TakiPlaylistCard(title: 'Mix', artwork: [null, null]),
      );
      expect(find.byIcon(Icons.queue_music_rounded), findsOneWidget);
    });

    testWidgets('vacía: placeholder con borde outline', (tester) async {
      await pumpInScreen(
        tester,
        const TakiPlaylistCard(title: 'Nueva', songCount: 0),
      );
      expect(find.text(TakiPlaylistCard.emptyLabel), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TakiArtwork),
          matching: find.byWidgetPredicate(
            (w) =>
                w is DecoratedBox &&
                w.position == DecorationPosition.foreground,
          ),
        ),
        findsOneWidget,
      );
    });
  });

  group('interacción', () {
    testWidgets('tocar y mantener pulsado', (tester) async {
      final calls = <String>[];
      await pumpInScreen(
        tester,
        TakiPlaylistCard(
          title: 'Rock',
          onTap: () => calls.add('tap'),
          onLongPress: () => calls.add('long'),
        ),
      );
      await tester.tap(find.byType(TakiPlaylistCard));
      await tester.longPress(find.byType(TakiPlaylistCard));
      expect(calls, ['tap', 'long']);
    });

    testWidgets('chevron solo si navega', (tester) async {
      await pumpInScreen(tester, TakiPlaylistCard(title: 'A', onTap: () {}));
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

      await pumpInScreen(
        tester,
        TakiPlaylistCard(title: 'A', onTap: () {}, showChevron: false),
      );
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });
  });

  testWidgets('seleccionada: marca, y se anuncia seleccionada', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpInScreen(
      tester,
      TakiPlaylistCard(title: 'Rock', selected: true, onTap: () {}),
    );

    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(TakiPlaylistCard)),
      isSemantics(isSelected: true),
    );
    handle.dispose();
  });

  testWidgets('sonando: barras en la portada y "Reproduciendo"',
      (tester) async {
    final handle = tester.ensureSemantics();
    await pumpInScreen(
      tester,
      TakiPlaylistCard(
        title: 'Rock',
        nowPlaying: TakiNowPlaying.playing,
        onTap: () {},
      ),
    );

    expect(find.byType(TakiPlayingIndicator), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(TakiPlaylistCard)),
      isSemantics(value: TakiPlaylistCard.playingLabel),
    );
    handle.dispose();
  });

  testWidgets('semántica: botón con nombre y metadata', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpInScreen(
      tester,
      TakiPlaylistCard(
        title: 'Rock en español',
        songCount: 4,
        subtitle: '1 h 24 min',
        onTap: () {},
      ),
    );

    expect(
      tester.getSemantics(find.byType(TakiPlaylistCard)),
      isSemantics(
        label: 'Rock en español, 4 canciones · 1 h 24 min',
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('alto mínimo 72; nombre largo sin desbordar', (tester) async {
    await pumpInScreen(
      tester,
      TakiPlaylistCard(
        title: 'Una playlist con un nombre larguísimo que no cabe',
        songCount: 3,
        onTap: () {},
      ),
      width: 280,
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(TakiPlaylistCard)).height,
      TakiPlaylistCard.minHeight,
    );
  });
}
