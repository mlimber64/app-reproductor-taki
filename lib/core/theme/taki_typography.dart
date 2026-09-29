import 'package:flutter/painting.dart';

/// Escala tipográfica de Taki (docs/DESIGN_SYSTEM.md §2.2).
///
/// Sora para títulos y DM Sans para el resto, empaquetadas en la app
/// (`fonts:` en pubspec.yaml). Cada rol fija familia, tamaño, peso,
/// interlínea y tracking; el color lo decide quien lo usa (§2.3). Un widget
/// elige un rol en lugar de ajustar `fontSize` a mano.
///
/// Solo existen los pesos empaquetados (Sora 400–700, DM Sans 400–600); un
/// peso fuera de ellos se dibujaría con negrita simulada.
abstract final class TakiTypography {
  /// Títulos: display, headline y title.
  static const String titleFontFamily = 'Sora';

  /// Texto: body, label, caption y nombres de canción.
  static const String bodyFontFamily = 'DM Sans';

  /// Cabecera hero (álbum, artista, discovery).
  static const TextStyle display = TextStyle(
    fontFamily: titleFontFamily,
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  /// Título de pantalla, nombre de playlist en su cabecera, título en
  /// Reproduciendo.
  static const TextStyle headline = TextStyle(
    fontFamily: titleFontFamily,
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
  );

  /// Barra superior, títulos de sección, de estado vacío/error y de diálogo.
  static const TextStyle titleLarge = TextStyle(
    fontFamily: titleFontFamily,
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  /// Título de bottom sheet, nombre de tarjeta en cuadrícula.
  static const TextStyle titleMedium = TextStyle(
    fontFamily: titleFontFamily,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  /// Nombre de canción o playlist en filas y en el mini player.
  static const TextStyle trackTitle = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  /// Artista en Reproduciendo, texto destacado.
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  /// Descripciones, mensajes de estados vacíos y de error, diálogos.
  static const TextStyle body = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  /// Artista (y álbum) en filas y en el mini player.
  static const TextStyle trackSubtitle = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  /// Texto de botones.
  static const TextStyle label = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
  );

  /// Etiquetas de navegación y chips.
  static const TextStyle labelSmall = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );

  /// Duraciones, tiempos del reproductor y contadores (cifras tabulares).
  static const TextStyle caption = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Etiquetas de grupo ("TUS PLAYLISTS"). El texto va en MAYÚSCULAS: lo
  /// convierte quien lo muestra (un TextStyle no cambia el texto).
  static const TextStyle eyebrow = TextStyle(
    fontFamily: bodyFontFamily,
    fontSize: 11,
    height: 16 / 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
  );

  /// Todos los roles de la escala, por su nombre en el Design System.
  static const Map<String, TextStyle> roles = {
    'display': display,
    'headline': headline,
    'titleLarge': titleLarge,
    'titleMedium': titleMedium,
    'trackTitle': trackTitle,
    'bodyLarge': bodyLarge,
    'body': body,
    'trackSubtitle': trackSubtitle,
    'label': label,
    'labelSmall': labelSmall,
    'caption': caption,
    'eyebrow': eyebrow,
  };
}
