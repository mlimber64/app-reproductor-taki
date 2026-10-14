import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taki/app/theme/app_theme.dart';
import 'package:taki/core/domain/entities/lyrics.dart';
import 'package:taki/core/domain/ports/lyrics_source.dart';
import 'package:taki/core/lyrics/lyrics_providers.dart';
import 'package:taki/core/widgets/artwork_tint.dart';
import 'package:taki/features/player/domain/entities/equalizer.dart';
import 'package:taki/features/player/domain/entities/playback_state.dart';
import 'package:taki/features/player/domain/ports/equalizer_port.dart';
import 'package:taki/features/player/presentation/providers/equalizer_providers.dart';
import 'package:taki/features/player/presentation/providers/player_providers.dart';
import 'package:taki/features/player/presentation/providers/sleep_timer_providers.dart';
import 'package:taki/features/player/presentation/widgets/equalizer_sheet.dart';
import 'package:taki/features/player/presentation/widgets/lyrics_sheet.dart';
import 'package:taki/features/player/presentation/widgets/sleep_timer_sheet.dart';

import '../../../helpers/library_fakes.dart';
import '../../../helpers/player_fakes.dart';

class _Lyrics implements LyricsSource {
  _Lyrics(this.handler);

  Future<Lyrics?> Function(LyricsQuery query) handler;
  final List<LyricsQuery> queries = [];

  @override
  Future<Lyrics?> find(LyricsQuery query) {
    queries.add(query);
    return handler(query);
  }
}

class _Equalizer implements EqualizerPort {
  _Equalizer({this.state});

  EqualizerState? state;
  final List<String> calls = [];

  @override
  Future<EqualizerState?> load() async => state;

  @override
  Future<void> setEnabled(bool enabled) async => calls.add('enabled($enabled)');

  @override
  Future<void> setBandGain(int index, double gain) async =>
      calls.add('gain($index,$gain)');
}

const _lines = Lyrics(lines: [
  LyricLine(Duration(seconds: 5), 'First line'),
  LyricLine(Duration(seconds: 15), 'Second line'),
  LyricLine(Duration(seconds: 25), 'Third line'),
]);

