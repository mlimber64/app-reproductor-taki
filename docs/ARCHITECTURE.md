# Arquitectura de Taki

Taki es un reproductor de música local para Android, 100 % cliente: sin backend,
sin anuncios, sin telemetría. El código sigue una **arquitectura hexagonal
(ports & adapters) organizada por features**.

## Estructura

```
lib/
  main.dart              Punto de entrada: ProviderScope + TakiApp
  app/                   Composición de la app (MaterialApp.router, rutas, tema)
    app.dart
    router.dart
    theme/
  core/                  Código transversal, sin lógica de negocio de una feature
    error/               Failures compartidos
    utils/
    constants/
    widgets/             Widgets genéricos reutilizables
  features/
    <feature>/
      domain/
        entities/        Modelos inmutables del negocio
        ports/           Interfaces (abstract interface class) que el dominio necesita
        usecases/        Casos de uso: una acción del negocio cada uno
      infrastructure/    Adapters que implementan los ports
      presentation/
        pages/           Pantallas
        widgets/         Widgets propios de la feature
        providers/       Providers de Riverpod (inyección + estado de UI)
```

Features actuales: `library`, `player`, `playlists`, `search`, `settings`.
La pestaña **Favoritos** vive en `library` (los favoritos son una vista filtrada
de la biblioteca).

## Reglas de dependencia

1. **`domain` es Dart puro.** No importa `package:flutter/*` ni paquetes
   externos. La única excepción permitida es `package:equatable`.
2. **`infrastructure` implementa los ports definidos en `domain`.** Aquí viven
   `just_audio`, `audio_service`, `on_audio_query`, `sqflite`,
   `permission_handler`, etc. Nunca expone tipos de esos paquetes hacia afuera:
   los traduce a entidades de dominio.
3. **`presentation` usa los casos de uso mediante providers de Riverpod.** Los
   widgets no instancian adapters ni llaman a paquetes de infraestructura
   directamente.
4. **La dirección de las dependencias es siempre hacia adentro:**

   ```
   presentation ──► domain ◄── infrastructure
   ```

   `domain` no conoce a nadie; `presentation` e `infrastructure` no se conocen
   entre sí. El cableado (qué adapter implementa qué port) se hace en providers.
5. **Entre features**, una feature solo puede importar el `domain` de otra
   (por ejemplo, `player` puede usar la entidad `Track` de `library`), nunca su
   `infrastructure` ni su `presentation`.
6. **`core`** no depende de ninguna feature.

## Fuente de audio intercambiable

La fuente de canciones es un **port**, no una implementación concreta:

```dart
// features/library/domain/ports/audio_source_port.dart (previsto)
abstract interface class AudioSourcePort {
  Future<List<Track>> fetchTracks();
  // ...
}
```

- Adapter inicial: `OnAudioQuerySource` (almacenamiento local vía
  `on_audio_query`).
- Adapters futuros posibles: `NavidromeSource` (Subsonic API), carpetas SAF,
  etc.

El adapter activo se elige en un provider:

```dart
final audioSourceProvider = Provider<AudioSourcePort>(
  (ref) => OnAudioQuerySource(),
);
```

Sumar una fuente nueva = crear un adapter en `infrastructure/` y cambiar (o
combinar) ese provider. Ni el dominio ni la UI cambian.

## Testing

- `domain`: tests unitarios puros.
- `presentation`: widget tests sobrescribiendo providers
  (`ProviderScope(overrides: [...])`) con fakes o mocks de `mocktail`.
- `infrastructure`: tests de integración en dispositivo cuando dependan de
  plugins de plataforma.

## Decisiones

- **Persistencia: `sqflite`** en lugar de `isar`. La última versión estable de
  isar (3.1.0+1) no se mantiene desde 2023, falla con Android Gradle Plugin 8+
  (falta `namespace`) y su generador de código entra en conflicto con versiones
  recientes de `analyzer`/`build_runner`. `sqflite` es estable, mantenido y
  suficiente para playlists, favoritos y ajustes.
- **Estado / DI: Riverpod.** **Navegación: go_router** con
  `StatefulShellRoute.indexedStack` (cada pestaña conserva su estado).
