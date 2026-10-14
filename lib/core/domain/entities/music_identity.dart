/// Identidad de una canción: **qué canción es**, sin decir dónde está su audio
/// ni cómo reproducirla.
///
/// Se compone de:
/// - [source]: etiqueta **opaca** de la fuente que conoce la canción. El
///   dominio no enumera fuentes ni sabe qué significa cada etiqueta; solo la
///   compara.
/// - [externalId]: identificador de la canción **dentro de esa fuente**, como
///   cadena opaca y **exactamente como lo entrega la fuente** (no se recorta,
///   no se normaliza a minúsculas y no se interpreta).
///
/// Invariantes:
/// - [source] y [externalId] no pueden estar vacíos ni contener solo espacios
///   en blanco (no identificarían nada). Si no se cumple, el constructor lanza
///   un [ArgumentError].
/// - No hay más restricciones: no hay límite de longitud ni de caracteres, y
///   las mayúsculas y minúsculas importan (`"ABC"` ≠ `"abc"`). Un valor que
///   parece una URL es solo texto; nunca se trata como URL.
///
/// Igualdad por valor: dos identidades son iguales si coinciden [source] y
/// [externalId], carácter a carácter.
///
/// Es inmutable, de Dart puro, y deliberadamente pequeña: no contiene URL,
/// ruta, `contentUri`, artwork ni metadata, y no resuelve nada (audio, portada,
/// descarga). Esos asuntos pertenecen a otras piezas.
final class MusicIdentity {
  MusicIdentity(this.source, this.externalId) {
    if (_isBlank(source)) {
      throw ArgumentError.value(source, 'source', 'no puede estar vacío');
    }
    if (_isBlank(externalId)) {
      throw ArgumentError.value(
        externalId,
        'externalId',
        'no puede estar vacío',
      );
    }
  }

  /// Etiqueta opaca de la fuente.
  final String source;

  /// Identificador dentro de [source], tal como lo entrega la fuente.
  final String externalId;

  static bool _isBlank(String value) => value.trim().isEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MusicIdentity &&
          other.source == source &&
          other.externalId == externalId;

  @override
  int get hashCode => Object.hash(source, externalId);

  /// Solo para depuración y mensajes; **no** es un formato de serialización ni
  /// debe analizarse.
  @override
  String toString() => 'MusicIdentity(source: $source, externalId: $externalId)';
}
