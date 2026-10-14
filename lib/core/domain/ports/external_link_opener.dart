/// Abre un enlace en la aplicación del sistema (navegador). No hay navegador
/// interno.
abstract interface class ExternalLinkOpener {
  /// `true` si se entregó al sistema. `false` si la URL no es `http(s)` o no se
  /// pudo abrir; **nunca lanza**.
  Future<bool> open(Uri url);
}
