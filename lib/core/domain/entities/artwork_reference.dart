/// Referencia a la carátula de una canción, **independiente de su origen**.
///
/// Responde «¿dónde está la carátula?», no «¿qué canción es?» (eso es
/// `MusicIdentity`) ni «¿cómo se reproduce?» (eso es `PlaybackResource`). Una
/// referencia no identifica una canción: dos canciones pueden compartirla.
///
/// Jerarquía **sellada** de tres casos:
/// - [LocalArtworkReference]: carátula de la fuente local, por `albumId`.
/// - [RemoteArtworkReference]: carátula a la que apunta una URL.
/// - [UnavailableArtworkReference]: se sabe que no hay carátula.
///
/// Dart puro, inmutable, con igualdad por valor (sirve de clave de caché).
/// Existing does not mean Taki downloads it: a remote reference is only loaded
/// when a `RemoteArtworkLoader` is available.
sealed class ArtworkReference {
  const ArtworkReference();
}

/// Carátula de la fuente local, resuelta por el `albumId` de MediaStore.
///
/// El `albumId` es una propiedad **de la fuente local**, no una identidad
/// universal: no forma parte de `MusicIdentity` ni se convierte en `externalId`.
final class LocalArtworkReference extends ArtworkReference {
  const LocalArtworkReference(this.albumId);

  final int albumId;

  @override
  bool operator ==(Object other) =>
      other is LocalArtworkReference && other.albumId == albumId;

  @override
  int get hashCode => Object.hash(LocalArtworkReference, albumId);

  @override
  String toString() => 'LocalArtworkReference($albumId)';
}

/// Carátula a la que apunta una URL.
///
/// - [url] es texto **opaco**: no se analiza, no se normaliza ni se recorta, y
///   no se asume que identifique una canción. Solo se exige que no esté vacía.
/// - [width] y [height] son el tamaño en px **conocido** de esa imagen, si la
///   fuente lo informa (`null` = desconocido). Forman parte de la igualdad:
///   la misma URL con otro tamaño declarado es otra referencia.
///
/// Sin cabeceras, tokens, caducidad ni datos propios de un proveedor: si una
/// fuente los necesita, se añadirán cuando exista esa necesidad.
final class RemoteArtworkReference extends ArtworkReference {
  RemoteArtworkReference(this.url, {this.width, this.height}) {
    if (url.trim().isEmpty) {
      throw ArgumentError.value(url, 'url', 'no puede estar vacío');
    }
    _requirePositive(width, 'width');
    _requirePositive(height, 'height');
  }

  final String url;
  final int? width;
  final int? height;

  static void _requirePositive(int? value, String name) {
    if (value != null && value <= 0) {
      throw ArgumentError.value(value, name, 'debe ser mayor que 0');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is RemoteArtworkReference &&
      other.url == url &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(RemoteArtworkReference, url, width, height);

  @override
  String toString() =>
      'RemoteArtworkReference($url, width: $width, height: $height)';
}

/// Se sabe que no hay carátula (p. ej. una canción sin álbum).
///
/// Es un resultado definitivo, no un error: un fallo transitorio no debe
/// convertirse en esto.
final class UnavailableArtworkReference extends ArtworkReference {
  const UnavailableArtworkReference();

  @override
  bool operator ==(Object other) => other is UnavailableArtworkReference;

  @override
  int get hashCode => (UnavailableArtworkReference).hashCode;

  @override
  String toString() => 'UnavailableArtworkReference()';
}

/// Referencia de la carátula local a partir del `albumId` de la fuente local.
///
/// Es el único sitio donde un `albumId` (que puede faltar) se convierte en
/// [ArtworkReference].
ArtworkReference localArtworkReference(int? albumId) => albumId == null
    ? const UnavailableArtworkReference()
    : LocalArtworkReference(albumId);
