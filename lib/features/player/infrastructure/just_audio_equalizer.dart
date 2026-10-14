import 'package:just_audio/just_audio.dart';

import '../domain/entities/equalizer.dart';
import '../domain/ports/equalizer_port.dart';

/// [EqualizerPort] over just_audio's `AndroidEqualizer`.
///
/// The platform only reports the bands after the player is first activated, so
/// the parameters are picked up when they arrive and [load] answers `null`
/// until then.
class JustAudioEqualizer implements EqualizerPort {
  JustAudioEqualizer(this._equalizer) {
    _equalizer.parameters.then<void>(
      (value) => _parameters = value,
      // Unsupported device: stays unavailable.
      onError: (Object _) {},
    );
  }

  final AndroidEqualizer _equalizer;
  AndroidEqualizerParameters? _parameters;

  @override
  Future<EqualizerState?> load() async {
    final parameters = _parameters;
    if (parameters == null) return null;
    return EqualizerState(
      enabled: _equalizer.enabled,
      minGain: parameters.minDecibels,
      maxGain: parameters.maxDecibels,
      bands: [
        for (final band in parameters.bands)
          EqualizerBand(
            index: band.index,
            centerFrequencyHz: band.centerFrequency,
            gain: band.gain,
          ),
      ],
    );
  }

  @override
  Future<void> setEnabled(bool enabled) => _equalizer.setEnabled(enabled);

  @override
  Future<void> setBandGain(int index, double gain) async {
    final parameters = _parameters;
    if (parameters == null) return;
    for (final band in parameters.bands) {
      if (band.index == index) {
        await band.setGain(gain);
        return;
      }
    }
  }
}
