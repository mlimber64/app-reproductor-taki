import 'package:equatable/equatable.dart';

/// One frequency band of the equalizer.
class EqualizerBand extends Equatable {
  const EqualizerBand({
    required this.index,
    required this.centerFrequencyHz,
    required this.gain,
  });

  final int index;
  final double centerFrequencyHz;

  /// Gain in decibels, within [EqualizerState.minGain]…[EqualizerState.maxGain].
  final double gain;

  EqualizerBand withGain(double value) => EqualizerBand(
        index: index,
        centerFrequencyHz: centerFrequencyHz,
        gain: value,
      );

  @override
  List<Object?> get props => [index, centerFrequencyHz, gain];
}

/// What the engine's equalizer currently does.
class EqualizerState extends Equatable {
  const EqualizerState({
    required this.enabled,
    required this.minGain,
    required this.maxGain,
    required this.bands,
  });

  final bool enabled;
  final double minGain;
  final double maxGain;
  final List<EqualizerBand> bands;

  EqualizerState copyWith({bool? enabled, List<EqualizerBand>? bands}) =>
      EqualizerState(
        enabled: enabled ?? this.enabled,
        minGain: minGain,
        maxGain: maxGain,
        bands: bands ?? this.bands,
      );

  /// The same state with band [index] set to [gain], clamped to the range.
  EqualizerState withBandGain(int index, double gain) => copyWith(bands: [
        for (final band in bands)
          band.index == index ? band.withGain(clampGain(gain)) : band,
      ]);

  double clampGain(double gain) => gain.clamp(minGain, maxGain).toDouble();

  /// Gains by band, in band order (what gets persisted).
  List<double> get gains => [for (final band in bands) band.gain];

  @override
  List<Object?> get props => [enabled, minGain, maxGain, bands];
}

/// A named curve, independent of how many bands the device has.
///
/// [curve] has five points, from the lowest to the highest frequencies, each
/// as a fraction of the maximum gain (−1…1). They are interpolated over the
/// device's bands, so the same preset works on a 5- or a 10-band equalizer.
class EqualizerPreset extends Equatable {
  const EqualizerPreset(this.name, this.curve);

  final String name;
  final List<double> curve;

  /// The gain of each of [bandCount] bands for a device with [maxGain].
  List<double> gainsFor(int bandCount, double maxGain) {
    if (bandCount <= 0) return const [];
    return [
      for (var i = 0; i < bandCount; i++)
        _at(bandCount == 1 ? 0.5 : i / (bandCount - 1)) * maxGain,
    ];
  }

  double _at(double t) {
    final scaled = t * (curve.length - 1);
    final low = scaled.floor().clamp(0, curve.length - 1);
    final high = (low + 1).clamp(0, curve.length - 1);
    final fraction = scaled - low;
    return curve[low] + (curve[high] - curve[low]) * fraction;
  }

  @override
  List<Object?> get props => [name, curve];
}

/// Presets offered by Taki.
const List<EqualizerPreset> equalizerPresets = [
  EqualizerPreset('Plano', [0, 0, 0, 0, 0]),
  EqualizerPreset('Más graves', [0.8, 0.5, 0.1, 0, 0]),
  EqualizerPreset('Más agudos', [0, 0, 0.1, 0.5, 0.8]),
  EqualizerPreset('Voz', [-0.3, 0, 0.5, 0.4, -0.1]),
  EqualizerPreset('Rock', [0.5, 0.2, -0.2, 0.2, 0.5]),
];
