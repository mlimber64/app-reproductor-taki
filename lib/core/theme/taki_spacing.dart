/// Escala de espaciado de Taki, base 4 (docs/DESIGN_SYSTEM.md §3).
///
/// Única fuente de verdad para márgenes y separaciones. Las alturas de fila,
/// artwork y botón no son espaciado: las define cada componente.
///
/// Nombres en el documento → en código: `space2xs` → [xxs], `spaceXs` → [xs],
/// … `space2xl` → [xxl], `space3xl` → [xxxl].
abstract final class TakiSpacing {
  /// 2 · Solo entre dos líneas de texto acopladas (título ↔ artista).
  static const double xxs = 2;

  /// 4 · Icono ↔ texto en chips; separación mínima.
  static const double xs = 4;

  /// 8 · Entre botones de icono; debajo de una etiqueta de grupo.
  static const double sm = 8;

  /// 12 · Artwork ↔ texto en filas; entre botones de un par.
  static const double md = 12;

  /// 16 · Margen lateral estándar; entre bloques de una sección.
  static const double lg = 16;

  /// 24 · Entre secciones; margen de pantallas inmersivas.
  static const double xl = 24;

  /// 32 · Margen interior de estados vacíos y de error.
  static const double xxl = 32;

  /// 48 · Separación grande (cabeceras hero, parte superior de estados vacíos).
  static const double xxxl = 48;

  // Reglas de §3 con nombre, sobre la misma escala.

  /// Margen lateral de página (Biblioteca, Playlists, Cola, sheets…).
  static const double pageGutter = lg;

  /// Margen lateral de pantallas inmersivas (Reproduciendo).
  static const double pageGutterImmersive = xl;

  /// Separación entre secciones.
  static const double sectionGap = xl;
}
