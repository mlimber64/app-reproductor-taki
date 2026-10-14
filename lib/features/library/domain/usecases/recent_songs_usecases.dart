import '../../../../core/domain/entities/music_identity.dart';
import '../../../../core/domain/entities/song.dart';
import '../../../../core/domain/ports/song_lookup.dart';

/// Turns recently played identities into songs, keeping their order.
///
/// Identities that cannot be resolved (a file that was deleted, a source that
/// is down) are left out of the list but not forgotten: they come back if the
/// song does. A failing source never breaks the list; if the lookup itself
/// fails as a whole, the failure reaches the caller.
class GetRecentSongs {
  const GetRecentSongs(this._lookup);

  final SongLookup _lookup;

  Future<List<Song>> call(List<MusicIdentity> identities) async {
    if (identities.isEmpty) return const [];
    final result = await _lookup.findAll(identities);
    return [
      for (final identity in identities)
        ?result.found[identity],
    ];
  }
}
