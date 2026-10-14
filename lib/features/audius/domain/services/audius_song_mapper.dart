import 'dart:math';

import '../../../../core/domain/entities/artwork_reference.dart';
import '../../../../core/domain/entities/music_identity.dart';
import '../../../../core/domain/entities/song.dart';
import '../entities/audius_track.dart';

/// Side (px) of the square cover Taki asks Audius for.
const int audiusArtworkSize = 480;

/// `AudiusTrack` → `Song`. It carries no stream URL and no license.
Song songFromAudiusTrack(AudiusTrack track) => Song(
      musicIdentity: MusicIdentity(audiusSource, track.id),
      title: track.title,
      artist: _nonBlank(track.artistName),
      album: null,
      artwork: audiusArtworkReference(track.artworkUrl),
      durationMs: max(0, track.durationSeconds) * 1000,
    );

/// Remote reference for a cover URL; without a usable one, unavailable.
ArtworkReference audiusArtworkReference(String? url) {
  final raw = url?.trim();
  if (raw == null || raw.isEmpty) return const UnavailableArtworkReference();
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      !(uri.scheme == 'http' || uri.scheme == 'https') ||
      uri.host.isEmpty) {
    return const UnavailableArtworkReference();
  }
  return RemoteArtworkReference(
    raw,
    width: audiusArtworkSize,
    height: audiusArtworkSize,
  );
}

String? _nonBlank(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return value;
}
