import 'music_identity.dart';
import 'provider_attribution.dart';
import 'song.dart';

/// Consulta de catálogo independiente de la fuente.
///
/// Debe traer al menos un criterio ([text], [artist] o [tag]). Cómo cada
/// fuente traduce los criterios a su API es asunto suyo.
final class CatalogSearchQuery {
  CatalogSearchQuery({
    this.text,
    this.artist,
    this.tag,
    this.limit = 20,
    this.offset = 0,
  }) {
    if (_blank(text) && _blank(artist) && _blank(tag)) {
      throw ArgumentError('la consulta necesita al menos un criterio');
    }
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'debe ser mayor que 0');
    }
    if (offset < 0) {
      throw ArgumentError.value(offset, 'offset', 'no puede ser negativo');
    }
  }

  /// Texto libre (título de la canción).
  final String? text;
  final String? artist;
  final String? tag;
  final int limit;
  final int offset;

  static bool _blank(String? value) => value == null || value.trim().isEmpty;

  @override
  String toString() =>
      'CatalogSearchQuery(text: $text, artist: $artist, tag: $tag, '
      'limit: $limit, offset: $offset)';
}

/// Una página de resultados. [hasMore] indica que pedir `offset + limit`
/// puede devolver más canciones.
///
/// [attributions] conserva la atribución del proveedor de cada canción, por
/// `song.musicIdentity` (la atribución **no** es de `Song`). Es opcional: una
/// fuente sin atribución, o una canción sin entrada, queda sin ella y la UI
/// debe tratarla como posiblemente ausente. Solo en memoria; no se persiste.
final class CatalogSearchPage {
  const CatalogSearchPage(
    this.songs, {
    required this.hasMore,
    this.attributions = const {},
  });

  final List<Song> songs;
  final bool hasMore;
  final Map<MusicIdentity, ProviderAttribution> attributions;

  /// Atribución de [song], o `null` si la fuente no la entregó.
  ProviderAttribution? attributionOf(Song song) =>
      attributions[song.musicIdentity];
}

/// La búsqueda no pudo completarse (red, credencial, parámetros…).
final class CatalogSearchFailure implements Exception {
  const CatalogSearchFailure(this.message, {this.source, this.cause});

  final String message;
  final String? source;
  final Object? cause;

  @override
  String toString() => 'CatalogSearchFailure(${source ?? '-'}: $message)';
}
