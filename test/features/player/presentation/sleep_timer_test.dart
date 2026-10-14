import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taki/features/player/domain/entities/playback_state.dart';
import 'package:taki/features/player/domain/entities/sleep_timer_state.dart';
import 'package:taki/features/player/presentation/providers/player_providers.dart';
import 'package:taki/features/player/presentation/providers/sleep_timer_providers.dart';
import 'package:taki/features/player/presentation/widgets/sleep_timer_sheet.dart';

import '../../../helpers/library_fakes.dart';
import '../../../helpers/player_fakes.dart';

void main() {
  late FakeAudioPlayerPort player;
  late ProviderContainer container;

  setUp(() {
    player = FakeAudioPlayerPort();
    container = ProviderContainer(overrides: [
      audioPlayerPortProvider.overrideWithValue(player),
    ]);
    addTearDown(container.dispose);
    // The timer listens to these; keep them alive like a screen would.
    container.listen(currentSongProvider, (_, _) {});
    container.listen(positionProvider, (_, _) {});
    container.listen(playbackStateProvider, (_, _) {});
  });

  SleepTimerController timer() => container.read(sleepTimerProvider.notifier);
  SleepTimerState state() => container.read(sleepTimerProvider);

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('starts idle', () {
    expect(state(), SleepTimerState.idle);
    expect(state().isActive, isFalse);
  });

  testWidgets('counts down and pauses at zero', (tester) async {
    player.emitState(PlaybackState(
      queue: [buildSong(id: 1)],
      currentIndex: 0,
      isPlaying: true,
    ));

    timer().startAfter(const Duration(seconds: 3));
    expect(state().remaining, const Duration(seconds: 3));

    await tester.pump(const Duration(seconds: 1));
    expect(state().remaining, const Duration(seconds: 2));
    expect(player.calls, isNot(contains('pause')));

    await tester.pump(const Duration(seconds: 2));
    expect(state(), SleepTimerState.idle);
    expect(player.calls, contains('pause'));
  });

  testWidgets('cancel stops it without pausing', (tester) async {
    timer().startAfter(const Duration(seconds: 3));

    timer().cancel();
    await tester.pump(const Duration(seconds: 5));

    expect(state(), SleepTimerState.idle);
    expect(player.calls, isNot(contains('pause')));
  });

  testWidgets('starting again replaces the running timer', (tester) async {
    timer().startAfter(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 2));

    timer().startAfter(const Duration(seconds: 30));

    expect(state().remaining, const Duration(seconds: 30));
    timer().cancel();
  });

  test('a zero duration does nothing', () {
    timer().startAfter(Duration.zero);

    expect(state(), SleepTimerState.idle);
  });

  test('end of track pauses when the track changes', () async {
    final first = buildSong(id: 1);
    final second = buildSong(id: 2);
    player.emitState(
      PlaybackState(queue: [first, second], currentIndex: 0, isPlaying: true),
    );
    await settle();

    timer().startAtEndOfTrack();
    expect(state().atEndOfTrack, isTrue);

    player.emitState(
      PlaybackState(queue: [first, second], currentIndex: 1, isPlaying: true),
    );
    await settle();

    expect(state(), SleepTimerState.idle);
    expect(player.calls, contains('pause'));
  });

  test('end of track pauses when the position reaches the end', () async {
    player.emitState(PlaybackState(
      queue: [buildSong(id: 1)],
      currentIndex: 0,
      isPlaying: true,
      duration: const Duration(minutes: 3),
    ));
    await settle();
    timer().startAtEndOfTrack();

    player.emitPosition(const Duration(minutes: 1));
    await settle();
    expect(state().atEndOfTrack, isTrue, reason: 'still in the middle');

    player.emitPosition(const Duration(minutes: 3) - const Duration(milliseconds: 200));
    await settle();

    expect(state(), SleepTimerState.idle);
    expect(player.calls, contains('pause'));
  });

  group('texts', () {
    test('formatCountdown', () {
      expect(formatCountdown(const Duration(seconds: 5)), '0:05');
      expect(formatCountdown(const Duration(minutes: 12, seconds: 5)), '12:05');
      expect(formatCountdown(const Duration(seconds: -4)), '0:00');
    });

    test('sleepTimerBadge', () {
      expect(sleepTimerBadge(SleepTimerState.idle), isNull);
      expect(sleepTimerBadge(const SleepTimerState.countdown(Duration(seconds: 65))),
          '1:05');
      expect(sleepTimerBadge(SleepTimerState.endOfTrack), SleepTimerTexts.active);
    });
  });
}
