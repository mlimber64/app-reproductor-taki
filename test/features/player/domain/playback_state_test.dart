import 'package:flutter_test/flutter_test.dart';
import 'package:taki/features/player/domain/entities/playback_state.dart';

import '../../../helpers/library_fakes.dart';

void main() {
  final queue = [for (var i = 0; i < 4; i++) buildSong(id: i)];

  group('reglas de la cola', () {
    test('solo lo que viene después de la actual es editable', () {
      final state = PlaybackState(queue: queue, currentIndex: 1);

      expect(state.upcomingStart, 2);
      expect(state.upcomingCount, 2);
      expect([for (var i = -1; i <= 4; i++) state.isUpcoming(i)],
          [false, false, false, true, true, false]);
    });

    test('sin canción actual no hay nada editable', () {
      final state = PlaybackState(queue: queue);

      expect(state.currentSong, isNull);
      expect(state.upcomingCount, 0);
      expect(state.isUpcoming(0), isFalse);
      expect(PlaybackState.empty.upcomingCount, 0);
    });
  });

  group('siguiente y anterior', () {
    test('dependen de la posición en la cola', () {
      final first = PlaybackState(queue: queue, currentIndex: 0);
      final middle = PlaybackState(queue: queue, currentIndex: 2);
      final last = PlaybackState(queue: queue, currentIndex: 3);

      expect((first.hasPrevious, first.hasNext), (false, true));
      expect((middle.hasPrevious, middle.hasNext), (true, true));
      expect((last.hasPrevious, last.hasNext), (true, false));
    });

    test('con repetir todo la cola da la vuelta', () {
      final last = PlaybackState(
        queue: queue,
        currentIndex: 3,
        repeatMode: RepeatMode.all,
      );
      expect((last.hasPrevious, last.hasNext), (true, true));
    });

    test('una sola canción no tiene vecinas, ni con repetir todo', () {
      final single = PlaybackState(
        queue: [queue.first],
        currentIndex: 0,
        repeatMode: RepeatMode.all,
      );
      expect((single.hasPrevious, single.hasNext), (false, false));
    });
  });
}
