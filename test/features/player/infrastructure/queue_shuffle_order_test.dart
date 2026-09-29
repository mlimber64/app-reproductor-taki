import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:taki/features/player/infrastructure/queue_shuffle_order.dart';

void main() {
  late QueueShuffleOrder order;

  setUp(() {
    order = QueueShuffleOrder(random: Random(7))..insert(0, 5);
  });

  test('sin indicación, inserta al final', () {
    expect(order.indices, [0, 1, 2, 3, 4]);
    order.insert(5, 2);
    expect(order.indices, [0, 1, 2, 3, 4, 5, 6]);
  });

  test('inserta donde indica placeNextInsertAt y desplaza los índices', () {
    order
      ..placeNextInsertAt(1)
      ..insert(2, 2);

    // Las fuentes 2..4 pasan a ser 4..6; las nuevas (2, 3) van en la posición 1.
    expect(order.indices, [0, 2, 3, 1, 4, 5, 6]);
  });

  test('la indicación se usa una sola vez', () {
    order
      ..placeNextInsertAt(0)
      ..insert(5, 1)
      ..insert(6, 1);
    expect(order.indices, [5, 0, 1, 2, 3, 4, 6]);
  });

  test('removeRange quita y compacta sin reordenar el resto', () {
    order.indices
      ..clear()
      ..addAll([3, 0, 4, 1, 2]);
    order.removeRange(1, 3);
    expect(order.indices, [1, 0, 2]);
  });

  test('shuffle deja la canción actual primero', () {
    order.shuffle(initialIndex: 3);
    expect(order.indices.first, 3);
    expect(order.indices.toSet(), {0, 1, 2, 3, 4});
  });

  test('clear vacía y olvida la indicación pendiente', () {
    order
      ..placeNextInsertAt(0)
      ..clear()
      ..insert(0, 2)
      ..insert(2, 1);
    expect(order.indices, [0, 1, 2]);
  });
}
