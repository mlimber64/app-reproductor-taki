import 'music_identity.dart';

/// Referencia guardada a una canción: su identidad y una copia de respaldo de
/// sus datos para reencontrarla si hiciera falta.
///
/// La implementan los favoritos y las entradas de playlist. Su responsabilidad
/// propia es **identidad + respaldo de metadata**; la identidad es
/// [musicIdentity] (fuente + id externo), que es lo que se persiste. El
/// respaldo (`title`, `artist`, `durationMs`, `path`) solo sirve para
/// reencontrar canciones cuya fuente no da ids estables (hoy, la local; ver
/// `SongMatcher`).
abstract interface class SongReference {
  MusicIdentity get musicIdentity;
  String? get title;
  String? get artist;
  int? get durationMs;
  String? get path;
}
