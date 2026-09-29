import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Lectura de las tablas de docs/DESIGN_SYSTEM.md para comprobar que el
/// código y la especificación dicen lo mismo.
class DesignSystemDoc {
  DesignSystemDoc._(this._lines);

  factory DesignSystemDoc.load() => DesignSystemDoc._(
        File('docs/DESIGN_SYSTEM.md').readAsLinesSync(),
      );

  final List<String> _lines;

  /// Filas de las tablas de la sección `## <number>.` (hasta la siguiente
  /// `## `), como listas de celdas sin la fila de separación.
  List<List<String>> tableRows(int number) {
    final start = _lines.indexWhere((l) => l.startsWith('## $number. '));
    if (start < 0) throw StateError('No existe la sección $number');
    final end = _lines.indexWhere((l) => l.startsWith('## '), start + 1);
    final rows = <List<String>>[];
    for (final line in _lines.sublist(start + 1, end < 0 ? null : end)) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('|') || RegExp(r'^\|[\s|:-]+\|$').hasMatch(trimmed)) {
        continue;
      }
      rows.add([
        for (final cell in trimmed.substring(1, trimmed.length - 1).split('|'))
          cell.trim(),
      ]);
    }
    return rows;
  }

  /// Token (entre comillas invertidas) de una celda: "`primary`" → "primary".
  static String? token(String cell) =>
      RegExp(r'^`([A-Za-z0-9]+)`$').firstMatch(cell)?.group(1);

  /// Primer color `#RRGGBB` de una celda, opaco.
  static Color? hexColor(String cell) {
    final match = RegExp(r'`#([0-9A-Fa-f]{6})`').firstMatch(cell);
    return match == null ? null : Color(0xFF000000 | int.parse(match.group(1)!, radix: 16));
  }

  /// Todos los colores `#RRGGBB` de una celda, en orden.
  static List<Color> hexColors(String cell) => [
        for (final m in RegExp(r'`#([0-9A-Fa-f]{6})`').allMatches(cell))
          Color(0xFF000000 | int.parse(m.group(1)!, radix: 16)),
      ];

  /// Primer número de una celda; admite el signo menos tipográfico (−).
  static double? number(String cell) {
    final match =
        RegExp(r'[-−]?\d+(?:\.\d+)?').firstMatch(cell.replaceAll('−', '-'));
    return match == null ? null : double.parse(match.group(0)!);
  }
}

/// Contraste WCAG 2.1 entre dos colores opacos.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}
