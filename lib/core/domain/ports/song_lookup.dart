import '../entities/music_identity.dart';
import '../entities/song_lookup_result.dart';

/// Resuelve **identidades** a canciones: `MusicIdentity → Song`, sin suponer que
/// pertenezcan a la biblioteca local.
///
/// Es solo resolución de identidad. **No** busca por título, **no** hace
/// coincidencias aproximadas (eso es política de cada fuente: p. ej.
/// `SongMatcher` es solo de la fuente local), **no** conoce la UI, SQLite,
/// MediaStore ni HTTP: cada implementación decide cómo resolver las identidades
/// de su fuente.
///
/// Contrato de [findAll]:
/// - Recibe un conjunto de identidades (los duplicados se tratan como una).
/// - Devuelve un [SongLookupResult] donde **cada identidad pedida está en
///   exactamente un cubo**: `found`, `missing` o `unsupported`.
/// - Una identidad de una fuente que esta implementación no maneja va a
///   `unsupported`.
/// - Un fallo transitorio se lanza como `SongLookupFailure`; no se convierte en
///   `missing`.
/// - Es por lotes a propósito: favoritos y playlists resuelven muchas entradas
///   a la vez (una sola lectura de la biblioteca; una sola llamada de red en
///   una fuente remota).
abstract interface class SongLookup {
  Future<SongLookupResult> findAll(Iterable<MusicIdentity> identities);
}
