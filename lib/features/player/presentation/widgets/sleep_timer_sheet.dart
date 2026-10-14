import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/taki_colors.dart';
import '../../../../core/theme/taki_spacing.dart';
import '../../../../core/theme/taki_typography.dart';
import '../../domain/entities/sleep_timer_state.dart';
import '../providers/sleep_timer_providers.dart';

/// Texts of the sleep timer.
abstract final class SleepTimerTexts {
  static const String title = 'Temporizador';
  static const String endOfTrack = 'Al terminar la canción';
  static const String cancel = 'Desactivar temporizador';
  static const String active = 'Activo';

  static String minutes(int value) => '$value minutos';
}

/// `12:05` for a countdown.
String formatCountdown(Duration value) {
  final total = value.inSeconds < 0 ? 0 : value.inSeconds;
  final minutes = total ~/ 60;
  final seconds = total % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// Opens the sleep timer picker.
Future<void> showSleepTimerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: TakiColors.surfaceElevated,
    showDragHandle: true,
    builder: (_) => const SleepTimerSheet(),
  );
}

class SleepTimerSheet extends ConsumerWidget {
  const SleepTimerSheet({super.key});

  static const List<int> _options = [15, 30, 45, 60];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sleepTimerProvider);
    final timer = ref.read(sleepTimerProvider.notifier);

    void choose(VoidCallback start) {
      start();
      Navigator.of(context).pop();
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TakiSpacing.pageGutter,
              0,
              TakiSpacing.pageGutter,
              TakiSpacing.sm,
            ),
            child: Semantics(
              header: true,
              child: Text(
                SleepTimerTexts.title,
                style: TakiTypography.titleMedium.copyWith(
                  color: TakiColors.textPrimary,
                ),
              ),
            ),
          ),
          for (final minutes in _options)
            ListTile(
              leading: const Icon(Icons.bedtime_outlined),
              title: Text(SleepTimerTexts.minutes(minutes)),
              selected: state.remaining != null &&
                  state.remaining!.inMinutes + 1 >= minutes &&
                  state.remaining!.inMinutes < minutes,
              onTap: () =>
                  choose(() => timer.startAfter(Duration(minutes: minutes))),
            ),
          ListTile(
            leading: const Icon(Icons.skip_next_rounded),
            title: const Text(SleepTimerTexts.endOfTrack),
            selected: state.atEndOfTrack,
            onTap: () => choose(timer.startAtEndOfTrack),
          ),
          if (state.isActive)
            ListTile(
              leading: const Icon(Icons.timer_off_outlined),
              title: const Text(SleepTimerTexts.cancel),
              subtitle: Text(
                state.remaining != null
                    ? 'Quedan ${formatCountdown(state.remaining!)}'
                    : SleepTimerTexts.endOfTrack,
              ),
              onTap: () => choose(timer.cancel),
            ),
          const SizedBox(height: TakiSpacing.sm),
        ],
      ),
    );
  }
}

/// The label shown on the Now Playing action while the timer runs.
String? sleepTimerBadge(SleepTimerState state) {
  final remaining = state.remaining;
  if (remaining != null) return formatCountdown(remaining);
  if (state.atEndOfTrack) return SleepTimerTexts.active;
  return null;
}
