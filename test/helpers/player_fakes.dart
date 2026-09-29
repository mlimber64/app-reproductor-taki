import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:taki/features/library/domain/entities/song.dart';
import 'package:taki/features/player/domain/entities/playback_error.dart';
import 'package:taki/features/player/domain/entities/playback_state.dart';
import 'package:taki/features/player/domain/ports/audio_player_port.dart';
import 'package:taki/features/player/domain/ports/notification_permission_port.dart';
import 'package:taki/features/player/domain/usecases/player_usecases.dart';

class MockAudioPlayerPort extends Mock implements AudioPlayerPort {}

class MockPlaySongs extends Mock implements PlaySongs {}

class MockTogglePlayPause extends Mock implements TogglePlayPause {}

class MockPlaySongsShuffled extends Mock implements PlaySongsShuffled {}

class MockSeek extends Mock implements Seek {}

class MockRemoveFromQueue extends Mock implements RemoveFromQueue {}

class MockMoveInQueue extends Mock implements MoveInQueue {}

class MockAddToQueue extends Mock implements AddToQueue {}

class MockPlayNext extends Mock implements PlayNext {}

class MockClearUpcoming extends Mock implements ClearUpcoming {}

/// Port controlable desde el test: se le "inyectan" estados, posiciones y
/// errores, y registra los comandos recibidos en [calls]. Play/pausa,
/// aleatorio, repetir y la edición de la cola actualizan el estado como lo
/// haría el motor real (con las mismas reglas: solo se edita lo que viene).
class FakeAudioPlayerPort implements AudioPlayerPort {
  final _states = StreamController<PlaybackState>.broadcast();
  final _positions = StreamController<Duration>.broadcast();
  final _songs = StreamController<Song?>.broadcast();
  final _errors = StreamController<PlaybackError>.broadcast();

  final List<String> calls = [];
  PlaybackState _state = PlaybackState.empty;

  void emitState(PlaybackState state) {
    _state = state;
    _states.add(state);
    _songs.add(state.currentSong);
  }

  void emitError(PlaybackError error) => _errors.add(error);

  void emitPosition(Duration position) => _positions.add(position);

  @override
  PlaybackState get state => _state;

  @override
  Stream<PlaybackState> get playbackState => _states.stream;

  @override
  Stream<Duration> get position => _positions.stream;

  @override
  Stream<Song?> get currentSong => _songs.stream;

  @override
  Stream<PlaybackError> get errors => _errors.stream;

  @override
  Future<void> setQueue(List<Song> songs, {int startIndex = 0}) async =>
      calls.add('setQueue(${songs.length}, $startIndex)');

  @override
  Future<void> play() async {
    calls.add('play');
    emitState(_state.copyWith(isPlaying: true));
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    emitState(_state.copyWith(isPlaying: false));
  }

  @override
  Future<void> seek(Duration position) async =>
      calls.add('seek(${position.inSeconds}s)');

  @override
  Future<void> skipToNext() async => calls.add('skipToNext');

  @override
  Future<void> skipToPrevious() async => calls.add('skipToPrevious');

  @override
  Future<void> skipToIndex(int index) async => calls.add('skipToIndex($index)');

  @override
  Future<void> setShuffle(bool enabled) async {
    calls.add('setShuffle($enabled)');
    emitState(_state.copyWith(shuffleEnabled: enabled));
  }

  @override
  Future<void> setRepeatMode(RepeatMode mode) async {
    calls.add('setRepeatMode(${mode.name})');
    emitState(_state.copyWith(repeatMode: mode));
  }

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> removeFromQueue(int index) async {
    calls.add('removeFromQueue($index)');
    if (!_state.isUpcoming(index)) return;
    _emitQueue(List.of(_state.queue)..removeAt(index));
  }

  @override
  Future<void> moveInQueue(int oldIndex, int newIndex) async {
    calls.add('moveInQueue($oldIndex, $newIndex)');
    if (!_state.isUpcoming(oldIndex) || !_state.isUpcoming(newIndex)) return;
    final queue = List.of(_state.queue);
    queue.insert(newIndex, queue.removeAt(oldIndex));
    _emitQueue(queue);
  }

  @override
  Future<void> addToQueue(List<Song> songs) async {
    calls.add('addToQueue(${songs.length})');
    _emitQueue([..._state.queue, ...songs]);
  }

  @override
  Future<void> playNext(List<Song> songs) async {
    calls.add('playNext(${songs.length})');
    _emitQueue(List.of(_state.queue)..insertAll(_state.upcomingStart, songs));
  }

  @override
  Future<void> clearUpcoming() async {
    calls.add('clearUpcoming');
    _emitQueue(_state.queue.sublist(0, _state.upcomingStart));
  }

  void _emitQueue(List<Song> queue) =>
      emitState(_state.copyWith(queue: List.unmodifiable(queue)));
}

class FakeNotificationPermission implements NotificationPermissionPort {
  int requests = 0;

  @override
  Future<void> requestIfNeeded() async => requests++;
}
