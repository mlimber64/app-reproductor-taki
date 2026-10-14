import '../../../../core/domain/entities/music_identity.dart';
import '../../../../core/domain/entities/song.dart';
import '../../../../core/domain/entities/song_lookup_failure.dart';
import '../../../../core/domain/entities/song_lookup_result.dart';
import '../../../../core/domain/ports/song_lookup.dart';
import '../entities/jamendo_exception.dart';
import '../entities/jamendo_track.dart';
import '../ports/jamendo_api.dart';
import 'jamendo_song_mapper.dart';

/// Resuelve identidades `jamendo` en lote (una consulta por todas las ids).
///
/// - Las identidades de otras fuentes salen como `unsupported`.
/// - Un id que la API no devuelve es `missing`.
/// - Un track con un id que no se pidió es un fallo del contrato de la API.
/// - Cualquier error de la API sale como [SongLookupFailure].
class JamendoSongLookup implements SongLookup {
  const JamendoSongLookup(this._api);

  final JamendoApi _api;

  @override
  Future<SongLookupResult> findAll(Iterable<MusicIdentity> identities) async {
    final wanted = identities.toSet();
    final mine = {
      for (final identity in wanted)
        if (identity.source == jamendoSource) identity,
    };
    final unsupported = wanted.difference(mine);
    if (mine.isEmpty) return SongLookupResult(unsupported: unsupported);

    final List<JamendoTrack> tracks;
    try {
      tracks = await _api.tracksByIds([for (final i in mine) i.externalId]);
    } on JamendoException catch (error) {
      throw SongLookupFailure(
        'no se pudo consultar Jamendo',
        source: jamendoSource,
        cause: error,
      );
    } catch (error) {
      throw SongLookupFailure(
        'fallo inesperado consultando Jamendo',
        source: jamendoSource,
        cause: error.runtimeType,
      );
    }

    final found = <MusicIdentity, Song>{};
    for (final track in tracks) {
      final identity = MusicIdentity(jamendoSource, track.id);
      if (!mine.contains(identity)) {
        throw const SongLookupFailure(
          'Jamendo devolvió un track que no se pidió',
          source: jamendoSource,
        );
      }
      found[identity] = songFromJamendoTrack(track);
    }
    return SongLookupResult(
      found: found,
      missing: mine.difference(found.keys.toSet()),
      unsupported: unsupported,
    );
  }
}
