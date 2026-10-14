import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/ports/preferences_store.dart';
import 'package:taki/core/preferences/preferences_providers.dart';
import 'package:taki/features/player/domain/entities/equalizer.dart';
import 'package:taki/features/player/domain/ports/equalizer_port.dart';
import 'package:taki/features/player/presentation/providers/equalizer_providers.dart';
import 'package:taki/features/player/presentation/providers/player_providers.dart';
import 'package:taki/features/player/presentation/widgets/equalizer_sheet.dart';

import '../../../helpers/player_fakes.dart';

class _MemoryPreferences implements PreferencesStore {
  final Map<String, String> values = {};
  bool failing = false;

  @override
  Future<String?> read(String key) async {
    if (failing) throw StateError('db');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failing) throw StateError('db');
    values[key] = value;
  }
}

class _FakeEqualizer implements EqualizerPort {
  bool available = true;
  bool enabled = false;
  final List<double> gains = [0, 0, 0, 0, 0];
  final List<String> calls = [];

  @override
  Future<EqualizerState?> load() async {
    if (!available) return null;
    return EqualizerState(
      enabled: enabled,
      minGain: -15,
      maxGain: 15,
      bands: [
        for (var i = 0; i < gains.length; i++)
          EqualizerBand(
            index: i,
            centerFrequencyHz: 60.0 * (i + 1) * (i + 1),
            gain: gains[i],
          ),
      ],
    );
  }

  @override
  Future<void> setEnabled(bool value) async {
    calls.add('enabled($value)');
    enabled = value;
  }

  @override
  Future<void> setBandGain(int index, double gain) async {
    calls.add('gain($index, $gain)');
    gains[index] = gain;
  }
}

void main() {
  group('EqualizerPreset', () {
    test('a flat preset is zero everywhere', () {
      expect(equalizerPresets.first.gainsFor(5, 15), everyElement(0));
    });

    test('the curve is scaled by the maximum gain', () {
      const preset = EqualizerPreset('x', [1, 1, 1, 1, 1]);

      expect(preset.gainsFor(3, 12), [12, 12, 12]);
    });

    test('the curve is interpolated over any number of bands', () {
      const preset = EqualizerPreset('ramp', [0, 0.25, 0.5, 0.75, 1]);

      final gains = preset.gainsFor(9, 10);

      expect(gains.first, 0);
      expect(gains.last, 10);
      expect(gains, orderedEquals([...gains]..sort()));
      expect(gains.length, 9);
    });

    test('a single band uses the middle of the curve', () {
      const preset = EqualizerPreset('x', [0, 0, 1, 0, 0]);

      expect(preset.gainsFor(1, 10), [10]);
      expect(preset.gainsFor(0, 10), isEmpty);
    });
  });

  group('EqualizerState', () {
    test('withBandGain clamps to the device range', () {
      const state = EqualizerState(
        enabled: true,
        minGain: -10,
        maxGain: 10,
        bands: [EqualizerBand(index: 0, centerFrequencyHz: 60, gain: 0)],
      );

      expect(state.withBandGain(0, 99).gains, [10]);
      expect(state.withBandGain(0, -99).gains, [-10]);
      expect(state.withBandGain(7, 5).gains, [0], reason: 'unknown band');
    });
  });

  group('equalizerProvider', () {
    late _FakeEqualizer port;
    late _MemoryPreferences preferences;
    late FakeAudioPlayerPort player;

    ProviderContainer build() {
      final container = ProviderContainer(overrides: [
        equalizerPortProvider.overrideWithValue(port),
        preferencesStoreProvider.overrideWithValue(preferences),
        audioPlayerPortProvider.overrideWithValue(player),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    setUp(() {
      port = _FakeEqualizer();
      preferences = _MemoryPreferences();
      player = FakeAudioPlayerPort();
    });

    test('loads the engine state when there is nothing saved', () async {
      final container = build();

      final state = await container.read(equalizerProvider.future);

      expect(state!.bands, hasLength(5));
      expect(state.enabled, isFalse);
      expect(port.calls, isEmpty);
    });

    test('is null while the engine does not report its bands', () async {
      port.available = false;
      final container = build();

      expect(await container.read(equalizerProvider.future), isNull);
    });

    test('applies the saved settings to the engine', () async {
      preferences.values[equalizerPreferenceKey] =
          jsonEncode({'enabled': true, 'gains': [3.0, 2.0, 1.0, 0.0, -1.0]});
      final container = build();

      final state = await container.read(equalizerProvider.future);

      expect(state!.enabled, isTrue);
      expect(state.gains, [3, 2, 1, 0, -1]);
      expect(port.enabled, isTrue);
      expect(port.gains, [3, 2, 1, 0, -1]);
    });

    test('saved gains for another number of bands are ignored', () async {
      preferences.values[equalizerPreferenceKey] =
          jsonEncode({'enabled': true, 'gains': [1.0, 2.0]});
      final container = build();

      final state = await container.read(equalizerProvider.future);

      expect(state!.enabled, isTrue);
      expect(state.gains, everyElement(0));
    });

    test('a broken saved value falls back to the engine state', () async {
      preferences.values[equalizerPreferenceKey] = 'not json';
      final container = build();

      final state = await container.read(equalizerProvider.future);

      expect(state!.enabled, isFalse);
    });

    test('a preferences failure does not break the equalizer', () async {
      preferences.failing = true;
      final container = build();

      final state = await container.read(equalizerProvider.future);

      expect(state, isNotNull);
      await container.read(equalizerProvider.notifier).setEnabled(true);
      expect(port.enabled, isTrue);
    });

    test('setEnabled changes the engine and saves', () async {
      final container = build();
      await container.read(equalizerProvider.future);

      await container.read(equalizerProvider.notifier).setEnabled(true);

      expect(port.enabled, isTrue);
      expect(container.read(equalizerProvider).value!.enabled, isTrue);
      expect(jsonDecode(preferences.values[equalizerPreferenceKey]!)['enabled'],
          isTrue);
    });

    test('a band moves immediately and is saved on commit', () async {
      final container = build();
      await container.read(equalizerProvider.future);
      final controller = container.read(equalizerProvider.notifier);

      await controller.setBandGain(2, 7.5);
      expect(port.gains[2], 7.5);
      expect(preferences.values, isEmpty, reason: 'saved once per gesture');

      await controller.commit();
      expect(jsonDecode(preferences.values[equalizerPreferenceKey]!)['gains'][2],
          7.5);
    });

    test('a gain beyond the range is clamped', () async {
      final container = build();
      await container.read(equalizerProvider.future);

      await container.read(equalizerProvider.notifier).setBandGain(0, 99);

      expect(port.gains[0], 15);
    });

    test('a preset turns the equalizer on and sets every band', () async {
      final container = build();
      await container.read(equalizerProvider.future);

      await container
          .read(equalizerProvider.notifier)
          .applyPreset(equalizerPresets[1]);

      expect(port.enabled, isTrue);
      expect(port.gains.first, greaterThan(port.gains.last));
      expect(preferences.values, contains(equalizerPreferenceKey));
    });
  });

  group('formatFrequency', () {
    test('uses Hz and kHz', () {
      expect(formatFrequency(60), '60 Hz');
      expect(formatFrequency(999.6), '1000 Hz');
      expect(formatFrequency(4000), '4 kHz');
      expect(formatFrequency(14000.4), '14 kHz');
      expect(formatFrequency(2500), '2.5 kHz');
    });
  });
}
