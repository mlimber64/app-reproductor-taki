import 'dart:convert';

import '../../../core/domain/ports/artwork_http_client.dart';
import '../domain/entities/audius_exception.dart';
import '../domain/entities/audius_track.dart';
import '../domain/ports/audius_api.dart';
import 'audius_response_parser.dart';

/// [AudiusApi] over HTTP.
///
/// Reuses the generic [ArtworkHttpClient] as the GET transport (bytes, status,
/// timeout and size cap), like the other remote providers. Audius needs no
/// key; `app_name` only identifies the app to the service.
///
/// No exception includes the URI or the original cause.
class HttpAudiusApi implements AudiusApi {
  HttpAudiusApi(
    this._http, {
    this.timeout = const Duration(seconds: 10),
    this.maxBytes = 4 * 1024 * 1024,
    this.host = 'api.audius.co',
    this.appName = 'taki',
  });

  /// Ids per request when looking tracks up in a batch.
  static const int maxIdsPerRequest = 50;

  final ArtworkHttpClient _http;
  final Duration timeout;
  final int maxBytes;
  final String host;
  final String appName;

  @override
  Future<AudiusTrackPage> searchTracks({
    required String query,
    required int limit,
    required int offset,
  }) =>
      _page(
        '/v1/tracks/search',
        {'query': query, 'limit': '$limit', 'offset': '$offset'},
        limit,
      );

  @override
  Future<AudiusTrackPage> trending({
    required AudiusTrendingWindow window,
    String? genre,
    required int limit,
    required int offset,
  }) =>
      _page(
        '/v1/tracks/trending',
        {
          'time': switch (window) {
            AudiusTrendingWindow.week => 'week',
            AudiusTrendingWindow.month => 'month',
          },
          if (genre != null && genre.trim().isNotEmpty) 'genre': genre,
          'limit': '$limit',
          'offset': '$offset',
        },
        limit,
      );

  @override
  Future<AudiusTrackPage> underground({
    required int limit,
    required int offset,
  }) =>
      _page(
        '/v1/tracks/trending/underground',
        {'limit': '$limit', 'offset': '$offset'},
        limit,
      );

  @override
  Future<List<AudiusTrack>> tracksByIds(Iterable<String> ids) async {
    final unique = ids.toSet().toList();
    if (unique.isEmpty) return const [];
    final found = <AudiusTrack>[];
    for (var i = 0; i < unique.length; i += maxIdsPerRequest) {
      final end = i + maxIdsPerRequest > unique.length
          ? unique.length
          : i + maxIdsPerRequest;
      final chunk = unique.sublist(i, end);
      // `id` repeats once per track; a Map cannot, so the query is built here.
      final query = [
        for (final id in chunk) 'id=${Uri.encodeQueryComponent(id)}',
        'app_name=${Uri.encodeQueryComponent(appName)}',
      ].join('&');
      final parsed = await _get(Uri(
        scheme: 'https',
        host: host,
        path: '/v1/tracks',
        query: query,
      ));
      found.addAll(parsed.tracks);
    }
    return found;
  }

  @override
  String streamUrl(String id) => Uri.https(
        host,
        '/v1/tracks/${Uri.encodeComponent(id)}/stream',
        {'app_name': appName},
      ).toString();

  Future<AudiusTrackPage> _page(
    String path,
    Map<String, String> params,
    int limit,
  ) async {
    final parsed = await _get(Uri.https(host, path, {
      ...params,
      'app_name': appName,
    }));
    return AudiusTrackPage(parsed.tracks, hasMore: parsed.rawCount >= limit);
  }

  Future<AudiusParsedTracks> _get(Uri uri) async {
    final ArtworkHttpResponse response;
    try {
      response = await _http.get(uri, timeout: timeout, maxBytes: maxBytes);
    } catch (error) {
      throw AudiusNetworkException('network failure (${error.runtimeType})');
    }
    if (response.statusCode < 200 || response.statusCode > 299) {
      throw AudiusNetworkException(
        'HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final String body;
    try {
      body = utf8.decode(response.bodyBytes);
    } on FormatException {
      throw const AudiusMalformedResponseException('invalid UTF-8');
    }
    return parseAudiusTracks(body);
  }
}
