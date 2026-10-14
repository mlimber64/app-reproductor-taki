import '../entities/catalog_search.dart';
import '../entities/catalog_section.dart';

/// Read-only discovery of a source's catalog: what is worth showing before the
/// user types anything.
///
/// It is separate from [CatalogSearch] because a source may be searchable and
/// still have no notion of "popular". Failures are thrown as
/// [CatalogSearchFailure].
abstract interface class CatalogBrowse {
  /// The songs of [section], best first.
  ///
  /// [limit] must be greater than 0; the source may return fewer songs. A
  /// section the source cannot answer returns an empty page, not a failure:
  /// a failure means the source was reachable and broke, or was not reachable.
  Future<CatalogSearchPage> section(CatalogSection section, {int limit = 20});
}
