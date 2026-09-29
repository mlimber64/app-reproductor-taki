import '../../../../core/domain/entities/song.dart';
import '../entities/playback_error.dart';
import '../entities/playback_state.dart';

/// Motor de reproducción.
abstract interface class AudioPlayerPort {
  /// Último estado emitido (para leerlo sin suscribirse).
  PlaybackState get state;

  Stream<PlaybackState> get playbackState;
  Stream<Duration> get position;
  Stream<Song?> get currentSong;

  /// Canciones que fallaron. La cola sigue con la siguiente.
  Stream<PlaybackError> get errors;

  Future<void> setQueue(List<Song> songs, {int startIndex = 0});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> skipToNext();
  Future<void> skipToPrevious();
  Future<void> skipToIndex(int index);
  Future<void> setShuffle(bool enabled);
  Future<void> setRepeatMode(RepeatMode mode);
  Future<void> stop();

  // Edición de la cola. Los índices son los de [PlaybackState.queue] (la cola
  // real, en orden de reproducción). Solo se aceptan índices de lo que viene
  // después de la canción actual; el resto se ignora sin error.

  /// Quita la canción en [index].
  Future<void> removeFromQueue(int index);

  /// Mueve la canción de [oldIndex] para que quede en [newIndex] (posición
  /// final, como `List.insert` tras quitarla).
  Future<void> moveInQueue(int oldIndex, int newIndex);

  /// Añade [songs] al final de la cola.
  Future<void> addToQueue(List<Song> songs);

  /// Inserta [songs] justo después de la canción actual.
  Future<void> playNext(List<Song> songs);

  /// Quita todo lo que viene después de la canción actual. La actual sigue
  /// sonando.
  Future<void> clearUpcoming();
}
