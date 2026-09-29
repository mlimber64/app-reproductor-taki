import 'dart:math';

import '../../../library/domain/entities/song.dart';
import '../entities/playback_state.dart';
import '../ports/audio_player_port.dart';

/// Reemplaza la cola por [songs] y reproduce desde [index].
class PlaySongs {
  const PlaySongs(this._player);

  final AudioPlayerPort _player;

  Future<void> call(List<Song> songs, int index) async {
    await _player.setQueue(songs, startIndex: index);
    await _player.play();
  }
}

/// Activa aleatorio y reproduce [songs] empezando por una al azar.
class PlaySongsShuffled {
  PlaySongsShuffled(this._player, {Random? random})
      : _random = random ?? Random();

  final AudioPlayerPort _player;
  final Random _random;

  Future<void> call(List<Song> songs) async {
    if (songs.isEmpty) return;
    await _player.setShuffle(true);
    await _player.setQueue(songs, startIndex: _random.nextInt(songs.length));
    await _player.play();
  }
}

class TogglePlayPause {
  const TogglePlayPause(this._player);

  final AudioPlayerPort _player;

  Future<void> call() =>
      _player.state.isPlaying ? _player.pause() : _player.play();
}

class SkipNext {
  const SkipNext(this._player);

  final AudioPlayerPort _player;

  Future<void> call() => _player.skipToNext();
}

class SkipPrevious {
  const SkipPrevious(this._player);

  final AudioPlayerPort _player;

  Future<void> call() => _player.skipToPrevious();
}

class Seek {
  const Seek(this._player);

  final AudioPlayerPort _player;

  Future<void> call(Duration position) => _player.seek(position);
}

class ToggleShuffle {
  const ToggleShuffle(this._player);

  final AudioPlayerPort _player;

  Future<void> call() => _player.setShuffle(!_player.state.shuffleEnabled);
}

/// off → all → one → off.
class CycleRepeatMode {
  const CycleRepeatMode(this._player);

  final AudioPlayerPort _player;

  Future<void> call() {
    final next = switch (_player.state.repeatMode) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    return _player.setRepeatMode(next);
  }
}

/// Salta a la canción en [index] de la cola real.
class SkipToQueueItem {
  const SkipToQueueItem(this._player);

  final AudioPlayerPort _player;

  Future<void> call(int index) async {
    if (index < 0 || index >= _player.state.queue.length) return;
    await _player.skipToIndex(index);
  }
}

/// Quita una canción de lo que viene. Ignora la actual y las ya reproducidas.
class RemoveFromQueue {
  const RemoveFromQueue(this._player);

  final AudioPlayerPort _player;

  Future<void> call(int index) async {
    if (!_player.state.isUpcoming(index)) return;
    await _player.removeFromQueue(index);
  }
}

/// Reordena lo que viene. Origen y destino deben estar después de la actual.
class MoveInQueue {
  const MoveInQueue(this._player);

  final AudioPlayerPort _player;

  Future<void> call(int oldIndex, int newIndex) async {
    final state = _player.state;
    if (oldIndex == newIndex ||
        !state.isUpcoming(oldIndex) ||
        !state.isUpcoming(newIndex)) {
      return;
    }
    await _player.moveInQueue(oldIndex, newIndex);
  }
}

/// Añade al final. Si no suena nada, empieza por la primera añadida.
class AddToQueue {
  const AddToQueue(this._player);

  final AudioPlayerPort _player;

  Future<void> call(List<Song> songs) async {
    if (songs.isEmpty) return;
    if (_player.state.currentSong == null) {
      await PlaySongs(_player)(songs, 0);
    } else {
      await _player.addToQueue(songs);
    }
  }
}

/// Inserta después de la actual. Si no suena nada, empieza por la primera.
class PlayNext {
  const PlayNext(this._player);

  final AudioPlayerPort _player;

  Future<void> call(List<Song> songs) async {
    if (songs.isEmpty) return;
    if (_player.state.currentSong == null) {
      await PlaySongs(_player)(songs, 0);
    } else {
      await _player.playNext(songs);
    }
  }
}

/// Quita todo lo que viene después de la actual.
class ClearUpcoming {
  const ClearUpcoming(this._player);

  final AudioPlayerPort _player;

  Future<void> call() async {
    if (_player.state.upcomingCount == 0) return;
    await _player.clearUpcoming();
  }
}
