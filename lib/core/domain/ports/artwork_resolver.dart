import '../entities/artwork_reference.dart';
import '../entities/song.dart';

/// Decide **qué recurso visual representa** una canción.
///
/// Recibe la [Song] (identidad + metadata ya cargada por su fuente), igual que
/// `PlaybackResolver`. No recibe solo `MusicIdentity` porque la identidad no
/// contiene lo que la carátula local necesita (`albumId`): resolver desde la
/// identidad obligaría a volver a consultar MediaStore. Las fuentes remotas
/// deben decidir con `song.musicIdentity`; solo la local lee `albumId`.
///
/// Contrato:
/// - Devuelve `UnavailableArtworkReference` si se sabe que no hay carátula o si
///   la fuente no aporta información suficiente (nunca se inventan URL).
/// - Lanza `ArtworkResolutionException` si la resolución falla.
/// - No devuelve `null`.
///
/// Solo resuelve: no descarga ni lee imágenes (eso es de `ArtworkCache` y
/// `RemoteArtworkLoader`).
abstract interface class ArtworkResolver {
  Future<ArtworkReference> resolve(Song song);
}
