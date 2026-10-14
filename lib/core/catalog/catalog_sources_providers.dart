import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ports/catalog_sources.dart';

// Registro de catálogos compartido por las pantallas de búsqueda. Se compone
// fuera de `core` (en `lib/app/*_wiring.dart`) porque conoce a los
// proveedores concretos; se inyecta con un override en `main.dart` y en los
// tests, como `songLookupProvider`.
final catalogSourcesProvider = Provider<CatalogSources>(
  (ref) => throw UnimplementedError(
    'catalogSourcesProvider se sobrescribe en main.dart',
  ),
);
