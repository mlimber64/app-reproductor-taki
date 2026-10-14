import 'package:equatable/equatable.dart';

/// State of the sleep timer.
///
/// Idle, counting down ([remaining]) or waiting for the current track to end
/// ([atEndOfTrack]). The two active modes never overlap.
class SleepTimerState extends Equatable {
  const SleepTimerState._({this.remaining, this.atEndOfTrack = false});

  static const SleepTimerState idle = SleepTimerState._();

  const SleepTimerState.countdown(Duration remaining)
      : this._(remaining: remaining);

  static const SleepTimerState endOfTrack =
      SleepTimerState._(atEndOfTrack: true);

  /// Time left before pausing; `null` unless counting down.
  final Duration? remaining;

  /// Pause when the current track ends.
  final bool atEndOfTrack;

  bool get isActive => remaining != null || atEndOfTrack;

  @override
  List<Object?> get props => [remaining, atEndOfTrack];
}
