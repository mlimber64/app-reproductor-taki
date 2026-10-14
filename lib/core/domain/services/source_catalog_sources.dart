import '../entities/catalog_provider_info.dart';
import '../ports/catalog_browse.dart';
import '../ports/catalog_search.dart';
import '../ports/catalog_sources.dart';

/// Una fuente de catálogo registrada: su descripción, su búsqueda y, si la
/// tiene, su descubrimiento ([browse]).
final class CatalogSourceRegistration {
  const CatalogSourceRegistration(this.info, this.search, {this.browse});

  final CatalogProviderInfo info;
  final CatalogSearch search;
  final CatalogBrowse? browse;
}

/// [CatalogSources] sobre un conjunto fijo de registros, indexados por
/// `info.source` (mismo patrón que `SourceSongLookup`: una fuente nueva se
/// registra añadiéndola, sin tocar la UI).
///
/// Dos registros con la misma fuente son un error de configuración
/// (`ArgumentError`): no se elige uno en silencio.
class SourceCatalogSources implements CatalogSources {
  SourceCatalogSources(Iterable<CatalogSourceRegistration> registrations)
      : _bySource = _index(registrations);

  final Map<String, CatalogSourceRegistration> _bySource;

  static Map<String, CatalogSourceRegistration> _index(
    Iterable<CatalogSourceRegistration> registrations,
  ) {
    final bySource = <String, CatalogSourceRegistration>{};
    for (final registration in registrations) {
      final source = registration.info.source;
      if (bySource.containsKey(source)) {
        throw ArgumentError.value(source, 'source', 'registrada dos veces');
      }
      bySource[source] = registration;
    }
    return bySource;
  }

  @override
  List<CatalogProviderInfo> get available => List.unmodifiable([
        for (final registration in _bySource.values) registration.info,
      ]);

  @override
  bool get isAvailable => _bySource.isNotEmpty;

  @override
  CatalogSearch searchIn(String source) {
    final registration = _bySource[source];
    if (registration == null) throw UnknownCatalogSource(source);
    return registration.search;
  }

  @override
  CatalogBrowse? browseIn(String source) {
    final registration = _bySource[source];
    if (registration == null) throw UnknownCatalogSource(source);
    return registration.browse;
  }
}
