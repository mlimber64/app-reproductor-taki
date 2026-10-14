import '../entities/artwork_exception.dart';
import '../entities/artwork_reference.dart';
import '../entities/local_music_identity.dart';
import '../entities/local_song.dart';
import '../entities/song.dart';
import '../ports/artwork_resolver.dart';

/// Resolvedor de la fuente local: la carátula sale del `albumId` que la propia
/// canción local ya trae. Dart puro, sin E/S y sin consultar MediaStore.
///
/// - Identidad de otra fuente → [ArtworkResolutionException] (error de
///   enrutamiento, no «sin carátula»).
/// - Identidad local pero sin datos locales (no es una [LocalSong]) →
///   `UnavailableArtworkReference` (no hay `albumId` que leer).
/// - `albumId` nulo → `UnavailableArtworkReference`.
/// - Si no, `LocalArtworkReference(albumId)`.
class LocalArtworkResolver implements ArtworkResolver {
  const LocalArtworkResolver();

  @override
  Future<ArtworkReference> resolve(Song song) async {
    final identity = song.musicIdentity;
    if (identity.source != localMusicSource) {
      throw ArtworkResolutionException(
        'la fuente «${identity.source}» no es la local',
      );
    }
    // Límite entre el contrato universal (`Song`) y los datos locales.
    if (song is! LocalSong) return const UnavailableArtworkReference();
    return localArtworkReference(song.albumId);
  }
}

/// Enruta cada canción al resolvedor de **su fuente** (`musicIdentity.source`).
///
/// Es el punto donde un proveedor futuro se registra sin tocar la UI ni el
/// cache: basta añadir su etiqueta de fuente al mapa. Una fuente sin resolvedor
/// registrado no aporta información suficiente → `UnavailableArtworkReference`
/// (explícito, sin inventar nada).
class SourceArtworkResolver implements ArtworkResolver {
  SourceArtworkResolver(Map<String, ArtworkResolver> bySource)
      : _bySource = Map.unmodifiable(bySource);

  final Map<String, ArtworkResolver> _bySource;

  @override
  Future<ArtworkReference> resolve(Song song) async {
    final resolver = _bySource[song.musicIdentity.source];
    if (resolver == null) return const UnavailableArtworkReference();
    return resolver.resolve(song);
  }
}

/// Resolver para fuentes cuyas canciones ya traen su [Song.artwork]: no hace
/// ninguna llamada, devuelve la referencia que la canción ya contiene.
class SongArtworkResolver implements ArtworkResolver {
  const SongArtworkResolver();

  @override
  Future<ArtworkReference> resolve(Song song) async => song.artwork;
}
