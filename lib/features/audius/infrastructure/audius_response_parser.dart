import 'dart:convert';

import '../domain/entities/audius_exception.dart';
import '../domain/entities/audius_track.dart';

/// Result of parsing a track listing.
typedef AudiusParsedTracks = ({List<AudiusTrack> tracks, int rawCount});

/// Validates an Audius response and returns its playable tracks.
///
/// Audius wraps listings as `{"data": [...]}`. A track that is deleted, not
/// streamable, gated for streaming, or without `id`/`title` is skipped:
/// it could not be played anyway. [AudiusParsedTracks.rawCount] counts what
/// the API sent, so paging does not mistake a filtered page for the last one.
AudiusParsedTracks parseAudiusTracks(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    throw const AudiusMalformedResponseException('the body is not JSON');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const AudiusMalformedResponseException('an object was expected');
  }
  final data = decoded['data'];
  if (data is! List<dynamic>) {
    throw const AudiusMalformedResponseException('data is missing');
  }

  final tracks = <AudiusTrack>[];
  for (final item in data) {
    if (item is! Map<String, dynamic>) continue;
    final track = _parseTrack(item);
    if (track != null) tracks.add(track);
  }
  return (tracks: tracks, rawCount: data.length);
}

AudiusTrack? _parseTrack(Map<String, dynamic> json) {
  final id = json['id'];
  final title = json['title'];
  if (id is! String || id.trim().isEmpty) return null;
  if (title is! String || title.trim().isEmpty) return null;

  if (json['is_delete'] == true) return null;
  if (json['is_streamable'] == false) return null;
  final access = json['access'];
  if (access is Map<String, dynamic> && access['stream'] == false) return null;

  final user = json['user'];
  final artist = user is Map<String, dynamic> ? user['name'] : null;
  final duration = json['duration'];

  return AudiusTrack(
    id: id,
    title: title,
    artistName: artist is String ? artist : null,
    durationSeconds: duration is num ? duration.toInt() : 0,
    artworkUrl: _artworkUrl(json['artwork']),
    permalink: json['permalink'] is String ? json['permalink'] as String : null,
    license: json['license'] is String ? json['license'] as String : null,
  );
}

/// Prefers the 480 px cover; falls back to the closest size that exists.
String? _artworkUrl(Object? artwork) {
  if (artwork is! Map<String, dynamic>) return null;
  for (final size in const ['480x480', '1000x1000', '150x150']) {
    final url = artwork[size];
    if (url is String && url.trim().isNotEmpty) return url;
  }
  return null;
}
