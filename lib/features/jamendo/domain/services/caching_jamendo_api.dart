import '../../../../core/domain/entities/music_identity.dart';
import '../entities/jamendo_track.dart';
import '../ports/jamendo_api.dart';
import 'jamendo_audio_cache.dart';

/// Decorador: cada track que pasa guarda su URL de audio en la caché en
/// memoria.
class CachingJamendoApi implements JamendoApi {
  CachingJamendoApi(this._inner, this._cache);

  final JamendoApi _inner;
  final JamendoAudioCache _cache;

  @override
  Future<JamendoTrackPage> searchTracks({
    String? name,
    String? artistName,
    String? tag,
    required int limit,
    required int offset,
  }) async {
    final page = await _inner.searchTracks(
      name: name,
      artistName: artistName,
      tag: tag,
      limit: limit,
      offset: offset,
    );
    _remember(page.tracks);
    return page;
  }

  @override
  Future<JamendoTrackPage> listTracks({
    required JamendoTrackOrder order,
    String? tag,
    required int limit,
    required int offset,
  }) async {
    final page = await _inner.listTracks(
      order: order,
      tag: tag,
      limit: limit,
      offset: offset,
    );
    _remember(page.tracks);
    return page;
  }

  @override
  Future<List<JamendoTrack>> tracksByIds(Iterable<String> ids) async {
    final tracks = await _inner.tracksByIds(ids);
    _remember(tracks);
    return tracks;
  }

  void _remember(List<JamendoTrack> tracks) {
    for (final track in tracks) {
      final audio = track.audio;
      if (audio != null && audio.trim().isNotEmpty) {
        _cache.put(MusicIdentity(jamendoSource, track.id), audio);
      }
    }
  }
}
