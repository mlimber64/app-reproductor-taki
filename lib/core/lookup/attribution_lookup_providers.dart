import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ports/attribution_lookup.dart';

// Resolución de atribuciones por identidad, compartida por las pantallas que
// la muestren (Reproduciendo, detalle…). Se compone fuera de `core` (en
// `lib/app/*_wiring.dart`) porque conoce a los proveedores concretos; se
// inyecta con un override en `main.dart` y en los tests, como
// `songLookupProvider`.
final attributionLookupProvider = Provider<AttributionLookup>(
  (ref) => throw UnimplementedError(
    'attributionLookupProvider se sobrescribe en main.dart',
  ),
);
