import 'package:equatable/equatable.dart';

import '../../../../core/domain/entities/song.dart';

enum RepeatMode { off, all, one }

/// Estado del reproductor.
///
/// [queue] es la **cola real**: el orden en que se va a reproducir (con
/// aleatorio activo, el orden mezclado). Todos los índices del port se
/// refieren a esta lista.
///
/// [position] es la posición en el momento en que se emitió el estado (play,
/// pausa, seek, cambio de canción…); para seguirla en vivo usa el stream de
/// posición del port.
class PlaybackState extends Equatable {
  const PlaybackState({
    this.queue = const [],
    this.currentIndex,
    this.isPlaying = false,
    this.isBuffering = false,
    this.position = Duration.zero,
    this.duration,
    this.shuffleEnabled = false,
    this.repeatMode = RepeatMode.off,
  });

  static const PlaybackState empty = PlaybackState();

  /// Cola en orden de reproducción. Cada cambio llega como una lista nueva.
  final List<Song> queue;

  /// Posición de la canción actual en [queue].
  final int? currentIndex;
  final bool isPlaying;
  final bool isBuffering;
  final Duration position;
  final Duration? duration;
  final bool shuffleEnabled;
  final RepeatMode repeatMode;

  Song? get currentSong {
    final index = currentIndex;
    if (index == null || index < 0 || index >= queue.length) return null;
    return queue[index];
  }

  /// Primer índice de lo que viene después de la canción actual.
  int get upcomingStart => currentSong == null ? queue.length : currentIndex! + 1;

  /// Cuántas canciones vienen después de la actual.
  int get upcomingCount => queue.length - upcomingStart;

  /// Regla de la cola: solo se puede quitar o mover lo que viene después de
  /// la canción actual (ni la actual ni las ya reproducidas).
  bool isUpcoming(int index) => index >= upcomingStart && index < queue.length;

  /// Hay canción siguiente (con repetir todo, la cola vuelve al principio).
  bool get hasNext {
    if (currentSong == null) return false;
    return currentIndex! < queue.length - 1 ||
        (repeatMode == RepeatMode.all && queue.length > 1);
  }

  /// Hay canción anterior (con repetir todo, la cola vuelve al final).
  bool get hasPrevious {
    if (currentSong == null) return false;
    return currentIndex! > 0 ||
        (repeatMode == RepeatMode.all && queue.length > 1);
  }

  PlaybackState copyWith({
    List<Song>? queue,
    int? currentIndex,
    bool? isPlaying,
    bool? isBuffering,
    Duration? position,
    Duration? duration,
    bool? shuffleEnabled,
    RepeatMode? repeatMode,
  }) {
    return PlaybackState(
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      repeatMode: repeatMode ?? this.repeatMode,
    );
  }

  @override
  List<Object?> get props => [
        // Por identidad: comparar miles de canciones en cada emisión es caro.
        identityHashCode(queue),
        currentIndex,
        isPlaying,
        isBuffering,
        position,
        duration,
        shuffleEnabled,
        repeatMode,
      ];
}
