/// Referencia guardada a una canción: su id de MediaStore y una copia de
/// respaldo de sus datos para reencontrarla si el id cambia.
///
/// La implementan los favoritos y las entradas de playlist.
abstract interface class SongReference {
  int get songId;
  String? get title;
  String? get artist;
  int? get durationMs;
  String? get path;
}
