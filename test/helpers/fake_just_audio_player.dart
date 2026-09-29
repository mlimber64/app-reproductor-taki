import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:taki/core/domain/entities/song.dart';

/// `AudioPlayer` falso que imita cómo just_audio mantiene la lista de fuentes,
/// el índice actual y el [ShuffleOrder] al añadir, quitar y mover. Registra
/// en [log] las llamadas que cambian la reproducción.
class FakeJustAudioPlayer extends Mock implements AudioPlayer {
  final List<AudioSource> sources = [];
  final List<String> log = [];
  final errors = StreamController<PlayerException>.broadcast();
  final processing = StreamController<ProcessingState>.broadcast();

  /// Como el reproductor real, avisa tras cada cambio de índice/posición.
  final _changes = StreamController<bool>.broadcast();

  ShuffleOrder _shuffleOrder = DefaultShuffleOrder();
  int? _currentIndex;
  bool _shuffleEnabled = false;
  LoopMode _loopMode = LoopMode.off;
  Duration fakePosition = Duration.zero;

  /// Canciones en el orden de las fuentes.
  List<Song> get sourceSongs =>
      [for (final source in sources) (source as UriAudioSource).tag as Song];

  Future<void> close() async {
    await errors.close();
    await processing.close();
    await _changes.close();
  }

  @override
  Stream<PlaybackEvent> get playbackEventStream => const Stream.empty();
  @override
  Stream<bool> get playingStream => _changes.stream;
  @override
  Stream<bool> get shuffleModeEnabledStream => const Stream.empty();
  @override
  Stream<LoopMode> get loopModeStream => const Stream.empty();
  @override
  Stream<PlayerException> get errorStream => errors.stream;
  @override
  Stream<ProcessingState> get processingStateStream => processing.stream;
  @override
  Stream<Duration> get positionStream => const Stream.empty();

  @override
  ProcessingState get processingState => ProcessingState.ready;
  @override
  int? get currentIndex => _currentIndex;
  @override
  bool get playing => false;
  @override
  Duration get position => fakePosition;
  @override
  Duration? get duration => null;
  @override
  bool get shuffleModeEnabled => _shuffleEnabled;
  @override
  LoopMode get loopMode => _loopMode;

  @override
  Future<Duration?> setAudioSources(
    List<AudioSource> audioSources, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
    ShuffleOrder? shuffleOrder,
  }) async {
    sources
      ..clear()
      ..addAll(audioSources);
    _shuffleOrder = shuffleOrder ?? DefaultShuffleOrder();
    _shuffleOrder
      ..clear()
      ..insert(0, audioSources.length);
    _currentIndex = audioSources.isEmpty ? null : (initialIndex ?? 0);
    log.add('setAudioSources(${audioSources.length})');
    return null;
  }

  @override
  Future<void> addAudioSources(List<AudioSource> audioSources) async {
    final index = sources.length;
    sources.addAll(audioSources);
    _shuffleOrder.insert(index, audioSources.length);
    log.add('addAudioSources(${audioSources.length})');
  }

  @override
  Future<void> insertAudioSources(
    int index,
    List<AudioSource> audioSources,
  ) async {
    sources.insertAll(index, audioSources);
    _shuffleOrder.insert(index, audioSources.length);
    if (_currentIndex != null && _currentIndex! >= index) {
      _currentIndex = _currentIndex! + audioSources.length;
    }
    log.add('insertAudioSources($index, ${audioSources.length})');
  }

  @override
  Future<void> removeAudioSourceAt(int index) async {
    await removeAudioSourceRange(index, index + 1);
  }

  @override
  Future<void> removeAudioSourceRange(int start, int end) async {
    final current = _currentIndex;
    if (current != null && current >= start && current < end) {
      throw StateError('El adapter no debe quitar la canción actual');
    }
    sources.removeRange(start, end);
    _shuffleOrder.removeRange(start, end);
    if (current != null && current >= end) _currentIndex = current - (end - start);
    log.add('removeAudioSourceRange($start, $end)');
  }

  @override
  Future<void> moveAudioSource(int currentIndex, int newIndex) async {
    sources.insert(newIndex, sources.removeAt(currentIndex));
    _shuffleOrder
      ..removeRange(currentIndex, currentIndex + 1)
      ..insert(newIndex, 1);
    final current = _currentIndex;
    if (current != null) {
      if (current == currentIndex) {
        _currentIndex = newIndex;
      } else if (currentIndex < current && newIndex >= current) {
        _currentIndex = current - 1;
      } else if (currentIndex > current && newIndex <= current) {
        _currentIndex = current + 1;
      }
    }
    log.add('moveAudioSource($currentIndex, $newIndex)');
  }

  @override
  Future<void> shuffle() async {
    _shuffleOrder.shuffle(initialIndex: _currentIndex);
    log.add('shuffle');
  }

  @override
  Future<void> setShuffleModeEnabled(bool enabled) async {
    _shuffleEnabled = enabled;
  }

  @override
  Future<void> setLoopMode(LoopMode mode) async => _loopMode = mode;

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    if (index != null) _currentIndex = index;
    fakePosition = position ?? Duration.zero;
    log.add('seek(${position?.inSeconds}s, index: $index)');
    _changes.add(false);
  }

  @override
  Future<void> play() async => log.add('play');

  @override
  Future<void> pause() async => log.add('pause');

  @override
  Future<void> stop() async => log.add('stop');
}
