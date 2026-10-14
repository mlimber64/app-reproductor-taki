import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../../../core/domain/entities/playback_resolution_exception.dart';
import '../../../core/domain/entities/playback_resource.dart';
import '../../../core/domain/entities/song.dart';
import '../../../core/domain/ports/playback_resolver.dart';
import '../../../core/domain/services/local_playback_resolver.dart';
import '../domain/entities/playback_error.dart';
import '../domain/entities/playback_state.dart';
import '../domain/ports/audio_player_port.dart';
import 'queue_shuffle_order.dart';

/// [AudioPlayerPort] sobre just_audio (ExoPlayer en Android).
///
/// - La cola es una lista de fuentes con preparación perezosa: solo se prepara
///   la canción actual y la siguiente, así que miles de canciones no bloquean.
/// - La reproducción es sin pausas entre canciones (gapless de ExoPlayer).
/// - Si una canción falla, se emite por [errors] y se salta a la siguiente,
///   sin tocar la cola. Tras varios fallos seguidos, pausa.
///
/// Dos órdenes:
/// - **Fuentes** ([_sources]): el orden de la lista de just_audio (orden
///   original, el que se ve con aleatorio desactivado).
/// - **Cola real** ([_queue]): el orden de reproducción. Sin aleatorio es igual
///   a las fuentes; con aleatorio sigue el [QueueShuffleOrder].
///
/// El port trabaja siempre con índices de la cola real; aquí se traducen a
/// índices de fuente. Añadir, quitar o mover usan las operaciones incrementales
/// de just_audio, que no recargan la cola ni cortan la canción actual.
///
/// Cómo se reproduce cada canción lo decide el [PlaybackResolver] (por defecto,
/// el local); este adaptador solo convierte el [PlaybackResource] a una fuente
/// de just_audio:
/// - [LocalUriResource] y [RemoteUriResource] → `AudioSource.uri`. HLS/DASH, si
///   algún día llegan como URI, los decide just_audio/ExoPlayer, no el dominio.
/// - [ProviderPlaybackResource] (motor propio, aún sin soporte) y
///   [UnavailableResource], o si la resolución falla → una fuente que **no se
///   puede reproducir**. La entrada se conserva en la cola (los índices siguen
///   coincidiendo con la cola del estado) y al llegar su turno falla por el
///   camino de siempre: se emite [PlaybackError] y se salta a la siguiente.
class JustAudioPlayerAdapter implements AudioPlayerPort {
  JustAudioPlayerAdapter({AudioPlayer? player, PlaybackResolver? resolver})
      : _player = player ?? AudioPlayer(useLazyPreparation: true),
        _resolver = resolver ?? const LocalPlaybackResolver() {
    _subscriptions.addAll([
      _player.playbackEventStream.listen(
        (_) => _emitState(),
        onError: (Object _) => _emitState(),
      ),
      _player.playingStream.listen((_) => _emitState()),
      _player.shuffleModeEnabledStream.listen((_) => _emitState()),
      _player.loopModeStream.listen((_) => _emitState()),
      _player.errorStream.listen(_onError),
      _player.processingStateStream.listen(_onProcessingState),
    ]);
  }

  /// Cuántas canciones rotas seguidas se saltan antes de pausar.
  static const int _maxConsecutiveSkips = 10;

  /// Antes de este punto, "anterior" va a la canción previa; después, reinicia.
  static const Duration _restartThreshold = Duration(seconds: 3);

  final AudioPlayer _player;
  final PlaybackResolver _resolver;
  final QueueShuffleOrder _shuffleOrder = QueueShuffleOrder();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  final StreamController<PlaybackState> _stateController =
      StreamController<PlaybackState>.broadcast();
  final StreamController<PlaybackError> _errorController =
      StreamController<PlaybackError>.broadcast();

  /// Canciones en el orden de las fuentes de just_audio.
  List<Song> _sources = const [];

  /// Cola real (orden de reproducción).
  List<Song> _queue = const [];

  /// Posición en la cola real → índice de fuente.
  List<int> _sourceAt = const [];

  /// Índice de fuente → posición en la cola real.
  List<int> _positionOf = const [];

  PlaybackState _state = PlaybackState.empty;
  int _consecutiveErrors = 0;

  /// Serializa las operaciones que cambian la cola para que dos toques
  /// rápidos no trabajen sobre un estado a medio actualizar.
  Future<void> _pending = Future.value();

  @override
  PlaybackState get state => _state;

  @override
  Stream<PlaybackState> get playbackState => _stateController.stream;

  @override
  Stream<Duration> get position => _player.positionStream;

  @override
  Stream<Song?> get currentSong =>
      playbackState.map((state) => state.currentSong).distinct();

  @override
  Stream<PlaybackError> get errors => _errorController.stream;

  @override
  Future<void> setQueue(List<Song> songs, {int startIndex = 0}) {
    return _serialized(() => _replaceQueue(songs, startIndex));
  }

