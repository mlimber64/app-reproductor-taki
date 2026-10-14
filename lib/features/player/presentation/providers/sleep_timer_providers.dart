import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/music_identity.dart';
import '../../domain/entities/sleep_timer_state.dart';
import 'player_providers.dart';

/// Pauses playback after a delay or when the current track ends.
final sleepTimerProvider =
    NotifierProvider<SleepTimerController, SleepTimerState>(
  SleepTimerController.new,
);

class SleepTimerController extends Notifier<SleepTimerState> {
  static const Duration _tick = Duration(seconds: 1);

  /// How close to the end of the track counts as "it ended". The position
  /// stream is sampled, so this must be larger than its period.
  static const Duration _endMargin = Duration(milliseconds: 600);

  Timer? _timer;
  MusicIdentity? _trackAtStart;

  @override
  SleepTimerState build() {
    ref.onDispose(_stop);

    ref.listen(currentSongProvider, (_, next) {
      // The track changed under "end of track": it already ended.
      if (!state.atEndOfTrack) return;
      final identity = next.valueOrNull?.musicIdentity;
      if (identity != _trackAtStart) _fire();
    });
    ref.listen(positionProvider, (_, next) {
      if (!state.atEndOfTrack) return;
      final position = next.valueOrNull;
      final duration = ref.read(playbackStateProvider).valueOrNull?.duration;
      if (position == null || duration == null || duration == Duration.zero) {
        return;
      }
      if (duration - position <= _endMargin) _fire();
    });
    return SleepTimerState.idle;
  }

  /// Pauses after [duration]. Replaces any timer already running.
  void startAfter(Duration duration) {
    if (duration <= Duration.zero) return;
    _stop();
    state = SleepTimerState.countdown(duration);
    _timer = Timer.periodic(_tick, (_) {
      final left = (state.remaining ?? Duration.zero) - _tick;
      if (left <= Duration.zero) {
        _fire();
      } else {
        state = SleepTimerState.countdown(left);
      }
    });
  }

  /// Pauses when the track that is playing now ends.
  void startAtEndOfTrack() {
    _stop();
    _trackAtStart = ref.read(currentSongProvider).valueOrNull?.musicIdentity;
    state = SleepTimerState.endOfTrack;
  }

  void cancel() {
    _stop();
    state = SleepTimerState.idle;
  }

  void _fire() {
    _stop();
    state = SleepTimerState.idle;
    ref.read(audioPlayerPortProvider).pause();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _trackAtStart = null;
  }
}
