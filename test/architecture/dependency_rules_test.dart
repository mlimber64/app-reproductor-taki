import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reglas de dependencia de `lib/` (ver docs/ARCHITECTURE.md):
///
/// - `core` no depende de `app` ni de ninguna feature.
/// - Ninguna feature depende de `app`.
/// - Una feature no depende de otra, salvo las [_allowedCrossFeature]
///   documentadas (providers de presentación, la API pública de una feature).
/// - `core/domain` es Dart puro.
void main() {
  final imports = _collectImports();

  test('encuentra los imports de lib/', () {
    expect(imports, isNotEmpty);
  });

  test('core no depende de app ni de features', () {
    final violations = [
      for (final i in imports)
        if (i.fromLayer == 'core' &&
            (i.toLayer == 'app' || i.toFeature != null))
          i,
    ];
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('las features no dependen de app', () {
    final violations = [
      for (final i in imports)
        if (i.fromFeature != null && i.toLayer == 'app') i,
    ];
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('las features no dependen de otras salvo las excepciones documentadas',
      () {
    final violations = [
      for (final i in imports)
        if (i.fromFeature != null &&
            i.toFeature != null &&
            i.fromFeature != i.toFeature &&
            !_allowedCrossFeature.contains('${i.from} -> ${i.to}'))
          i,
    ];
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('las excepciones entre features siguen existiendo', () {
    // Si una excepción deja de usarse, hay que quitarla de la lista (y de
    // docs/ARCHITECTURE.md) para que la lista no crezca sin control.
    final actual = {for (final i in imports) '${i.from} -> ${i.to}'};
    final stale = _allowedCrossFeature.difference(actual);
    expect(stale, isEmpty, reason: stale.join('\n'));
  });

  test('core/domain es Dart puro', () {
    final violations = [
      for (final i in imports)
        if (i.from.startsWith('core/domain/') &&
            i.isPackage &&
            !i.to.startsWith('package:equatable/'))
          i,
    ];
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  // Fase 3.2B: la búsqueda de catálogo es provider-neutral. Depende solo de
  // abstracciones de `core`; el proveedor se enchufa desde `app/`.
  test('features/search solo importa de otra feature el provider del Player',
      () {
    final violations = [
      for (final i in imports)
        if (i.fromFeature == 'search' &&
            i.toFeature != null &&
            i.toFeature != 'search' &&
            i.to != _searchPlayerProviders)
          i,
    ];
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('features/search no importa features/jamendo directamente', () {
    final violations = [
      for (final i in imports)
        if (i.fromFeature == 'search' && i.to.startsWith('features/jamendo/'))
          i,
    ];
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('features/search no depende de app', () {
    final violations = [
      for (final i in imports)
        if (i.fromFeature == 'search' && i.toLayer == 'app') i,
    ];
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('features/search no menciona a ningún proveedor concreto', () {
    final files = Directory('lib/features/search')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    expect(files, isNotEmpty);
    final offenders = [
      for (final file in files)
        if (RegExp('jamendo|audius', caseSensitive: false)
            .hasMatch(file.readAsStringSync()))
          file.path,
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  // Fase 3.2F: Reproduciendo pide la atribución por el contrato de `core`; no
  // conoce a ningún proveedor.
  test('features/player no importa features/jamendo ni lo menciona', () {
    final violations = [
      for (final i in imports)
        if (i.fromFeature == 'player' && i.to.startsWith('features/jamendo/'))
          i,
    ];
    expect(violations, isEmpty, reason: violations.join('\n'));
    final offenders = [
      for (final file in Directory('lib/features/player')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')))
        if (RegExp('jamendo|audius', caseSensitive: false)
            .hasMatch(file.readAsStringSync()))
          file.path,
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  // Fase 3.6: las portadas de playlist usan el artwork de `core`; no conocen a
  // ningún proveedor.
  test('features/playlists no importa features/jamendo ni lo menciona', () {
    final violations = [
      for (final i in imports)
        if (i.fromFeature == 'playlists' && i.to.startsWith('features/jamendo/'))
          i,
    ];
    expect(violations, isEmpty, reason: violations.join('\n'));
    final offenders = [
      for (final file in Directory('lib/features/playlists')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')))
        if (RegExp('jamendo|audius', caseSensitive: false)
            .hasMatch(file.readAsStringSync()))
          file.path,
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('search tiene una única excepción entre features (3.2C)', () {
    expect(
      _allowedCrossFeature.where((e) => e.contains('features/search/')),
      {
        'features/search/presentation/pages/search_page.dart -> '
            '$_searchPlayerProviders',
      },
    );
  });
}

/// Provider del Player que `SearchPage` usa para reproducir un resultado.
const String _searchPlayerProviders =
    'features/player/presentation/providers/player_providers.dart';

/// Imports entre features permitidos: solo providers de presentación.
const Set<String> _allowedCrossFeature = {
  // Biblioteca y Favoritos reproducen sus listas, marcan la canción que suena
  // y piden el permiso de notificaciones al empezar a reproducir.
  'features/library/presentation/pages/library_page.dart -> '
      'features/player/presentation/providers/player_providers.dart',
  'features/library/presentation/pages/favorites_page.dart -> '
      'features/player/presentation/providers/player_providers.dart',
  // El corazón de Reproduciendo marca/desmarca favoritos (viven en library).
  'features/player/presentation/pages/now_playing_page.dart -> '
      'features/library/presentation/providers/favorites_providers.dart',
  // Las playlists se resuelven contra las canciones escaneadas de la
  // biblioteca y piden permiso de lectura igual que ella.
  'features/playlists/presentation/providers/playlists_providers.dart -> '
      'features/library/presentation/providers/songs_notifier.dart',
  'features/playlists/presentation/pages/playlist_detail_page.dart -> '
      'features/library/presentation/providers/songs_notifier.dart',
  // Buscar reproduce el resultado tocado y marca la canción que suena.
  'features/search/presentation/pages/search_page.dart -> '
      'features/player/presentation/providers/player_providers.dart',
  // Ajustes muestra el estado de la biblioteca y la vuelve a escanear.
  'features/settings/presentation/pages/settings_page.dart -> '
      'features/library/presentation/providers/songs_notifier.dart',
  // El detalle de playlist reproduce, mezcla y marca la canción que suena.
  'features/playlists/presentation/pages/playlist_detail_page.dart -> '
      'features/player/presentation/providers/player_providers.dart',
};

class _Import {
  _Import(this.from, this.to, {required this.isPackage});

  /// Rutas relativas a `lib/` (o el import tal cual si es de otro paquete).
  final String from;
  final String to;
  final bool isPackage;

  String get fromLayer => from.split('/').first;
  String get toLayer => isPackage ? 'package' : to.split('/').first;
  String? get fromFeature => _feature(from);
  String? get toFeature => isPackage ? null : _feature(to);

  static String? _feature(String path) {
    final parts = path.split('/');
    return parts.length > 2 && parts.first == 'features' ? parts[1] : null;
  }

  @override
  String toString() => '$from -> $to';
}

final RegExp _directive = RegExp(
  r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

List<_Import> _collectImports() {
  final lib = Directory('lib');
  final result = <_Import>[];
  for (final file in lib.listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart')) continue;
    final from = _relative(file.path);
    for (final match in _directive.allMatches(file.readAsStringSync())) {
      final uri = match.group(1)!;
      if (uri.startsWith('dart:')) continue;
      if (uri.startsWith('package:taki/')) {
        result.add(_Import(from, uri.substring('package:taki/'.length),
            isPackage: false));
      } else if (uri.startsWith('package:')) {
        result.add(_Import(from, uri, isPackage: true));
      } else {
        result.add(_Import(from, _resolve(from, uri), isPackage: false));
      }
    }
  }
  return result;
}

String _relative(String path) {
  final normalized = path.replaceAll(r'\', '/');
  return normalized.substring(normalized.indexOf('lib/') + 'lib/'.length);
}

String _resolve(String from, String relative) {
  final parts = from.split('/')..removeLast();
  for (final segment in relative.split('/')) {
    if (segment == '..') {
      parts.removeLast();
    } else if (segment != '.') {
      parts.add(segment);
    }
  }
  return parts.join('/');
}
