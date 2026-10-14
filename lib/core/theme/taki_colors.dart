import 'package:flutter/painting.dart';

/// Paleta semántica "Midnight + Taki Orange" (docs/DESIGN_SYSTEM.md §1).
///
/// Los widgets usan estos tokens por su significado, nunca un HEX suelto. El
/// naranja ([primary]) es identidad y foco: acción principal, lo que suena, lo
/// activo o seleccionado y el foco; no decora.
///
/// Es la fuente vigente de los tokens de color del Design System; `AppTheme`
/// los compone en el `ThemeData`.
abstract final class TakiColors {
  // Superficies (§1.2). Cada nivel es ≈1.1:1 más claro que el anterior.

  /// Nivel 0: fondo de toda la app.
  static const Color background = Color(0xFF0E1016);

  /// Nivel 1: zonas agrupadas integradas (navegación, cabeceras, placeholder).
  static const Color surface = Color(0xFF161920);

  /// Nivel 2: elementos que flotan (mini player, sheets, menús, diálogos).
  static const Color surfaceElevated = Color(0xFF1E222B);

  /// Superficie sobre un nivel 2 (campos en un sheet, chips, tooltips).
  static const Color surfaceHighest = Color(0xFF272B36);

  /// Oscurece el contenido detrás de un modal.
  static final Color scrim = const Color(0xFF000000).withValues(alpha: 0.6);

  // Texto e iconos (§1.3).

  /// Títulos y nombres de canción. Blanco cálido, no #FFFFFF.
  static const Color textPrimary = Color(0xFFF2F0EB);

  /// Artista, descripciones, etiquetas inactivas.
  static const Color textSecondary = Color(0xFFA3A6B0);

  /// Metadata de baja prioridad. No usar sobre [surfaceHighest] (4.1:1).
  static const Color textMuted = Color(0xFF858A98);

  static const Color iconPrimary = textPrimary;
  static const Color iconSecondary = textSecondary;

  /// Icono dentro de un círculo [textPrimary] (play del mini player).
  static const Color onTextPrimary = Color(0xFF0E1016);

  // Acento: Taki Orange (§1.4).

  /// Identidad y foco.
  static const Color primary = Color(0xFFFF8A3D);

  /// Texto e icono sobre [primary] o [primaryPressed].
  static const Color onPrimary = Color(0xFF0E1016);

  /// Elementos naranjas mientras se pulsan.
  static const Color primaryPressed = Color(0xFFE97A30);

  /// Fondo tenue de selección o de lo activo (indicador de pestaña).
  static const Color primaryContainer = Color(0xFF3A2517);

  /// Texto sobre [primaryContainer].
  static const Color onPrimaryContainer = Color(0xFFFFC9A3);

  // Estados derivados (§1.4.1): reutilizan los tokens anteriores.

  /// Fondo de lo seleccionado; va con una marca de verificación en [primary].
  static const Color selected = primaryContainer;

  /// Icono o texto de lo activo (toggle encendido, pestaña actual, sonando);
  /// va con una variante de icono o un indicador, no solo el color.
  static const Color active = primary;

  /// Capa de pulsado encima del componente. Sobre naranja: [primaryPressed].
  static final Color pressedOverlay =
      textPrimary.withValues(alpha: pressedOpacity);

  /// Anillo de foco. Sobre componentes naranjas: [focusRingOnPrimary].
  static const Color focusRing = primary;
  static const Color focusRingOnPrimary = textPrimary;

  /// Texto e icono deshabilitados.
  static final Color disabledContent =
      textPrimary.withValues(alpha: disabledContentOpacity);

  /// Fondo de un botón deshabilitado.
  static final Color disabledContainer =
      textPrimary.withValues(alpha: disabledContainerOpacity);

  /// Velo sobre la carátula de la canción que suena, para que el indicador
  /// "sonando" se lea encima (§8).
  static final Color artworkScrim =
      background.withValues(alpha: artworkScrimOpacity);

  static const double pressedOpacity = 0.10;
  static const double artworkScrimOpacity = 0.55;
  static const double disabledContentOpacity = 0.38;
  static const double disabledContainerOpacity = 0.12;

  // Líneas (§1.5). Decorativas: nada depende solo de ellas.

  static const Color divider = Color(0xFF23272F);

  /// Borde del botón secundario, placeholder de playlist vacía, campos.
  static const Color outline = Color(0xFF2E3340);

  // Estados (§1.6). Siempre acompañados de icono y texto.

  static const Color error = Color(0xFFFF6B6B);
  static const Color errorContainer = Color(0xFF3A1A1C);
  static const Color success = Color(0xFF3DD6B0);
  static const Color warning = Color(0xFFF2C94C);

  // Marca (§1.7).

  /// Solo momentos de marca (ícono, splash, onboarding, ilustraciones de
  /// primer uso). Nunca en botones, texto, progreso ni fondos de pantalla.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF8A3D), Color(0xFFFC0A93), Color(0xFF9B11E6)],
  );
}
