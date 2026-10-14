import '../../../../core/domain/entities/catalog_section.dart';

/// One carousel of the discovery screen: what to ask the catalog for and how
/// to call it.
///
/// The titles are the screen's own words; they never name a provider.
final class FeaturedSection {
  const FeaturedSection({
    required this.title,
    required this.section,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final CatalogSection section;
}

/// Sections shown on the search screen, in order.
///
/// The three charts come first; the genres follow. Each one loads on its own
/// when it scrolls into view, so adding a genre costs nothing until seen.
final List<FeaturedSection> defaultFeaturedSections = [
  const FeaturedSection(
    title: 'Populares esta semana',
    subtitle: 'Lo más escuchado del momento',
    section: CatalogSection.popularThisWeek,
  ),
  const FeaturedSection(
    title: 'Más escuchadas del mes',
    section: CatalogSection.popularThisMonth,
  ),
  const FeaturedSection(
    title: 'Novedades',
    subtitle: 'Recién publicadas',
    section: CatalogSection.newReleases,
  ),
  FeaturedSection(title: 'Rock', section: CatalogSection.genre('rock')),
  FeaturedSection(
    title: 'Electrónica',
    section: CatalogSection.genre('electronic'),
  ),
  FeaturedSection(title: 'Pop', section: CatalogSection.genre('pop')),
  FeaturedSection(title: 'Hip hop', section: CatalogSection.genre('hiphop')),
  FeaturedSection(title: 'Jazz', section: CatalogSection.genre('jazz')),
  FeaturedSection(title: 'Chill', section: CatalogSection.genre('chillout')),
];
