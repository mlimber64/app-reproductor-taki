/// What a section of the discovery screen is about.
enum CatalogSectionKind {
  /// The most listened tracks of the current week.
  popularThisWeek,

  /// The most listened tracks of the current month.
  popularThisMonth,

  /// The most recently released tracks, newest first.
  newReleases,

  /// The most popular tracks of one genre (see [CatalogSection.genre]).
  genre,
}

/// A section a source can be asked for, independent of the source.
///
/// The value says *what* is wanted ("the popular rock tracks"); how each
/// source answers it is its own business, and a source that cannot answer a
/// section returns an empty page instead of failing.
///
/// Pure Dart, immutable, with value equality so it can key a cache.
final class CatalogSection {
  const CatalogSection._(this.kind, this.genre);

  static const CatalogSection popularThisWeek =
      CatalogSection._(CatalogSectionKind.popularThisWeek, null);

  static const CatalogSection popularThisMonth =
      CatalogSection._(CatalogSectionKind.popularThisMonth, null);

  static const CatalogSection newReleases =
      CatalogSection._(CatalogSectionKind.newReleases, null);

  /// The popular tracks of [genre], a free-text tag such as `rock`.
  ///
  /// Throws [ArgumentError] if [genre] is blank: it would identify nothing.
  factory CatalogSection.genre(String genre) {
    final trimmed = genre.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(genre, 'genre', 'must not be blank');
    }
    return CatalogSection._(CatalogSectionKind.genre, trimmed);
  }

  final CatalogSectionKind kind;

  /// The tag of a [CatalogSectionKind.genre] section; `null` for the others.
  final String? genre;

  @override
  bool operator ==(Object other) =>
      other is CatalogSection && other.kind == kind && other.genre == genre;

  @override
  int get hashCode => Object.hash(CatalogSection, kind, genre);

  @override
  String toString() =>
      genre == null ? 'CatalogSection($kind)' : 'CatalogSection($kind, $genre)';
}
