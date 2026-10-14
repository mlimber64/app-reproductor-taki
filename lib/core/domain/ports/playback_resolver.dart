import '../entities/playback_resource.dart';
import '../entities/song.dart';

/// Decide **cómo puede reproducirse** una canción.
///
/// Recibe la [Song] (identidad + metadata, ya cargada por su fuente) y devuelve
/// un [PlaybackResource]. Las decisiones deben basarse en `song.musicIdentity`;
/// solo la fuente local lee, además, sus propios datos locales de la canción.
/// Así el recurso no se guarda en la canción ni en la cola: se obtiene cuando
/// se necesita.
///
/// Contrato:
/// - Devuelve [UnavailableResource] si la canción existe pero no hay recurso
///   reproducible.
/// - Lanza `IdentityNotFound` si la identidad no es de este resolvedor.
/// - Lanza `PlaybackResolutionError` si la resolución falla. Nunca deja
///   escapar errores de HTTP, de un SDK ni de MediaStore.
/// - No devuelve `null`.
///
/// Solo resuelve: no reproduce, no descarga ni obtiene artwork.
abstract interface class PlaybackResolver {
  Future<PlaybackResource> resolve(Song song);
}
