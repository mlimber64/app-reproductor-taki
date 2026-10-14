import 'dart:math';

import '../../../../core/domain/entities/artwork_reference.dart';
import '../../../../core/domain/entities/music_identity.dart';
import '../../../../core/domain/entities/song.dart';
import '../entities/jamendo_track.dart';

/// Ancho (px) con el que se pide la portada. Jamendo solo devuelve imágenes
/// cuadradas exactas para 25…600 (verificado en el spike; 1000 falla y sin
/// `width` también).
const int jamendoArtworkWidth = 300;
const int jamendoArtworkMinWidth = 25;
const int jamendoArtworkMaxWidth = 600;

/// `JamendoTrack` → `Song`. No lleva audio, `shareurl` ni licencia.
Song songFromJamendoTrack(JamendoTrack track) => Song(
      musicIdentity: MusicIdentity(jamendoSource, track.id),
      title: track.name,
      artist: _nonBlank(track.artistName),
      album: _nonBlank(track.albumName),
      artwork: jamendoArtworkReference(track.albumImage),
      durationMs: max(0, track.durationSeconds) * 1000,
    );

/// Referencia remota con `width` fijado; sin imagen utilizable, no disponible.
ArtworkReference jamendoArtworkReference(
  String? albumImage, {
  int width = jamendoArtworkWidth,
}) {
  if (width < jamendoArtworkMinWidth || width > jamendoArtworkMaxWidth) {
    throw ArgumentError.value(
      width,
      'width',
      'Jamendo solo entrega $jamendoArtworkMinWidth…$jamendoArtworkMaxWidth px',
    );
  }
  final raw = albumImage?.trim();
  if (raw == null || raw.isEmpty) return const UnavailableArtworkReference();
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      !(uri.scheme == 'http' || uri.scheme == 'https') ||
      uri.host.isEmpty) {
    return const UnavailableArtworkReference();
  }
  final sized = uri.replace(
    queryParameters: {...uri.queryParameters, 'width': '$width'},
  );
  return RemoteArtworkReference(sized.toString(), width: width, height: width);
}

String? _nonBlank(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return value;
}
