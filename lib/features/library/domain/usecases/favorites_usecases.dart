import '../../../../core/domain/entities/local_music_identity.dart';
import '../../../../core/domain/entities/local_song.dart';
import '../../../../core/domain/entities/music_identity.dart';
import '../../../../core/domain/entities/song.dart';
import '../../../../core/domain/ports/song_lookup.dart';
import '../../../../core/domain/services/isolated_song_lookup.dart';
import '../../../../core/domain/services/song_matcher.dart';
import '../ports/favorites_repository.dart';

/// Marca o desmarca [Song] según su estado actual. Devuelve `true` si quedó
/// como favorita.
class ToggleFavorite {
  const ToggleFavorite(this._favorites);

  final FavoritesRepository _favorites;

  Future<bool> call(Song song) async {
    final identities = await _favorites.watchFavoriteIdentities().first;
    if (identities.contains(song.musicIdentity)) {
      await _favorites.remove(song.musicIdentity);
      return false;
    }
    await _favorites.add(song);
    return true;
  }
}

/// Resuelve los favoritos guardados a canciones, de cualquier fuente.
///
/// 1. Cada identidad guardada se resuelve con el [SongLookup] (identidad →
///    `Song`): una sola llamada por lote, sin suponer que sea local.
/// 2. Solo a los favoritos **locales** que el lookup declara `missing` se les
///    aplica además la política de reencuentro de la fuente local
///    ([SongMatcher]: ruta → título + artista + duración, con
///    [durationTolerance]) sobre [library]. Si así se encuentra con otra
///    identidad (p. ej. el id cambió tras reinstalar), se guarda la nueva
///    (`relink`). El matcher **no** se usa para otras fuentes ni para
///    identidades `unsupported` (un problema de configuración no se tapa).
/// 3. Los que no se resuelven se ocultan pero no se borran (p. ej. la SD está
///    desmontada y la canción vuelve después).
/// 4. Devuelve las canciones en orden de añadido, más recientes primero, sin
///    repetir ninguna.
///
/// El fallo de una fuente (`SongLookupFailure`) afecta **solo a sus
/// identidades** (se ocultan, sin reencuentro ni borrado; nunca pasan a
/// `missing`). Si fallan **todas** las fuentes consultadas, el error llega a
/// quien llama.
class GetFavoriteSongs {
  const GetFavoriteSongs(
    this._favorites,
    this._lookup, {
    this.durationTolerance = const Duration(seconds: 1),
  });

  final FavoritesRepository _favorites;
  final SongLookup _lookup;
  final Duration durationTolerance;

  /// [library] es la biblioteca local, solo para el reencuentro local (2).
  Future<List<Song>> call(List<LocalSong> library) async {
    final entries = await _favorites.getFavorites();
    if (entries.isEmpty) return const [];

    final isolated = await findAllIsolatingSources(_lookup, {
      for (final entry in entries) entry.musicIdentity,
    });
    final resolved = isolated.result;
    final matcher = SongMatcher(library, durationTolerance: durationTolerance);

    final result = <Song>[];
    final seen = <MusicIdentity>{};
    for (final entry in entries) {
      final identity = entry.musicIdentity;
      // Su fuente falló: no se reencuentra, no se relinka ni se borra.
      if (isolated.failed.contains(identity)) continue;
      final song = resolved.found[identity] ??
          (resolved.missing.contains(identity) &&
                  identity.source == localMusicSource
              ? matcher.match(entry)
              : null);
      if (song == null || !seen.add(song.musicIdentity)) continue;

      if (song.musicIdentity != identity) {
        await _favorites.relink(identity, song);
      }
      result.add(song);
    }
    return result;
  }
}