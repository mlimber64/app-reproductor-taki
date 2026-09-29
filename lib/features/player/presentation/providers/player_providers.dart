import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entities/song.dart';
import '../../domain/entities/playback_state.dart';
import '../../domain/ports/audio_player_port.dart';
import '../../domain/ports/notification_permission_port.dart';
import '../../domain/usecases/player_usecases.dart';
import '../../infrastructure/permission_handler_notification_permission.dart';
import '../../infrastructure/taki_audio_handler.dart';

// El motor y el handler se crean en `main.dart` con `initPlayer()` (deben
// existir antes de runApp) y se inyectan con overrides.

final audioPlayerPortProvider = Provider<AudioPlayerPort>(
  (ref) => throw UnimplementedError(
    'audioPlayerPortProvider se sobrescribe en main.dart',
  ),
);

final audioHandlerProvider = Provider<TakiAudioHandler>(
  (ref) => throw UnimplementedError(
    'audioHandlerProvider se sobrescribe en main.dart',
  ),
);

final notificationPermissionProvider = Provider<NotificationPermissionPort>(
  (ref) => PermissionHandlerNotificationPermission(),
);

// Los streams del port no repiten el último valor: se emite primero el estado
// actual para que un widget que se suscribe tarde (p. ej. Reproduciendo) no
// quede vacío hasta el próximo evento.

final playbackStateProvider = StreamProvider<PlaybackState>((ref) {
  final player = ref.watch(audioPlayerPortProvider);
  return _startWithCurrent(player.playbackState, () => player.state);
});

final positionProvider = StreamProvider<Duration>((ref) {
  final player = ref.watch(audioPlayerPortProvider);
  return _startWithCurrent(player.position, () => player.state.position);
});

final currentSongProvider = StreamProvider<Song?>((ref) {
  final player = ref.watch(audioPlayerPortProvider);
  return _startWithCurrent(player.currentSong, () => player.state.currentSong);
});

/// [updates] precedido del valor actual. Se suscribe antes de emitir el valor
/// inicial para no perder eventos entre ambos.
Stream<T> _startWithCurrent<T>(Stream<T> updates, T Function() current) {
  StreamSubscription<T>? subscription;
  late final StreamController<T> controller;
  controller = StreamController<T>(
    onListen: () {
      subscription = updates.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.add(current());
    },
    onPause: () => subscription?.pause(),
    onResume: () => subscription?.resume(),
    onCancel: () => subscription?.cancel(),
  );
  return controller.stream;
}

final playSongsProvider = Provider<PlaySongs>(
  (ref) => PlaySongs(ref.watch(audioPlayerPortProvider)),
);

final playSongsShuffledProvider = Provider<PlaySongsShuffled>(
  (ref) => PlaySongsShuffled(ref.watch(audioPlayerPortProvider)),
);

final togglePlayPauseProvider = Provider<TogglePlayPause>(
  (ref) => TogglePlayPause(ref.watch(audioPlayerPortProvider)),
);

final skipNextProvider = Provider<SkipNext>(
  (ref) => SkipNext(ref.watch(audioPlayerPortProvider)),
);

final skipPreviousProvider = Provider<SkipPrevious>(
  (ref) => SkipPrevious(ref.watch(audioPlayerPortProvider)),
);

final seekProvider = Provider<Seek>(
  (ref) => Seek(ref.watch(audioPlayerPortProvider)),
);

final toggleShuffleProvider = Provider<ToggleShuffle>(
  (ref) => ToggleShuffle(ref.watch(audioPlayerPortProvider)),
);

final cycleRepeatModeProvider = Provider<CycleRepeatMode>(
  (ref) => CycleRepeatMode(ref.watch(audioPlayerPortProvider)),
);

final skipToQueueItemProvider = Provider<SkipToQueueItem>(
  (ref) => SkipToQueueItem(ref.watch(audioPlayerPortProvider)),
);

final removeFromQueueProvider = Provider<RemoveFromQueue>(
  (ref) => RemoveFromQueue(ref.watch(audioPlayerPortProvider)),
);

final moveInQueueProvider = Provider<MoveInQueue>(
  (ref) => MoveInQueue(ref.watch(audioPlayerPortProvider)),
);

final addToQueueProvider = Provider<AddToQueue>(
  (ref) => AddToQueue(ref.watch(audioPlayerPortProvider)),
);

final playNextProvider = Provider<PlayNext>(
  (ref) => PlayNext(ref.watch(audioPlayerPortProvider)),
);

final clearUpcomingProvider = Provider<ClearUpcoming>(
  (ref) => ClearUpcoming(ref.watch(audioPlayerPortProvider)),
);
