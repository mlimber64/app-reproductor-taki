/// Reglas del nombre de una playlist: se recorta, no puede quedar vacío y
/// tiene como máximo [maxLength] caracteres. Se permiten nombres repetidos.
abstract final class PlaylistName {
  static const int maxLength = 60;

  static String normalize(String raw) => raw.trim();

  /// `null` si [raw] es válido una vez recortado.
  static PlaylistNameError? validate(String raw) {
    final name = normalize(raw);
    if (name.isEmpty) return PlaylistNameError.empty;
    if (name.length > maxLength) return PlaylistNameError.tooLong;
    return null;
  }
}

enum PlaylistNameError { empty, tooLong }

class InvalidPlaylistNameException implements Exception {
  const InvalidPlaylistNameException(this.error);

  final PlaylistNameError error;

  @override
  String toString() => 'InvalidPlaylistNameException(${error.name})';
}
