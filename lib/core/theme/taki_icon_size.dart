/// Tamaños de icono de Taki (docs/DESIGN_SYSTEM.md §6.1).
///
/// El área táctil de un icono pulsable es siempre ≥ 48, mida lo que mida el
/// icono.
enum TakiIconSize {
  /// 16 · Indicadores de estado no pulsables en filas (corazón de favorita,
  /// barras de "sonando").
  xs(16),

  /// 20 · Dentro de botones de texto y chips; acciones secundarias de fila.
  sm(20),

  /// 24 · Estándar: navegación, barra superior, menús, ⋯, aleatorio, repetir.
  md(24),

  /// 28 · Favorito en Reproduciendo.
  lg(28),

  /// 32 · Anterior / siguiente en Reproduciendo.
  xl(32),

  /// 40 · Play / pausa en Reproduciendo.
  hero(40);

  const TakiIconSize(this.value);

  final double value;
}
