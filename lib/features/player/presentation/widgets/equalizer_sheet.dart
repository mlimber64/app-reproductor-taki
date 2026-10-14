import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/taki_colors.dart';
import '../../../../core/theme/taki_spacing.dart';
import '../../../../core/theme/taki_typography.dart';
import '../../domain/entities/equalizer.dart';
import '../providers/equalizer_providers.dart';

/// Texts of the equalizer.
abstract final class EqualizerTexts {
  static const String title = 'Ecualizador';
  static const String enabled = 'Activar ecualizador';
  static const String unavailable =
      'El ecualizador estará disponible cuando empiece a sonar una canción.';
  static const String presets = 'Ajustes preestablecidos';
}

/// `250 Hz` or `4 kHz`.
String formatFrequency(double hz) {
  if (hz >= 1000) {
    final khz = (hz / 100).round() / 10;
    final text = khz == khz.roundToDouble()
        ? khz.round().toString()
        : khz.toStringAsFixed(1);
    return '$text kHz';
  }
  return '${hz.round()} Hz';
}

/// Opens the equalizer.
Future<void> showEqualizerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: TakiColors.surfaceElevated,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const EqualizerSheet(),
  );
}

class EqualizerSheet extends ConsumerWidget {
  const EqualizerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final equalizer = ref.watch(equalizerProvider);
    final state = equalizer.valueOrNull;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          TakiSpacing.pageGutter,
          0,
          TakiSpacing.pageGutter,
          TakiSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                EqualizerTexts.title,
                style: TakiTypography.titleMedium.copyWith(
                  color: TakiColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: TakiSpacing.md),
            if (equalizer.isLoading && state == null)
              const Center(child: CircularProgressIndicator())
            else if (state == null)
              Text(
                EqualizerTexts.unavailable,
                style: TakiTypography.body.copyWith(
                  color: TakiColors.textSecondary,
                ),
              )
            else
              _Controls(state: state),
          ],
        ),
      ),
    );
  }
}

class _Controls extends ConsumerWidget {
  const _Controls({required this.state});

  final EqualizerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(equalizerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(EqualizerTexts.enabled),
          value: state.enabled,
          onChanged: controller.setEnabled,
        ),
        const SizedBox(height: TakiSpacing.sm),
        Text(
          EqualizerTexts.presets,
          style: TakiTypography.label.copyWith(color: TakiColors.textSecondary),
        ),
        const SizedBox(height: TakiSpacing.sm),
        Wrap(
          spacing: TakiSpacing.sm,
          children: [
            for (final preset in equalizerPresets)
              ActionChip(
                label: Text(preset.name),
                onPressed: () => controller.applyPreset(preset),
              ),
          ],
        ),
        const SizedBox(height: TakiSpacing.lg),
        SizedBox(
          height: 220,
          child: Row(
            children: [
              for (final band in state.bands)
                Expanded(
                  child: _BandSlider(
                    band: band,
                    min: state.minGain,
                    max: state.maxGain,
                    enabled: state.enabled,
                    onChanged: (gain) =>
                        controller.setBandGain(band.index, gain),
                    onChangeEnd: (_) => controller.commit(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BandSlider extends StatelessWidget {
  const _BandSlider({
    required this.band,
    required this.min,
    required this.max,
    required this.enabled,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final EqualizerBand band;
  final double min;
  final double max;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final label = formatFrequency(band.centerFrequencyHz);
    return Column(
      children: [
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: Semantics(
              label: 'Banda de $label',
              value: '${band.gain.toStringAsFixed(1)} dB',
              child: Slider(
                value: band.gain.clamp(min, max).toDouble(),
                min: min,
                max: max,
                onChanged: enabled ? onChanged : null,
                onChangeEnd: enabled ? onChangeEnd : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: TakiSpacing.xs),
        Text(
          label,
          maxLines: 1,
          style: TakiTypography.caption.copyWith(color: TakiColors.textMuted),
        ),
      ],
    );
  }
}
