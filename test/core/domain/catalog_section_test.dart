import 'package:flutter_test/flutter_test.dart';
import 'package:taki/core/domain/entities/catalog_section.dart';

void main() {
  test('the fixed sections have their own kind and no genre', () {
    expect(
      CatalogSection.popularThisWeek.kind,
      CatalogSectionKind.popularThisWeek,
    );
    expect(
      CatalogSection.popularThisMonth.kind,
      CatalogSectionKind.popularThisMonth,
    );
    expect(CatalogSection.newReleases.kind, CatalogSectionKind.newReleases);
    expect(CatalogSection.newReleases.genre, isNull);
  });

  test('a genre section keeps its trimmed tag', () {
    final section = CatalogSection.genre('  rock ');

    expect(section.kind, CatalogSectionKind.genre);
    expect(section.genre, 'rock');
  });

  test('a blank genre is rejected', () {
    expect(() => CatalogSection.genre('   '), throwsArgumentError);
    expect(() => CatalogSection.genre(''), throwsArgumentError);
  });

  test('equal sections are equal and usable as map keys', () {
    expect(CatalogSection.genre('jazz'), CatalogSection.genre(' jazz'));
    expect(
      CatalogSection.genre('jazz').hashCode,
      CatalogSection.genre('jazz').hashCode,
    );
    expect(CatalogSection.genre('jazz'), isNot(CatalogSection.genre('pop')));
    expect(
      CatalogSection.popularThisWeek,
      isNot(CatalogSection.popularThisMonth),
    );

    final cache = {CatalogSection.genre('rock'): 1};
    expect(cache[CatalogSection.genre('rock')], 1);
  });
}
