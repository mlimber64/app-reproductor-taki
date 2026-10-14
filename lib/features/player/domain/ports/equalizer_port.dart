import '../entities/equalizer.dart';

/// The engine's equalizer.
///
/// Not every device exposes one, and it only becomes available once the player
/// has started playing, so [load] may answer `null`: callers treat that as
/// "not available right now", not as an error.
abstract interface class EqualizerPort {
  /// Current state, or `null` when the equalizer is not available (yet).
  Future<EqualizerState?> load();

  Future<void> setEnabled(bool enabled);

  /// Sets band [index] to [gain] decibels.
  Future<void> setBandGain(int index, double gain);
}