  /// Cuerpo de [setQueue]. Solo se llama **dentro** de [_serialized].
  Future<void> _replaceQueue(List<Song> songs, int startIndex) async {
    _sources = List.unmodifiable(songs);
    if (songs.isEmpty) {
      await _player.stop();
      await _player.setAudioSources(const [], shuffleOrder: _shuffleOrder);
      _commitQueue();
      return;
    }

    await _player.setAudioSources(
      await _toSources(songs),
      initialIndex: startIndex.clamp(0, songs.length - 1),
      initialPosition: Duration.zero,
      // No cargar aquí: play() la carga. Así un archivo roto no hace fallar
      // setQueue, sino que se salta como cualquier otro error.
      preload: false,
      shuffleOrder: _shuffleOrder,
    );
    if (_player.shuffleModeEnabled) await _player.shuffle();
    _commitQueue();
  }

  @override
  Future<void> play() async {
    if (_queue.isEmpty) return;
    // El Future de just_audio.play() no termina hasta que se pausa; no lo
    // esperamos para no bloquear al llamador.
    unawaited(_player.play().catchError((Object _) {}));
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    final next = _relativePosition(1);
    if (next != null) await _seekToPosition(next);
  }

  @override
  Future<void> skipToPrevious() async {
    final previous = _relativePosition(-1);
    if (_player.position > _restartThreshold || previous == null) {
      await _player.seek(Duration.zero);
    } else {
      await _seekToPosition(previous);
    }
  }