void main() {
  late FakeAudioPlayerPort player;

  setUp(() => player = FakeAudioPlayerPort());

  Future<ProviderContainer> pump(
    WidgetTester tester,
    Widget child, {
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(412, 915) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(overrides: [
      audioPlayerPortProvider.overrideWithValue(player),
      ...overrides,
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(body: child),
      ),
    ));
    await tester.pump();
    await tester.pump();
    return container;
  }

  group('LyricsSheet', () {
    final song = buildSong(id: 1);

    testWidgets('asks for the lyrics of the song with its title and artist',
        (tester) async {
      final source = _Lyrics((_) async => _lines);

      await pump(
        tester,
        LyricsSheet(song: song),
        overrides: [lyricsSourceProvider.overrideWithValue(source)],
      );

      expect(source.queries.single.title, song.title);
      expect(source.queries.single.artist, song.artist);
      expect(find.text('First line'), findsOneWidget);
      expect(find.text('Third line'), findsOneWidget);
      expect(find.text(LyricsTexts.credit), findsOneWidget);
    });

    testWidgets('tapping a line seeks the song there', (tester) async {
      final source = _Lyrics((_) async => _lines);
      await pump(
        tester,
        LyricsSheet(song: song),
        overrides: [lyricsSourceProvider.overrideWithValue(source)],
      );

      await tester.tap(find.text('Second line'));
      await tester.pump();

      expect(player.calls, contains('seek(15s)'));
    });

    testWidgets('the line being sung is highlighted', (tester) async {
      final source = _Lyrics((_) async => _lines);
      await pump(
        tester,
        LyricsSheet(song: song),
        overrides: [lyricsSourceProvider.overrideWithValue(source)],
      );

      Color? colorOf(String text) => tester
          .widget<AnimatedDefaultTextStyle>(find.ancestor(
            of: find.text(text),
            matching: find.byType(AnimatedDefaultTextStyle),
          ).first)
          .style
          .color;

      final before = colorOf('Second line');
      player.emitPosition(const Duration(seconds: 16));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(colorOf('Second line'), isNot(before));
      expect(colorOf('Second line'), isNot(colorOf('Third line')));
    });

    testWidgets('plain lyrics are shown as text', (tester) async {
      final source = _Lyrics((_) async => const Lyrics(text: 'Just words'));

      await pump(
        tester,
        LyricsSheet(song: song),
        overrides: [lyricsSourceProvider.overrideWithValue(source)],
      );

      expect(find.text('Just words'), findsOneWidget);
    });

    testWidgets('no lyrics says so', (tester) async {
      final source = _Lyrics((_) async => null);

      await pump(
        tester,
        LyricsSheet(song: song),
        overrides: [lyricsSourceProvider.overrideWithValue(source)],
      );

      expect(find.text(LyricsTexts.notFound), findsOneWidget);
    });

    testWidgets('an instrumental track says so', (tester) async {
      final source = _Lyrics((_) async => const Lyrics(instrumental: true));

      await pump(
        tester,
        LyricsSheet(song: song),
        overrides: [lyricsSourceProvider.overrideWithValue(source)],
      );

      expect(find.text(LyricsTexts.instrumental), findsOneWidget);
    });

    testWidgets('while it loads it shows progress', (tester) async {
      final pending = Completer<Lyrics?>();
      final source = _Lyrics((_) => pending.future);

      await pump(
        tester,
        LyricsSheet(song: song),
        overrides: [lyricsSourceProvider.overrideWithValue(source)],
      );

      expect(find.text(LyricsTexts.loading), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.complete(null);
      await tester.pump();
    });

    testWidgets('a failure offers to retry and asks again', (tester) async {
      var attempts = 0;
      final source = _Lyrics((_) async {
        if (++attempts == 1) throw const LyricsLookupFailure('down');
        return _lines;
      });
      await pump(
        tester,
        LyricsSheet(song: song),
        overrides: [lyricsSourceProvider.overrideWithValue(source)],
      );
      expect(find.text(LyricsTexts.failed), findsOneWidget);

      await tester.tap(find.text(LyricsTexts.retry));
      await tester.pump();
      await tester.pump();

      expect(find.text('First line'), findsOneWidget);
      expect(attempts, 2);
    });
  });

  group('EqualizerSheet', () {
    EqualizerState sample({bool enabled = false}) => EqualizerState(
          enabled: enabled,
          minGain: -10,
          maxGain: 10,
          bands: const [
            EqualizerBand(index: 0, centerFrequencyHz: 60, gain: 0),
            EqualizerBand(index: 1, centerFrequencyHz: 230, gain: 0),
            EqualizerBand(index: 2, centerFrequencyHz: 910, gain: 0),
            EqualizerBand(index: 3, centerFrequencyHz: 3600, gain: 0),
            EqualizerBand(index: 4, centerFrequencyHz: 14000, gain: 0),
          ],
        );

    testWidgets('explains when the equalizer is not available yet',
        (tester) async {
      await pump(
        tester,
        const EqualizerSheet(),
        overrides: [
          equalizerPortProvider.overrideWithValue(_Equalizer()),
        ],
      );

      expect(find.text(EqualizerTexts.unavailable), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('shows a slider per band, labelled by frequency',
        (tester) async {
      await pump(
        tester,
        const EqualizerSheet(),
        overrides: [
          equalizerPortProvider.overrideWithValue(_Equalizer(state: sample())),
        ],
      );

      expect(find.byType(Slider), findsNWidgets(5));
      expect(find.text('60 Hz'), findsOneWidget);
      expect(find.text('3.6 kHz'), findsOneWidget);
      expect(find.text('14 kHz'), findsOneWidget);
    });

    testWidgets('the sliders are off until the equalizer is enabled',
        (tester) async {
      final port = _Equalizer(state: sample());
      await pump(
        tester,
        const EqualizerSheet(),
        overrides: [equalizerPortProvider.overrideWithValue(port)],
      );

      expect(
        tester.widgetList<Slider>(find.byType(Slider)).every((s) => s.onChanged == null),
        isTrue,
      );

      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump();

      expect(port.calls, contains('enabled(true)'));
      expect(
        tester.widgetList<Slider>(find.byType(Slider)).every((s) => s.onChanged != null),
        isTrue,
      );
    });

    testWidgets('a preset chip applies its curve', (tester) async {
      final port = _Equalizer(state: sample());
      await pump(
        tester,
        const EqualizerSheet(),
        overrides: [equalizerPortProvider.overrideWithValue(port)],
      );

      await tester.tap(find.widgetWithText(ActionChip, 'Más graves'));
      await tester.pump();
      await tester.pump();

      expect(port.calls, contains('enabled(true)'));
      expect(port.calls.where((c) => c.startsWith('gain(')), hasLength(5));
    });
  });

  group('SleepTimerSheet', () {
    testWidgets('picking a duration starts the timer', (tester) async {
      final container = await pump(tester, const SleepTimerSheet());

      await tester.tap(find.text(SleepTimerTexts.minutes(30)));
      await tester.pump();

      expect(container.read(sleepTimerProvider).remaining,
          const Duration(minutes: 30));
      container.read(sleepTimerProvider.notifier).cancel();
    });

    testWidgets('end of track mode', (tester) async {
      final container = await pump(tester, const SleepTimerSheet());
      player.emitState(
        PlaybackState(queue: [buildSong(id: 1)], currentIndex: 0),
      );

      await tester.tap(find.text(SleepTimerTexts.endOfTrack));
      await tester.pump();

      expect(container.read(sleepTimerProvider).atEndOfTrack, isTrue);
      container.read(sleepTimerProvider.notifier).cancel();
    });

    testWidgets('offers to turn it off only while active', (tester) async {
      final container = await pump(tester, const SleepTimerSheet());
      expect(find.text(SleepTimerTexts.cancel), findsNothing);

      container
          .read(sleepTimerProvider.notifier)
          .startAfter(const Duration(minutes: 15));
      await tester.pump();

      expect(find.text(SleepTimerTexts.cancel), findsOneWidget);
      await tester.tap(find.text(SleepTimerTexts.cancel));
      await tester.pump();
      expect(container.read(sleepTimerProvider).isActive, isFalse);
    });
  });

  group('ArtworkTint', () {
    testWidgets('without an image the tint is null', (tester) async {
      Color? seen = const Color(0xFF123456);

      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: ArtworkTint(
          image: null,
          builder: (_, tint) {
            seen = tint;
            return const SizedBox();
          },
        ),
      ));

      expect(seen, isNull);
    });
  });
}
