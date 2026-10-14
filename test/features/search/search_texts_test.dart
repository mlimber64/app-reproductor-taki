import 'package:flutter_test/flutter_test.dart';
import 'package:taki/features/search/presentation/search_texts.dart';

void main() {
  test('textos finales aprobados (D9)', () {
    expect(SearchTexts.hint, 'Buscar canciones');
    expect(SearchTexts.idleTitle, 'Buscar música');
    expect(SearchTexts.idleMessage(2),
        'Escribe al menos 2 caracteres para empezar.');
    expect(SearchTexts.emptyTitle, 'No encontramos música');
    expect(SearchTexts.emptyMessage, 'Prueba con otro título.');
    expect(SearchTexts.failedTitle, 'No pudimos buscar');
    expect(SearchTexts.failedMessage,
        'Revisa tu conexión e inténtalo de nuevo.');
    expect(SearchTexts.retry, 'Reintentar');
    expect(SearchTexts.unavailableTitle, 'Búsqueda no disponible');
    expect(SearchTexts.unavailableMessage,
        'Esta función no está disponible en esta versión.');
    expect(SearchTexts.loadMoreFailed, 'No pudimos cargar más resultados');
  });

  test('el mínimo del mensaje inicial sale del parámetro', () {
    expect(SearchTexts.idleMessage(4), contains('4 caracteres'));
  });

  test('ningún texto menciona implementación ni proveedor', () {
    final all = [
      SearchTexts.hint,
      SearchTexts.idleTitle,
      SearchTexts.idleMessage(2),
      SearchTexts.emptyTitle,
      SearchTexts.emptyMessage,
      SearchTexts.failedTitle,
      SearchTexts.failedMessage,
      SearchTexts.retry,
      SearchTexts.unavailableTitle,
      SearchTexts.unavailableMessage,
      SearchTexts.loadMoreFailed,
      SearchTexts.searching,
      SearchTexts.loadingMore,
    ].join(' ').toLowerCase();
    for (final word in ['jamendo', 'api', 'provider', 'proveedor', 'http', 'client']) {
      expect(all, isNot(contains(word)), reason: word);
    }
  });
}
