import '../../../../core/domain/entities/music_identity.dart';
import '../../../../core/domain/entities/playback_resolution_exception.dart';
import '../../../../core/domain/entities/playback_resource.dart';
import '../../../../core/domain/entities/song.dart';
import '../../../../core/domain/ports/playback_resolver.dart';
import '../entities/jamendo_exception.dart';
import '../entities/jamendo_track.dart';
import '../ports/jamendo_api.dart';
import 'jamendo_audio_cache.dart';

/// Resuelve la URL de streaming de una canción de Jamendo.
///
/// La URL **no** está en `Song`: se consulta por identidad (o sale de la caché
/// en memoria). Es temporal, no se persiste y no hay modo offline.
///
/// **Single-flight por `MusicIdentity`:** si la misma identidad se pide mientras
/// su resolución sigue pendiente (p. ej. la misma canción dos veces en una cola
/// fría), todas comparten **una** consulta. La entrada en vuelo se retira al
/// terminar (con éxito o con fallo), así que un fallo nunca se recuerda: el
/// siguiente intento vuelve a resolver. La caché sigue siendo solo de memoria.
class JamendoPlaybackResolver implements PlaybackResolver {
  JamendoPlaybackResolver(this._api, this._cache);

  final JamendoApi _api;
  final JamendoAudioCache _cache;
  final Map<MusicIdentity, Future<PlaybackResource>> _inFlight = {};

  @override
  Future<PlaybackResource> resolve(Song song) async {
    final identity = song.musicIdentity;
    if (identity.source != jamendoSource) throw IdentityNotFound(identity);

    final cached = _cache.get(identity);
    if (cached != null) return RemoteUriResource(cached);

    return _inFlight[identity] ??= _fetch(identity).whenComplete(() {
      // Bloque sin valor: `remove` devuelve este mismo futuro y, si el callback
      // lo devolviera, `whenComplete` lo esperaría (nunca terminaría).
      _inFlight.remove(identity);
    });
  }

  Future<PlaybackResource> _fetch(MusicIdentity identity) async {
    final List<JamendoTrack> tracks;
    try {
      tracks = await _api.tracksByIds([identity.externalId]);
    } on JamendoException catch (error) {
      throw PlaybackResolutionError(
        'no se pudo resolver el audio en Jamendo',
        cause: error,
      );
    } catch (error) {
      throw PlaybackResolutionError(
        'fallo inesperado resolviendo el audio',
        cause: error.runtimeType,
      );
    }

    final track = tracks.where((t) => t.id == identity.externalId).firstOrNull;
    if (track == null) throw IdentityNotFound(identity);

    final audio = track.audio;
    if (audio == null || audio.trim().isEmpty) {
      return const UnavailableResource(reason: 'Jamendo no entregó audio');
    }
    _cache.put(identity, audio);
    return RemoteUriResource(audio);
  }
}
