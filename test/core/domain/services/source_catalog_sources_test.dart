import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/entities/catalog_provider_info.dart';
import 'package:taki/core/domain/services/source_catalog_sources.dart';

import '../../../helpers/catalog_fakes.dart';

CatalogSourceRegistration _registration(
  String source,
  FakeCatalogSearch search, {
  String? label,
}) =>
    CatalogSourceRegistration(
      CatalogProviderInfo(source: source, label: label ?? source.toUpperCase()),
      search,
    );

void main() {
  group('CatalogProviderInfo', () {
    test('guarda fuente y etiqueta', () {
      final info = CatalogProviderInfo(source: 'fake', label: 'Fake');
      expect(info.source, 'fake');
      expect(info.label, 'Fake');
    });

    test('no admite fuente ni etiqueta en blanco', () {
      expect(() => CatalogProviderInfo(source: '', label: 'x'),
          throwsArgumentError);
      expect(() => CatalogProviderInfo(source: '  ', label: 'x'),
          throwsArgumentError);
      expect(() => CatalogProviderInfo(source: 'x', label: ''),
          throwsArgumentError);
      expect(() => CatalogProviderInfo(source: 'x', label: ' '),
          throwsArgumentError);
    });

    test('igualdad por valor', () {
      final a = CatalogProviderInfo(source: 'a', label: 'A');
      expect(a, CatalogProviderInfo(source: 'a', label: 'A'));
      expect(a.hashCode, CatalogProviderInfo(source: 'a', label: 'A').hashCode);
      expect(a, isNot(CatalogProviderInfo(source: 'b', label: 'A')));
      expect(a, isNot(CatalogProviderInfo(source: 'a', label: 'B')));
      expect(a.hashCode,
          isNot(CatalogProviderInfo(source: 'a', label: 'B').hashCode));
    });

    test('toString y UnknownCatalogSource', () {
      expect(CatalogProviderInfo(source: 'a', label: 'A').toString(),
          'CatalogProviderInfo(a, A)');
      expect(const UnknownCatalogSource('z').toString(),
          'UnknownCatalogSource(z)');
    });
  });

  group('SourceCatalogSources', () {
    test('sin registros: no disponible', () {
      final sources = SourceCatalogSources(const []);
      expect(sources.isAvailable, isFalse);
      expect(sources.available, isEmpty);
    });

    test('con registros: disponibles, en orden de registro', () {
      final sources = SourceCatalogSources([
        _registration('b', FakeCatalogSearch()),
        _registration('a', FakeCatalogSearch()),
      ]);
      expect(sources.isAvailable, isTrue);
      expect(sources.available.map((i) => i.source), ['b', 'a']);
      expect(sources.available.first.label, 'B');
    });

    test('searchIn devuelve el catálogo de la fuente', () {
      final a = FakeCatalogSearch();
      final b = FakeCatalogSearch();
      final sources =
          SourceCatalogSources([_registration('a', a), _registration('b', b)]);
      expect(sources.searchIn('a'), same(a));
      expect(sources.searchIn('b'), same(b));
    });

    test('fuente no registrada: UnknownCatalogSource', () {
      final sources = SourceCatalogSources([_registration('a', FakeCatalogSearch())]);
      expect(
        () => sources.searchIn('z'),
        throwsA(isA<UnknownCatalogSource>().having((e) => e.source, 'source', 'z')),
      );
    });

    test('la misma fuente dos veces es un error de configuración', () {
      expect(
        () => SourceCatalogSources([
          _registration('a', FakeCatalogSearch()),
          _registration('a', FakeCatalogSearch()),
        ]),
        throwsArgumentError,
      );
    });

    test('la lista disponible no es modificable', () {
      final sources = SourceCatalogSources([_registration('a', FakeCatalogSearch())]);
      expect(() => sources.available.clear(), throwsUnsupportedError);
    });
  });
}
