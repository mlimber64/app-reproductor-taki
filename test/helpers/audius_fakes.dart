import 'dart:convert';
import 'dart:typed_data';

import 'package:taki/core/domain/ports/artwork_http_client.dart';
import 'package:taki/features/audius/domain/entities/audius_track.dart';
import 'package:taki/features/audius/domain/ports/audius_api.dart';

/// Body of one track as the Audius API sends it.
Map<String, dynamic> audiusJson(
  String id, {
  String title = 'Song',
  String artist = 'Artist',
  int duration = 120,
  Object? license = 'All rights reserved',
  bool streamable = true,
  bool deleted = false,
  bool? streamAccess,
  bool artwork = true,
}) =>
    {
      'id': id,
      'title': title,
      'duration': duration,
      'permalink': '/$artist/$id',
      'license': license,
      'is_streamable': streamable,
      'is_delete': deleted,
      if (streamAccess != null)
        'access': {'stream': streamAccess, 'download': false},
      'user': {'name': artist},
      if (artwork)
        'artwork': {
          '150x150': 'https://cdn.example/$id/150x150.jpg',
          '480x480': 'https://cdn.example/$id/480x480.jpg',
          '1000x1000': 'https://cdn.example/$id/1000x1000.jpg',
        },
    };

String audiusBody(List<Map<String, dynamic>> tracks) =>
    jsonEncode({'data': tracks});

/// HTTP transport that records the URIs and answers what it is told.
class FakeAudiusHttp implements ArtworkHttpClient {
  FakeAudiusHttp({this.status = 200, String? body, this.error})
      : body = body ?? audiusBody([audiusJson('a1'), audiusJson('a2')]);

  int status;
  String body;
  Object? error;
  final List<Uri> requests = [];

  @override
  Future<ArtworkHttpResponse> get(
    Uri uri, {
    required Duration timeout,
    required int maxBytes,
  }) async {
    requests.add(uri);
    final error = this.error;
    if (error != null) throw error;
    return ArtworkHttpResponse(
      status,
      Uint8List.fromList(utf8.encode(body)),
    );
  }
}

AudiusTrack buildAudiusTrack(
  String id, {
  String title = 'Song',
  String? artist = 'Artist',
  String? license = 'All rights reserved',
  String? permalink,
}) =>
    AudiusTrack(
      id: id,
      title: title,
      artistName: artist,
      durationSeconds: 120,
      artworkUrl: 'https://cdn.example/$id/480x480.jpg',
      permalink: permalink ?? '/artist/$id',
      license: license,
    );

/// `AudiusApi` fake with fixed tracks; it records what it was asked.
class FakeAudiusApi implements AudiusApi {
  FakeAudiusApi({this.tracks = const [], this.error});

  List<AudiusTrack> tracks;
  Object? error;
  int idCalls = 0;
  final List<({AudiusTrendingWindow window, String? genre})> trendingCalls = [];
  int undergroundCalls = 0;
  final List<String> searches = [];

  AudiusTrackPage get _page => AudiusTrackPage(tracks, hasMore: false);

  @override
  Future<AudiusTrackPage> searchTracks({
    required String query,
    required int limit,
    required int offset,
  }) async {
    searches.add(query);
    if (error != null) throw error!;
    return _page;
  }

  @override
  Future<AudiusTrackPage> trending({
    required AudiusTrendingWindow window,
    String? genre,
    required int limit,
    required int offset,
  }) async {
    trendingCalls.add((window: window, genre: genre));
    if (error != null) throw error!;
    return _page;
  }

  @override
  Future<AudiusTrackPage> underground({
    required int limit,
    required int offset,
  }) async {
    undergroundCalls++;
    if (error != null) throw error!;
    return _page;
  }

  @override
  Future<List<AudiusTrack>> tracksByIds(Iterable<String> ids) async {
    idCalls++;
    if (error != null) throw error!;
    final wanted = ids.toSet();
    return [
      for (final track in tracks)
        if (wanted.contains(track.id)) track,
    ];
  }

  @override
  String streamUrl(String id) => 'https://stream.example/$id';
}