  @override
  Future<void> skipToIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;
    await _seekToPosition(index);
  }

  @override
  Future<void> setShuffle(bool enabled) {
    return _serialized(() async {
      // shuffle() genera un orden nuevo que empieza por la canción actual.
      if (enabled) await _player.shuffle();
      await _player.setShuffleModeEnabled(enabled);
      _commitQueue();
    });
  }

  @override
  Future<void> setRepeatMode(RepeatMode mode) {
    return _player.setLoopMode(switch (mode) {
      RepeatMode.off => LoopMode.off,
      RepeatMode.all => LoopMode.all,
      RepeatMode.one => LoopMode.one,
    });
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> removeFromQueue(int index) {
    return _serialized(() async {
      if (!_isUpcoming(index)) return;
      final source = _sourceAt[index];
      await _player.removeAudioSourceAt(source);
      _sources = List.unmodifiable(List.of(_sources)..removeAt(source));
      _commitQueue();
    });
  }

  @override
  Future<void> moveInQueue(int oldIndex, int newIndex) {
    return _serialized(() async {
      if (oldIndex == newIndex ||
          !_isUpcoming(oldIndex) ||
          !_isUpcoming(newIndex)) {
        return;
      }

      if (_player.shuffleModeEnabled) {
        // El orden de las fuentes no cambia; solo el orden de reproducción.
        // move(i, i) hace que just_audio saque el índice del orden aleatorio y
        // lo vuelva a insertar donde indica placeNextInsertAt.
        final source = _sourceAt[oldIndex];
        _shuffleOrder.placeNextInsertAt(newIndex);
        await _player.moveAudioSource(source, source);
      } else {
        await _player.moveAudioSource(oldIndex, newIndex);
        final sources = List.of(_sources);
        sources.insert(newIndex, sources.removeAt(oldIndex));
        _sources = List.unmodifiable(sources);
      }
      _commitQueue();
    });
  }

  @override
  Future<void> addToQueue(List<Song> songs) {
    return _serialized(() async {
      // Con la cola vacía **en el momento de aplicarse** (no al pedirse): una
      // operación anterior aún pendiente puede estar llenándola.
      if (_sources.isEmpty) return _replaceQueue(songs, 0);
      if (songs.isEmpty) return;
      _shuffleOrder.placeNextInsertAt(null); // Al final del orden aleatorio.
      await _player.addAudioSources(await _toSources(songs));
      _sources = List.unmodifiable([..._sources, ...songs]);
      _commitQueue();
    });
  }

  @override
  Future<void> playNext(List<Song> songs) {
    return _serialized(() async {
      // Igual que en [addToQueue]: se decide con el estado ya actualizado.
      if (_sources.isEmpty || _currentPosition == null) {
        return _replaceQueue(songs, 0);
      }
      final position = _currentPosition;
      final source = _player.currentIndex;
      if (songs.isEmpty || position == null || source == null) return;
      // Justo después de la actual en ambos órdenes: en la cola real (vía el
      // orden aleatorio) y en las fuentes (por si luego se desactiva).
      _shuffleOrder.placeNextInsertAt(position + 1);
      await _player.insertAudioSources(source + 1, await _toSources(songs));
      _sources = List.unmodifiable(
        List.of(_sources)..insertAll(source + 1, songs),
      );
      _commitQueue();
    });
  }

  @override
  Future<void> clearUpcoming() {
    return _serialized(() async {
      final position = _currentPosition;
      if (position == null || position >= _queue.length - 1) return;

      final toRemove = _sourceAt.sublist(position + 1)..sort();
      // Con aleatorio las fuentes a quitar no son contiguas: se quitan por
      // tramos contiguos, de atrás hacia adelante para no desplazar índices.
      for (final (start, end) in _contiguousRuns(toRemove).reversed) {
        await _player.removeAudioSourceRange(start, end);
      }
      final removed = toRemove.toSet();
      _sources = List.unmodifiable([
        for (var i = 0; i < _sources.length; i++)
          if (!removed.contains(i)) _sources[i],
      ]);
      _commitQueue();
    });
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
    await _stateController.close();
    await _errorController.close();
  }

  Future<void> _serialized(Future<void> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.catchError((Object _) {});
    return result;
  }

  /// Esquema que nadie sabe reproducir: la fuente falla al cargar y el error
  /// sigue el camino de cualquier canción rota.
  static final Uri _unplayableUri = Uri(scheme: 'taki-unplayable');

  Future<List<AudioSource>> _toSources(List<Song> songs) =>
      Future.wait([for (final song in songs) _toSource(song)]);

  Future<AudioSource> _toSource(Song song) async {
    PlaybackResource resource;
    try {
      resource = await _resolver.resolve(song);
    } on PlaybackResolutionException catch (error) {
      resource = UnavailableResource(reason: error.toString());
    }

    return switch (resource) {
      LocalUriResource(:final uri) ||
      RemoteUriResource(:final uri) =>
        AudioSource.uri(Uri.parse(uri), tag: song),
      ProviderPlaybackResource() ||
      UnavailableResource() =>
        AudioSource.uri(_unplayableUri, tag: song),
    };
  }

  int? get _currentPosition {
    final source = _player.currentIndex;
    if (source == null || source < 0 || source >= _positionOf.length) {
      return null;
    }
    return _positionOf[source];
  }

  bool _isUpcoming(int index) {
    final position = _currentPosition;
    return position != null && index > position && index < _queue.length;
  }

  /// Posición vecina en la cola real; con repetir todo, da la vuelta.
  int? _relativePosition(int offset) {
    final position = _currentPosition;
    if (position == null || _queue.isEmpty) return null;
    final target = position + offset;
    if (target >= 0 && target < _queue.length) return target;
    if (_player.loopMode == LoopMode.all && _queue.length > 1) {
      return target % _queue.length;
    }
    return null;
  }

  Future<void> _seekToPosition(int position) =>
      _player.seek(Duration.zero, index: _sourceAt[position]);

  /// Recalcula la cola real (lista nueva) y publica el estado.
  void _commitQueue() {
    final count = _sources.length;
    final shuffled = _player.shuffleModeEnabled &&
        _shuffleOrder.indices.length == count;
    final order = shuffled
        ? List<int>.of(_shuffleOrder.indices)
        : List<int>.generate(count, (i) => i);

    final positions = List<int>.filled(count, 0);
    for (var p = 0; p < count; p++) {
      positions[order[p]] = p;
    }
    _sourceAt = order;
    _positionOf = positions;
    _queue = List.unmodifiable([for (final source in order) _sources[source]]);
    _emitState();
  }

  static List<(int, int)> _contiguousRuns(List<int> sortedIndices) {
    final runs = <(int, int)>[];
    var i = 0;
    while (i < sortedIndices.length) {
      final start = sortedIndices[i];
      var end = start + 1;
      while (i + 1 < sortedIndices.length && sortedIndices[i + 1] == end) {
        i++;
        end++;
      }
      runs.add((start, end));
      i++;
    }
    return runs;
  }

  Future<void> _onError(PlayerException error) async {
    final source = error.index;
    final position = source != null && source >= 0 && source < _positionOf.length
        ? _positionOf[source]
        : null;
    _errorController.add(
      PlaybackError(
        index: position,
        song: position != null ? _queue[position] : null,
        message: error.message,
      ),
    );

    try {
      final next = _relativePosition(1);
      if (next != null && _consecutiveErrors < _maxConsecutiveSkips) {
        _consecutiveErrors++;
        await _seekToPosition(next);
      } else {
        await _player.pause();
      }
    } catch (_) {
      // Un fallo al saltar no debe romper el reproductor.
    }
  }

  Future<void> _onProcessingState(ProcessingState state) async {
    if (state == ProcessingState.ready) _consecutiveErrors = 0;
    if (state != ProcessingState.completed) return;
    // Fin de la cola (repeat off): volver al principio, en pausa.
    await _player.pause();
    await _player.seek(
      Duration.zero,
      index: _sourceAt.isEmpty ? null : _sourceAt.first,
    );
  }

  void _emitState() {
    final processing = _player.processingState;
    final position = _currentPosition;

    _state = PlaybackState(
      queue: _queue,
      currentIndex: position,
      isPlaying: _player.playing && processing != ProcessingState.completed,
      isBuffering: processing == ProcessingState.loading ||
          processing == ProcessingState.buffering,
      position: _player.position,
      duration: _player.duration ??
          (position != null ? _queue[position].duration : null),
      shuffleEnabled: _player.shuffleModeEnabled,
      repeatMode: switch (_player.loopMode) {
        LoopMode.off => RepeatMode.off,
        LoopMode.all => RepeatMode.all,
        LoopMode.one => RepeatMode.one,
      },
    );
    if (!_stateController.isClosed) _stateController.add(_state);
  }
}
