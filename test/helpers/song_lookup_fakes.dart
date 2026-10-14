import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/core/domain/entities/song.dart';
import 'package:taki/core/domain/entities/song_lookup_result.dart';
import 'package:taki/core/domain/ports/song_lookup.dart';

/// Lookup de una fuente de prueba: resuelve las identidades de [songs] y
/// declara `missing` el resto. Registra lo que se le pidió.
class FakeSourceLookup implements SongLookup {
  FakeSourceLookup([Iterable<Song> songs = const []])
      : songs = {for (final song in songs) song.musicIdentity: song};

  final Map<MusicIdentity, Song> songs;
  final requests = <Set<MusicIdentity>>[];

  /// Si no es null, se lanza en vez de resolver.
  Object? failure;

  @override
  Future<SongLookupResult> findAll(Iterable<MusicIdentity> identities) async {
    final wanted = identities.toSet();
    requests.add(wanted);
    final error = failure;
    if (error != null) throw error;
    return SongLookupResult(
      found: {
        for (final identity in wanted) identity: ?songs[identity],
      },
      missing: {
        for (final identity in wanted)
          if (!songs.containsKey(identity)) identity,
      },
    );
  }
}

/// Lookup que devuelve exactamente [result], sin mirar lo pedido (para probar
/// que el router hace cumplir el contrato).
class ScriptedLookup implements SongLookup {
  ScriptedLookup(this.result);

  final SongLookupResult result;

  @override
  Future<SongLookupResult> findAll(Iterable<MusicIdentity> identities) async =>
      result;
}
