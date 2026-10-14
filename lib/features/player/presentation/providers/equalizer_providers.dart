import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/preferences/preferences_providers.dart';
import '../../domain/entities/equalizer.dart';
import '../../domain/ports/equalizer_port.dart';
import 'player_providers.dart';

/// Where the equalizer settings are kept in the preferences store.
const String equalizerPreferenceKey = 'equalizer';

/// An equalizer that is never available: the default until `main.dart` injects
/// the engine one, and what tests get unless they override it.
class UnavailableEqualizer implements EqualizerPort {
  const UnavailableEqualizer();

  @override
  Future<EqualizerState?> load() async => null;

  @override
  Future<void> setEnabled(bool enabled) async {}

  @override
  Future<void> setBandGain(int index, double gain) async {}
}

final equalizerPortProvider = Provider<EqualizerPort>(
  (ref) => const UnavailableEqualizer(),
);

/// The equalizer, with the last saved settings applied.
///
/// `null` means "not available right now": the engine only reports its bands
/// once it has started playing, so the value is read again when a song starts.
/// Changes are applied immediately and saved; saving is best effort (a failure
/// never undoes what the user hears).
final equalizerProvider =
    AsyncNotifierProvider<EqualizerController, EqualizerState?>(
  EqualizerController.new,
);

class EqualizerController extends AsyncNotifier<EqualizerState?> {
  EqualizerPort get _port => ref.read(equalizerPortProvider);

  @override
  Future<EqualizerState?> build() async {
    ref.listen(currentSongProvider, (_, next) {
      if (next.valueOrNull != null && state.valueOrNull == null) {
        ref.invalidateSelf();
      }
    });

    final loaded = await _port.load();
    if (loaded == null) return null;
    return _applySaved(loaded);
  }

  Future<EqualizerState> _applySaved(EqualizerState current) async {
    final saved = await _readSaved();
    if (saved == null) return current;

    var next = current.copyWith(enabled: saved.enabled);
    if (saved.gains.length == current.bands.length) {
      for (var i = 0; i < saved.gains.length; i++) {
        next = next.withBandGain(current.bands[i].index, saved.gains[i]);
      }
    }
    await _port.setEnabled(next.enabled);
    for (final band in next.bands) {
      await _port.setBandGain(band.index, band.gain);
    }
    return next;
  }

  Future<({bool enabled, List<double> gains})?> _readSaved() async {
    try {
      final raw = await ref
          .read(preferencesStoreProvider)
          .read(equalizerPreferenceKey);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final gains = decoded['gains'];
      return (
        enabled: decoded['enabled'] == true,
        gains: [
          if (gains is List<dynamic>)
            for (final gain in gains)
              if (gain is num) gain.toDouble(),
        ],
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(enabled: enabled));
    await _port.setEnabled(enabled);
    await _save();
  }

  Future<void> setBandGain(int index, double gain) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.withBandGain(index, gain));
    await _port.setBandGain(index, current.clampGain(gain));
  }

  /// Called when the user lets go of a slider: one save per gesture.
  Future<void> commit() => _save();

  Future<void> applyPreset(EqualizerPreset preset) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final gains = preset.gainsFor(current.bands.length, current.maxGain);
    var next = current.copyWith(enabled: true);
    for (var i = 0; i < gains.length; i++) {
      next = next.withBandGain(current.bands[i].index, gains[i]);
    }
    state = AsyncData(next);
    await _port.setEnabled(true);
    for (final band in next.bands) {
      await _port.setBandGain(band.index, band.gain);
    }
    await _save();
  }

  Future<void> _save() async {
    final current = state.valueOrNull;
    if (current == null) return;
    try {
      await ref.read(preferencesStoreProvider).write(
            equalizerPreferenceKey,
            jsonEncode({'enabled': current.enabled, 'gains': current.gains}),
          );
    } catch (_) {
      // Best effort: the sound already changed.
    }
  }
}
