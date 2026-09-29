import 'package:flutter/painting.dart';

/// Radios de Taki (docs/DESIGN_SYSTEM.md §4): cuatro valores más la píldora.
///
/// El radio lo decide el tipo y el tamaño del componente, no la pantalla.
abstract final class TakiRadius {
  /// 8 · Artwork ≤ 64 px (filas, mini player, Cola), tooltips.
  static const double sm = 8;

  /// 12 · Artwork de 65 a 160 px, campos de texto, SnackBars.
  static const double md = 12;

  /// 16 · Mini player, contenedores y tarjetas agrupadas, menús.
  static const double lg = 16;

  /// 24 · Artwork > 160 px, bordes superiores de sheets, diálogos.
  static const double xl = 24;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));

  /// Píldora: botones de texto, chips, indicador de navegación, campo de
  /// búsqueda. Los botones de icono con contenedor usan un círculo.
  static const StadiumBorder pill = StadiumBorder();

  /// Radio de un artwork cuadrado de lado [side] (§4, §7.1).
  static double forArtwork(double side) {
    if (side <= 64) return sm;
    if (side <= 160) return md;
    return xl;
  }
}
