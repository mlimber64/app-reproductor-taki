import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/utils/duration_format.dart';

void main() {
  group('formatTrackDuration', () {
    test('formatea m:ss con segundos de dos dígitos', () {
      expect(formatTrackDuration(Duration.zero), '0:00');
      expect(formatTrackDuration(const Duration(seconds: 5)), '0:05');
      expect(formatTrackDuration(const Duration(minutes: 3, seconds: 7)), '3:07');
      expect(formatTrackDuration(const Duration(minutes: 59, seconds: 59)), '59:59');
    });

    test('trunca los milisegundos', () {
      expect(
        formatTrackDuration(const Duration(minutes: 2, seconds: 30, milliseconds: 999)),
        '2:30',
      );
    });

    test('usa h:mm:ss a partir de una hora', () {
      expect(formatTrackDuration(const Duration(hours: 1)), '1:00:00');
      expect(
        formatTrackDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
    });

    test('trata duraciones negativas como cero', () {
      expect(formatTrackDuration(const Duration(seconds: -5)), '0:00');
    });
  });

  group('formatTotalDuration', () {
    test('muestra segundos, minutos u horas según el total', () {
      expect(formatTotalDuration(const Duration(seconds: 45)), '45 s');
      expect(formatTotalDuration(const Duration(minutes: 42, seconds: 59)), '42 min');
      expect(formatTotalDuration(const Duration(hours: 2, minutes: 5)), '2 h 05 min');
    });
  });
}
