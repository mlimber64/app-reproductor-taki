import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/theme/taki_typography.dart';

import 'design_system_doc.dart';

/// Familias y pesos declarados en la sección `fonts:` de pubspec.yaml.
Map<String, Set<int>> _bundledWeights() {
  final bundled = <String, Set<int>>{};
  String? family;
  for (final line in File('pubspec.yaml').readAsLinesSync()) {
    final familyMatch = RegExp(r'^\s*- family:\s*(.+)$').firstMatch(line);
    if (familyMatch != null) {
      family = familyMatch.group(1)!.trim();
      bundled[family] = {};
      continue;
    }
    final weightMatch = RegExp(r'^\s*weight:\s*(\d+)').firstMatch(line);
    if (weightMatch != null && family != null) {
      bundled[family]!.add(int.parse(weightMatch.group(1)!));
    }
  }
  return bundled;
}

void main() {
  test('cada rol usa una familia y un peso empaquetados (sin negrita simulada)',
      () {
    final bundled = _bundledWeights();
    expect(bundled.keys, containsAll(['Sora', 'DM Sans']));
    TakiTypography.roles.forEach((name, style) {
      final weights = bundled[style.fontFamily];
      expect(weights, isNotNull, reason: '$name: familia no empaquetada');
      expect(
        weights,
        contains(style.fontWeight!.value),
        reason: '$name: peso ${style.fontWeight!.value} no empaquetado',
      );
    });
  });

  group('coincide con la escala de docs/DESIGN_SYSTEM.md §2.2', () {
    // | Rol | `token` | Familia | tamaño / interlínea | peso | tracking | uso |
    final documented = <String, List<String>>{
      for (final row in DesignSystemDoc.load().tableRows(2))
        if (row.length >= 6 && DesignSystemDoc.token(row[1]) != null)
          DesignSystemDoc.token(row[1])!: row,
    };

    test('mismos roles: ni añadidos ni eliminados', () {
      expect(TakiTypography.roles.keys.toSet(), documented.keys.toSet());
    });

    test('familia, tamaño, interlínea, peso y tracking', () {
      TakiTypography.roles.forEach((name, style) {
        final row = documented[name]!;
        final sizes = row[3].split('/').map((s) => double.parse(s.trim()));

        expect(style.fontFamily, row[2], reason: '$name: familia');
        expect(style.fontSize, sizes.first, reason: '$name: tamaño');
        // La interlínea en px sale exacta (sin medios píxeles).
        expect(style.fontSize! * style.height!, closeTo(sizes.last, 1e-9),
            reason: '$name: interlínea');
        expect(style.fontWeight!.value, DesignSystemDoc.number(row[4]),
            reason: '$name: peso');
        expect(style.letterSpacing, DesignSystemDoc.number(row[5]),
            reason: '$name: tracking');
      });
    });

    test('las cifras tabulares del documento están activadas', () {
      documented.forEach((name, row) {
        final tabular = row[5].contains('tabulares');
        expect(
          TakiTypography.roles[name]!.fontFeatures
                  ?.contains(const FontFeature.tabularFigures()) ??
              false,
          tabular,
          reason: name,
        );
      });
    });
  });

  test('los roles no fijan color: lo decide su uso (§2.3)', () {
    TakiTypography.roles.forEach((name, TextStyle style) {
      expect(style.color, isNull, reason: name);
    });
  });
}
