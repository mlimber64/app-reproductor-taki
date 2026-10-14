import 'package:equatable/equatable.dart';

import 'artwork_reference.dart';
import 'music_identity.dart';

/// Canción **universal**, independiente de la fuente que la provee.
///
/// Solo lleva lo que cualquier fuente puede dar:
/// - [musicIdentity]: «¿qué canción es?» (fuente + id externo). Es lo que se
///   **persiste** (favoritos y playlists guardan fuente + id externo).
/// - metadata: [title], [artist], [album], [durationMs].
/// - [artwork]: la carátula tal como la fuente la entrega.
///
/// No dice dónde está el audio (eso es `PlaybackResource`, que se resuelve bajo
/// demanda) ni conoce MediaStore: los datos propios de la biblioteca local
/// (`id`, `albumId`, `path`, `contentUri`, `folder`) viven en `LocalSong`.
/// Una fuente remota crea directamente `Song` con su `MusicIdentity` y su
/// `ArtworkReference`, sin subclase.
///
/// Igualdad por valor (Equatable, que también compara el tipo en ejecución: una
/// `Song` nunca es igual a una `LocalSong`).
class Song extends Equatable {
  const Song({
    required this.musicIdentity,
    required this.title,
    required this.artist,
    required this.album,
    required this.artwork,
    required this.durationMs,
  });

  /// Identidad de la canción; no dice dónde está el audio ni la portada.
  final MusicIdentity musicIdentity;
  final String title;

  /// `null` cuando la fuente no conoce el artista.
  final String? artist;

  /// `null` cuando la fuente no conoce el álbum.
  final String? album;

  /// Carátula **tal como la fuente la entrega** para esta canción: local
  /// (`LocalArtworkReference`), remota (`RemoteArtworkReference`) o
  /// `UnavailableArtworkReference`. La UI la usa tal cual
  /// (`AlbumArtworkBuilder.reference`) sin saber de dónde viene.
  ///
  /// Es un campo explícito: no se deriva de [musicIdentity] y **no se
  /// persiste**: es metadata de la fuente, no parte de la identidad guardada.
  final ArtworkReference artwork;
  final int durationMs;

  Duration get duration => Duration(milliseconds: durationMs);

  @override
  List<Object?> get props => [
        musicIdentity,
        title,
        artist,
        album,
        artwork,
        durationMs,
      ];
}
