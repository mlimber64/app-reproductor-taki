import '../entities/jamendo_track.dart';

/// Órdenes de listado de Jamendo que Taki usa.
enum JamendoTrackOrder {
  /// Más escuchados de la semana.
  popularityWeek,

  /// Más escuchados del mes.
  popularityMonth,

  /// Lanzados más recientemente primero.
  releaseDateDesc,
}

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

  /// Tracks sin criterio de texto, en el orden [order] y, opcionalmente, de
  /// una etiqueta ([tag], p. ej. un género).
  Future<JamendoTrackPage> listTracks({
    required JamendoTrackOrder order,
    String? tag,
    required int limit,
    required int offset,
  });

  /// Tracks por id, en lote. Los ids inexistentes simplemente no aparecen.
  Future<List<JamendoTrack>> tracksByIds(Iterable<String> ids);
}
