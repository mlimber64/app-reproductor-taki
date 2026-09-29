import 'dart:async';

import 'package:audio_service/audio_service.dart';

import '../../library/domain/entities/song.dart';
import '../domain/entities/playback_state.dart' as player;
import '../domain/ports/audio_player_port.dart';
import 'artwork_file_cache.dart';

/// Puente entre audio_service (notificación, pantalla de bloqueo, auriculares,
/// Bluetooth) y el [AudioPlayerPort].
///
/// Refleja el estado del port en audio_service y le reenvía los comandos del
/// sistema. Los botones de auriculares/Bluetooth llegan como [click],
/// [skipToNext] y [skipToPrevious] (implementación de [BaseAudioHandler]).
class TakiAudioHandler extends BaseAudioHandler {
  TakiAudioHandler(this._player, this._artworkFiles) {
    _subscriptions.addAll([
      _player.playbackState.listen(_publishPlaybackState),
      _player.currentSong.listen(_publishMediaItem),
    ]);
    _publishPlaybackState(_player.state);
  }

  final AudioPlayerPort _player;
  final ArtworkFileCache _artworkFiles;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.skipToNext();

  @override
  Future<void> skipToPrevious() => _player.skipToPrevious();

  @override
  Future<void> skipToQueueItem(int index) => _player.skipToIndex(index);

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) =>
      _player.setShuffle(shuffleMode != AudioServiceShuffleMode.none);

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) {
    return _player.setRepeatMode(switch (repeatMode) {
      AudioServiceRepeatMode.none => player.RepeatMode.off,
      AudioServiceRepeatMode.one => player.RepeatMode.one,
      AudioServiceRepeatMode.all ||
      AudioServiceRepeatMode.group =>
        player.RepeatMode.all,
    });
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop(); // Pasa a idle y retira la notificación.
  }

  /// La app se cerró desde recientes: si no suena nada, liberar el servicio.
  @override
  Future<void> onTaskRemoved() async {
    if (!_player.state.isPlaying) await stop();
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
  }

  void _publishPlaybackState(player.PlaybackState state) {
    final hasSong = state.currentSong != null;
    // "Anterior" siempre está (sin canción previa reinicia la actual).
    // "Siguiente" solo si hay algo después (o repetir todo).
    final controls = [
      if (hasSong) MediaControl.skipToPrevious,
      state.isPlaying ? MediaControl.pause : MediaControl.play,
      if (state.hasNext) MediaControl.skipToNext,
    ];

    playbackState.add(
      PlaybackState(
        controls: controls,
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.skipToQueueItem,
        },
        androidCompactActionIndices: [
          for (var i = 0; i < controls.length; i++) i,
        ],
        processingState: !hasSong
            ? AudioProcessingState.idle
            : state.isBuffering
                ? AudioProcessingState.buffering
                : AudioProcessingState.ready,
        playing: state.isPlaying,
        updatePosition: state.position,
        speed: 1,
        queueIndex: state.currentIndex,
        shuffleMode: state.shuffleEnabled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        repeatMode: switch (state.repeatMode) {
          player.RepeatMode.off => AudioServiceRepeatMode.none,
          player.RepeatMode.all => AudioServiceRepeatMode.all,
          player.RepeatMode.one => AudioServiceRepeatMode.one,
        },
      ),
    );
  }

  Future<void> _publishMediaItem(Song? song) async {
    if (song == null) {
      mediaItem.add(null);
      return;
    }

    final item = _toMediaItem(song);
    mediaItem.add(item);

    // La carátula llega después para no retrasar la notificación.
    final artUri = await _artworkFiles.artUriFor(song);
    if (artUri != null && mediaItem.value?.id == item.id) {
      mediaItem.add(item.copyWith(artUri: artUri));
    }
  }

  static MediaItem _toMediaItem(Song song) {
    return MediaItem(
      id: song.contentUri,
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: song.durationMs > 0 ? song.duration : null,
    );
  }
}
