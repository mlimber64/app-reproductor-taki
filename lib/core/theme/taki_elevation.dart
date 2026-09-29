import 'package:flutter/painting.dart';

import 'taki_colors.dart';

/// Niveles de superficie de Taki (docs/DESIGN_SYSTEM.md §5).
///
/// En oscuro la elevación se comunica con luminosidad, no con sombras: cada
/// nivel es una superficie más clara que el anterior. El único nivel que
/// oscurece lo de detrás es [modal].
enum TakiElevation {
  /// Nivel 0: parte del fondo (listas, contenido de página, Reproduciendo).
  integrated(TakiColors.background),

  /// Nivel 1: zona agrupada, sin sombra (navegación, cabecera de playlist).
  raised(TakiColors.surface),

  /// Nivel 2: flota sobre el contenido (mini player, sheets, menús).
  floating(TakiColors.surfaceElevated),

  /// Nivel 3: bloquea el resto (diálogos, sheets modales), con [scrim]
  /// detrás. Lo que se anida dentro usa `TakiColors.surfaceHighest`.
  modal(TakiColors.surfaceElevated);

  const TakiElevation(this.surface);

  final Color surface;

  /// Si oscurece el contenido de detrás con `TakiColors.scrim`.
  bool get hasScrim => this == modal;

  /// Grosor del borde `TakiColors.outline`, solo cuando dos superficies del
  /// mismo nivel se tocan o el componente necesita silueta.
  static const double borderWidth = 1;

  /// La única sombra del sistema: artwork grande de Reproduciendo y cabeceras
  /// hero. No es una escala de sombras; ningún otro componente la usa.
  static const BoxShadow artworkShadow = BoxShadow(
    color: Color(0x66000000),
    blurRadius: 32,
    offset: Offset(0, 12),
  );
}
