import 'dart:convert';

import '../../../core/domain/entities/lyrics.dart';
import '../../../core/domain/ports/artwork_http_client.dart';
import '../../../core/domain/ports/lyrics_source.dart';
import '../../../core/domain/services/lrc_parser.dart';

/// [LyricsSource] over LRCLIB (`lrclib.net`), a free, key-less lyrics service
/// with synchronized lyrics.
///
/// 1. `GET /api/get` with title, artist and duration: an exact match.
/// 2. If that finds nothing (404), `GET /api/search` by title and artist, and
///    the candidate whose duration is closest (within [durationTolerance]) is
///    taken, preferring one with synchronized lyrics.
///
/// Reuses the generic [ArtworkHttpClient] as the GET transport. No exception
/// carries the URI or the original cause: the query holds the song's title and
/// artist.
class LrclibLyricsSource implements LyricsSource {
  LrclibLyricsSource(
    this._http, {
    this.host = 'lrclib.net',
    this.timeout = const Duration(seconds: 10),
    this.maxBytes = 2 * 1024 * 1024,
    this.durationTolerance = const Duration(seconds: 3),
  });

  final ArtworkHttpClient _http;
  final String host;
  final Duration timeout;
  final int maxBytes;
  final Duration durationTolerance;

  @override
  Future<Lyrics?> find(LyricsQuery query) async {
    final title = query.title.trim();
    if (title.isEmpty) return null;
    final artist = query.artist?.trim();
    final hasArtist = artist != null && artist.isNotEmpty;

    if (hasArtist) {
      final exact = await _get(
        Uri.https(host, '/api/get', {
          'track_name': title,
          'artist_name': artist,
          if (query.durationSeconds != null && query.durationSeconds! > 0)
            'duration': '${query.durationSeconds}',
        }),
      );
      if (exact != null) {
        final decoded = _decode(exact);
        if (decoded is Map<String, dynamic>) {
          final lyrics = _toLyrics(decoded);
          if (lyrics != null) return lyrics;
        }
      }
    }

    final found = await _get(
      Uri.https(host, '/api/search', {
        'track_name': title,
        if (hasArtist) 'artist_name': artist,
      }),
    );
    if (found == null) return null;
    final decoded = _decode(found);
    if (decoded is! List<dynamic>) {
      throw const LyricsLookupFailure('unexpected search answer');
    }
    return _bestMatch(decoded, query.durationSeconds);
  }

  /// The body of a 2xx answer, `null` for a 404 and a failure otherwise.
  Future<String?> _get(Uri uri) async {
    final ArtworkHttpResponse response;
    try {
      response = await _http.get(uri, timeout: timeout, maxBytes: maxBytes);
    } catch (error) {
      throw LyricsLookupFailure('network failure (${error.runtimeType})');
    }
    if (response.statusCode == 404) return null;
    if (response.statusCode < 200 || response.statusCode > 299) {
      throw LyricsLookupFailure('HTTP ${response.statusCode}');
    }
    try {
      return utf8.decode(response.bodyBytes);
    } on FormatException {
      throw const LyricsLookupFailure('invalid UTF-8');
    }
  }

  Object? _decode(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      throw const LyricsLookupFailure('the body is not JSON');
    }
  }

  Lyrics? _bestMatch(List<dynamic> candidates, int? durationSeconds) {
    Lyrics? best;
    var bestScore = double.infinity;
    for (final item in candidates) {
      if (item is! Map<String, dynamic>) continue;
      final lyrics = _toLyrics(item);
      if (lyrics == null) continue;

      var score = 0.0;
      final duration = item['duration'];
      if (durationSeconds != null && duration is num) {
        final diff = (duration - durationSeconds).abs();
        if (diff > durationTolerance.inSeconds) continue;
        score += diff;
      }
      // Synchronized lyrics beat plain ones at the same distance.
      if (!lyrics.isSynced) score += 0.5;
      if (score < bestScore) {
        best = lyrics;
        bestScore = score;
      }
    }
    return best;
  }

  Lyrics? _toLyrics(Map<String, dynamic> json) {
    if (json['instrumental'] == true) {
      return const Lyrics(instrumental: true);
    }
    final synced = json['syncedLyrics'];
    final plain = json['plainLyrics'];
    final lines = synced is String ? parseLrc(synced) : const <LyricLine>[];
    final text = plain is String && plain.trim().isNotEmpty ? plain : null;
    final lyrics = Lyrics(lines: lines, text: text);
    return lyrics.hasContent ? lyrics : null;
  }
}
