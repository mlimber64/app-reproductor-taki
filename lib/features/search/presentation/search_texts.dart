/// Textos de la pantalla de búsqueda (aprobados en D9, Fase 3.2E).
///
/// Están aquí, y no dispersos por los widgets, para poder cambiarlos
/// en un único sitio. No mencionan a ningún proveedor.
abstract final class SearchTexts {
  static const String hint = 'Buscar canciones';

  static const String idleTitle = 'Buscar música';
  static String idleMessage(int minimumLength) =>
      'Escribe al menos $minimumLength caracteres para empezar.';

  static const String emptyTitle = 'No encontramos música';
  static const String emptyMessage = 'Prueba con otro título.';

  static const String failedTitle = 'No pudimos buscar';
  static const String failedMessage =
      'Revisa tu conexión e inténtalo de nuevo.';
  static const String retry = 'Reintentar';

  static const String unavailableTitle = 'Búsqueda no disponible';
  static const String unavailableMessage =
      'Esta función no está disponible en esta versión.';

  static const String loadMoreFailed = 'No pudimos cargar más resultados';
  static const String searching = 'Buscando…';
  static const String loadingMore = 'Cargando más resultados';
}
