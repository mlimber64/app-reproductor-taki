import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/entities/catalog_provider_info.dart';
import 'package:taki/core/domain/services/source_catalog_sources.dart';

import '../../helpers/catalog_fakes.dart';

void main() {
  final info = CatalogProviderInfo(source: 'a', label: 'A');

  test('browseIn returns the browse registered for that source', () {
    final browse = FakeCatalogBrowse();
    final sources = SourceCatalogSources([
      CatalogSourceRegistration(info, FakeCatalogSearch(), browse: browse),
    ]);

    expect(sources.browseIn('a'), same(browse));
  });

  test('a source registered without browse reports null, not an error', () {
    final sources = SourceCatalogSources([
      CatalogSourceRegistration(info, FakeCatalogSearch()),
    ]);

    expect(sources.browseIn('a'), isNull);
  });

  test('an unknown source throws UnknownCatalogSource', () {
    final sources = SourceCatalogSources(const []);

    expect(
      () => sources.browseIn('nope'),
      throwsA(isA<UnknownCatalogSource>()),
    );
  });
}
