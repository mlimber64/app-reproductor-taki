import '../entities/audius_track.dart';

/// Chart windows of Audius that Taki uses.
enum AudiusTrendingWindow { week, month }

/// Access to the Audius API. The domain knows nothing about HTTP, URIs or
/// JSON. Failures are thrown as `AudiusException`.
abstract interface class AudiusApi {
  /// Text search over titles, artists and tags.
  Future<AudiusTrackPage> searchTracks({
    required String query,
    required int limit,
    required int offset,
  });

  /// Most played tracks of [window], optionally of one [genre] (Audius genre
  /// names, e.g. `Hip-Hop/Rap`).
  Future<AudiusTrackPage> trending({
    required AudiusTrendingWindow window,
    String? genre,
    required int limit,
    required int offset,
  });

  /// Emerging tracks, newest first within the chart.
  Future<AudiusTrackPage> underground({
    required int limit,
    required int offset,
  });

  /// Tracks by id, in one request. Unknown or unplayable ids do not appear.
  Future<List<AudiusTrack>> tracksByIds(Iterable<String> ids);

  /// Stream URL of a track. It is built, not fetched: the server answers with
  /// a redirect to a signed content node each time it is opened.
  String streamUrl(String id);
}
