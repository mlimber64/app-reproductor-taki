import 'package:flutter_test/flutter_test.dart';
import 'package:taki/features/settings/presentation/format_bytes.dart';

void main() {
  test('bytes below one kilobyte are shown as-is', () {
    expect(formatBytes(0), '0 B');
    expect(formatBytes(512), '512 B');
    expect(formatBytes(999), '999 B');
  });

  test('negative values never show a minus sign', () {
    expect(formatBytes(-5), '0 B');
  });

  test('uses decimal units with a comma and drops a trailing ,0', () {
    expect(formatBytes(1000), '1 kB');
    expect(formatBytes(1500), '1,5 kB');
    expect(formatBytes(3200000), '3,2 MB');
    expect(formatBytes(2000000000), '2 GB');
  });

  test('values of 100 or more of a unit have no decimals', () {
    expect(formatBytes(250000), '250 kB');
  });
}
