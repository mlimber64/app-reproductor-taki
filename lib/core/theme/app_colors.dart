import 'package:flutter/painting.dart';

import 'taki_colors.dart';

/// Alias temporal de [TakiColors] para la UI que aún no se ha migrado
/// (docs/DESIGN_SYSTEM.md §1.8, §22 paso 1).
///
/// Los widgets legacy siguen escribiendo `AppColors.x`, pero cada valor es ya
/// el token Taki equivalente: toda la app usa la paleta "Midnight + Taki
/// Orange". Código nuevo: usar [TakiColors]. Se elimina cuando no quede
/// ningún uso.
abstract final class AppColors {
  // Superficies
  static const Color background = TakiColors.background;
  static const Color surface = TakiColors.surface;
  static const Color surfaceElevated = TakiColors.surfaceElevated;
  static const Color border = TakiColors.outline;

  // Texto
  static const Color textPrimary = TakiColors.textPrimary;
  static const Color textSecondary = TakiColors.textSecondary;

  // Acento principal
  static const Color accent = TakiColors.primary;

  // Acentos alternativos. Sin uso; se retiran con AppColors (§1.8).
  static const Color accentCoral = Color(0xFFFF7A59);
  static const Color accentBlue = Color(0xFF7C9CFF);
  static const Color accentMint = Color(0xFF3DD6B0);

  /// Contenido sobre el acento.
  static const Color onAccent = TakiColors.onPrimary;

  /// Contenido sobre fondos claros de [textPrimary] (p. ej. botón play).
  static const Color onTextPrimary = TakiColors.onTextPrimary;

  // Reproductor
  /// Pista de la barra de progreso del mini player (§10: `divider`).
  static const Color miniProgressTrack = TakiColors.divider;

  /// Pista de la barra de búsqueda de Reproduciendo (§11: `divider`).
  static const Color seekTrack = TakiColors.divider;

  /// Sombra de la carátula grande; mismo valor que
  /// `TakiElevation.artworkShadow` (negro al 40 %).
  static const Color artworkShadow = Color(0x66000000);
}
