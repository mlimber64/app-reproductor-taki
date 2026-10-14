import 'dart:typed_data';

import 'package:taki/core/artwork/album_artwork_builder.dart';
import 'package:taki/core/domain/entities/artwork_reference.dart';
import 'package:taki/core/domain/entities/local_song.dart';
import 'package:taki/core/domain/ports/remote_artwork_loader.dart';
import 'package:taki/features/playlists/presentation/playlist_cover_albums.dart';
import 'package:taki/features/playlists/presentation/playlist_cover_images.dart';

import 'library_fakes.dart';

/// `albumId` de una referencia local; `null` si no es local (remota o no
/// disponible). Solo para tests: la UI ya no conoce `albumId`.
int? albumIdOf(ArtworkReference? reference) =>
    reference is LocalArtworkReference ? reference.albumId : null;

/// Referencia local a partir de un `albumId` de prueba (`null` → no disponible).
ArtworkReference localRef(int? albumId) => localArtworkReference(albumId);

/// Carátula remota de prueba (nunca se descarga: no hay red en los tests).
final ArtworkReference remoteTestArtwork =
    RemoteArtworkReference('https://cdn.example/cover.jpg');

/// `albumId` de las canciones de [remoteArtworkSong]: existe a propósito y es
/// **distinto de la carátula**, para detectar una UI que lea `albumId`.
const int remoteSongAlbumId = 77;

/// Canción local con `albumId` pero cuya fuente entrega una carátula remota.
LocalSong remoteArtworkSong({
  int id = 70,
  String title = 'Con carátula remota',
  ArtworkReference? artwork,
}) =>
    buildSong(
      id: id,
      title: title,
      albumId: remoteSongAlbumId,
      artwork: artwork ?? remoteTestArtwork,
    );

/// Cargador remoto falso: devuelve `[42]` y registra qué se le pidió.
class FakeRemoteArtworkLoader implements RemoteArtworkLoader {
  final requests = <(RemoteArtworkReference, int)>[];

  @override
  Future<Uint8List?> load(
    RemoteArtworkReference reference, {
    required int size,
  }) async {
    requests.add((reference, size));
    return Uint8List.fromList([42]);
  }
}

/// Lecturas de tests sobre los widgets de artwork, en términos de `albumId`.
extension AlbumArtworkBuilderTestX on AlbumArtworkBuilder {
  int? get albumId => albumIdOf(reference);
}

extension AlbumArtworkMosaicBuilderTestX on AlbumArtworkMosaicBuilder {
  List<int?> get albumIds => [for (final r in references) albumIdOf(r)];
}

extension PlaylistCoverImagesTestX on PlaylistCoverImages {
  List<int?> get albumIds => [for (final r in artwork) albumIdOf(r)];
}

/// `playlistCoverArtwork` expresada en `albumId`, para conservar los casos de
/// prueba de la selección de portada.
///
/// Perezosa (solo consume lo que consume la función real) y no modificable,
/// como `playlistCoverArtwork`.
List<int?> playlistCoverAlbumIds(Iterable<int?> ids) => List.unmodifiable(
      playlistCoverArtwork(
        ids.map((id) => id == null ? null : LocalArtworkReference(id)),
      ).map(albumIdOf),
    );
