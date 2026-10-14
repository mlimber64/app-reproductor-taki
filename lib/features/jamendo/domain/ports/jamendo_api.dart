import '../entities/jamendo_track.dart';

/// Acceso a la API de Jamendo. El dominio no conoce HTTP, URIs, JSON ni el
/// `client_id`. Los fallos se lanzan como `JamendoException`.
abstract interface class JamendoApi {
  /// Búsqueda por título ([name]), artista o etiqueta.
  Future<JamendoTrackPage> searchTracks({
    String? name,
    String? artistName,
    String? tag,
    required int limit,
    required int offset,
  });

  /// Tracks por id, en lote. Los ids inexistentes simplemente no aparecen.
  Future<List<JamendoTrack>> tracksByIds(Iterable<String> ids);
}
