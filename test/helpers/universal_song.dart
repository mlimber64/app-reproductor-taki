import 'package:taki/core/domain/entities/artwork_reference.dart';
import 'package:taki/core/domain/entities/music_identity.dart';
import 'package:taki/core/domain/entities/song.dart';

/// `Song` universal de **cualquier fuente** (solo para pruebas): sin subclase y
/// sin campos locales, como la crearía un proveedor remoto.
///
/// Sirve para probar persistencia, cola y UI con identidades que no son locales
/// (ids alfanuméricos, con ceros a la izquierda, en otras fuentes…) sin
/// implementar ninguna fuente. [artwork] es la que la «fuente» entrega (remota
/// o no disponible).
Song buildUniversalSong(
  MusicIdentity identity, {
  String title = 'Remota',
  String? artist = 'Artista',
  String? album = 'Álbum',
  int durationMs = 200000,
  ArtworkReference artwork = const UnavailableArtworkReference(),
}) {
  return Song(
    musicIdentity: identity,
    title: title,
    artist: artist,
    album: album,
    artwork: artwork,
    durationMs: durationMs,
  );
}
