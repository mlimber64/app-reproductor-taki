import 'music_identity.dart';
import 'song.dart';

/// Resultado de resolver un conjunto de [MusicIdentity] a [Song].
///
/// Cada identidad pedida cae en **exactamente un** cubo, y los cubos dicen cosas
/// distintas (no se mezclan en un genérico «no encontrada»):
///
/// - [found]: la fuente la conoce y devuelve la canción. La clave coincide con
///   `song.musicIdentity`.
/// - [missing]: la fuente existe y está disponible, pero **no tiene** esa
///   canción (p. ej. el archivo local se borró, la SD está desmontada). Puede
///   volver a aparecer: quien guardó la identidad no debe borrarla.
/// - [unsupported]: **ninguna fuente registrada** sabe resolver esa identidad
///   (etiqueta de fuente desconocida o fuente aún no integrada). Es un problema
///   de configuración, no de la canción: se distingue de [missing] para que no
///   quede oculto.
///
/// Un fallo transitorio (red, lectura de la biblioteca…) **no** es un cubo: se
/// lanza como `SongLookupFailure`.
final class SongLookupResult {
  const SongLookupResult({
    this.found = const {},
    this.missing = const {},
    this.unsupported = const {},
  });

  static const SongLookupResult empty = SongLookupResult();

  final Map<MusicIdentity, Song> found;
  final Set<MusicIdentity> missing;
  final Set<MusicIdentity> unsupported;

  /// Unión de dos resultados de conjuntos de identidades disjuntos.
  SongLookupResult merge(SongLookupResult other) => SongLookupResult(
        found: {...found, ...other.found},
        missing: {...missing, ...other.missing},
        unsupported: {...unsupported, ...other.unsupported},
      );

  @override
  String toString() => 'SongLookupResult(found: ${found.length}, '
      'missing: ${missing.length}, unsupported: ${unsupported.length})';
}
