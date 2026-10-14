import '../../../core/domain/entities/artwork_reference.dart';

/// Carátulas con las que se dibuja la portada de una playlist.
///
/// [songArtwork] trae **una entrada por canción de la playlist, en orden**
/// (`null` o `UnavailableArtworkReference` si la canción no tiene carátula o no
/// está disponible). Solo cuentan las **primeras 4 canciones** (no las primeras
/// 4 carátulas): `[A, A, B, C, D]` da `[A, B, C]`. De ellas se toman las
/// carátulas distintas (igualdad de [ArtworkReference]), sin las no
/// disponibles, en orden de aparición.
///
/// - Sin canciones: `[]`. La portada es la de una playlist vacía (placeholder
///   con borde).
/// - Con canciones pero ninguna con carátula: `[Unavailable]`. Una pieza sin
///   imagen: la playlist tiene canciones, solo que sin carátula.
/// - Si no: las carátulas distintas, hasta 4.
///
/// Cada pantalla construye su propia secuencia, y esa diferencia se conserva:
/// - **Lista y sheet "Añadir a una playlist":** las primeras 4 *entradas
///   guardadas* (`Playlist.coverIdentities`) pasadas por el mapa de la
///   biblioteca; las que ya no están en ella entran como `null` y ocupan un
///   hueco. "Sin canciones" es el conteo guardado (`songCount == 0`).
/// - **Detalle:** las canciones *visibles* (las de la biblioteca); las
///   ausentes ni aparecen. "Sin canciones" es que no haya ninguna visible.
///
/// Es solo selección de datos: no resuelve ni conoce imágenes, ni si la
/// carátula es local o remota. Solo consume las primeras 4 entradas, así que
/// admite un `Iterable` perezoso o largo. No modifica la entrada y devuelve una
/// lista no modificable.
List<ArtworkReference> playlistCoverArtwork(
  Iterable<ArtworkReference?> songArtwork,
) {
  final considered = songArtwork.take(_coverSongs).toList();
  if (considered.isEmpty) return const <ArtworkReference>[];

  final distinct = <ArtworkReference>{
    for (final reference in considered)
      if (reference != null && reference is! UnavailableArtworkReference)
        reference,
  }.toList();
  if (distinct.isEmpty) {
    return const <ArtworkReference>[UnavailableArtworkReference()];
  }
  return List<ArtworkReference>.unmodifiable(distinct);
}

/// Canciones que deciden la portada (`Playlist.coverIdentities` guarda hasta 4).
const int _coverSongs = 4;
