import 'dart:math';

import 'package:just_audio/just_audio.dart';

/// Orden aleatorio que respeta las ediciones de la cola.
///
/// El [DefaultShuffleOrder] de just_audio mete las canciones nuevas en
/// posiciones al azar, así que con aleatorio activo "reproducir a
/// continuación" o "mover" no harían lo esperado. Aquí la posición de las
/// canciones insertadas se controla con [placeNextInsertAt]: just_audio llama a
/// [insert] en cada `add`, `insert` y `move`, y envía el orden resultante al
/// reproductor nativo sin recargar la cola.
class QueueShuffleOrder extends ShuffleOrder {
  QueueShuffleOrder({Random? random}) : _random = random ?? Random();

  final Random _random;
  int? _insertPosition;

  @override
  final List<int> indices = [];

  /// Posición (en [indices]) donde irá la próxima inserción. `null` = al final.
  /// Se consume en la siguiente llamada a [insert].
  void placeNextInsertAt(int? position) => _insertPosition = position;

  @override
  void shuffle({int? initialIndex}) {
    assert(initialIndex == null || indices.contains(initialIndex));
    if (indices.length <= 1) return;
    indices.shuffle(_random);
    if (initialIndex == null) return;
    // La canción actual queda primera: lo que sigue es el orden mezclado.
    final swapPosition = indices.indexOf(initialIndex);
    indices[swapPosition] = indices[0];
    indices[0] = initialIndex;
  }

  @override
  void insert(int index, int count) {
    for (var i = 0; i < indices.length; i++) {
      if (indices[i] >= index) indices[i] += count;
    }
    final position = (_insertPosition ?? indices.length).clamp(0, indices.length);
    _insertPosition = null;
    indices.insertAll(position, List.generate(count, (i) => index + i));
  }

  @override
  void removeRange(int start, int end) {
    final count = end - start;
    indices.removeWhere((i) => i >= start && i < end);
    for (var i = 0; i < indices.length; i++) {
      if (indices[i] >= end) indices[i] -= count;
    }
  }

  @override
  void clear() {
    indices.clear();
    _insertPosition = null;
  }
}
