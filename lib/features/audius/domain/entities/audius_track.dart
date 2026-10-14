import '../../../../core/domain/entities/music_identity.dart';
import '../../../../core/domain/entities/provider_attribution.dart';

/// Source identifier of Audius in `MusicIdentity.source`.
const String audiusSource = 'audius';

/// Audius name shown in the attribution.
const String audiusProviderName = 'Audius';

/// Public site the track permalinks are relative to.
const String audiusSiteHost = 'audius.co';

/// A track as the Audius API delivers it (only the observed fields).
///
/// It is provider specific and never persisted. Unlike a Creative Commons
/// catalog, Audius does not guarantee a license: [license] is whatever the
/// artist declared, and it is often "All rights reserved" or absent.
final class AudiusTrack {
  const AudiusTrack({
    required this.id,
    required this.title,
    this.artistName,
    this.durationSeconds = 0,
    this.artworkUrl,
    this.permalink,
    this.license,
  });

  /// Hashed track id (e.g. `DX0Xb`), kept as text and never normalized.
  final String id;
  final String title;
  final String? artistName;
  final int durationSeconds;

  /// Square cover, already sized by the API.
  final String? artworkUrl;

  /// Path of the track on the Audius site (`/artist/track-slug`).
  final String? permalink;

  /// License label as declared by the artist; `null` when not declared.
  final String? license;

  /// What the UI must show for this track. Missing data stays `null`; the page
  /// link is only built from a well-formed permalink, never guessed.
  ProviderAttribution get attribution => ProviderAttribution(
        identity: MusicIdentity(audiusSource, id),
        providerName: audiusProviderName,
        pageUrl: _pageUri(permalink),
        licenseName: _licenseLabel(license),
      );
}

Uri? _pageUri(String? permalink) {
  final path = permalink?.trim();
  if (path == null || !path.startsWith('/') || path.length < 2) return null;
  final uri = Uri.tryParse(path);
  if (uri == null || uri.hasAuthority || uri.hasScheme) return null;
  return Uri.https(audiusSiteHost, path);
}

String? _licenseLabel(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  return value;
}

/// One page of tracks. [hasMore]: the API returned as many as were asked.
final class AudiusTrackPage {
  const AudiusTrackPage(this.tracks, {required this.hasMore});

  final List<AudiusTrack> tracks;
  final bool hasMore;
}
