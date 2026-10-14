import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:taki/core/domain/ports/artwork_http_client.dart';
import 'package:taki/features/jamendo/domain/entities/jamendo_track.dart';
import 'package:taki/features/jamendo/domain/ports/jamendo_api.dart';

/// `client_id` falso: los tests nunca usan el real.
const String fakeClientId = 'fake-test-client-id';

String jamendoFixture(String name) =>
    File('test/fixtures/jamendo/$name').readAsStringSync();

/// Transporte HTTP falso: registra las URIs y responde lo que se le configure.
class FakeHttp implements ArtworkHttpClient {
  FakeHttp({this.status = 200, String? body, this.error})
      : body = body ?? jamendoFixture('tracks_search.json');

  int status;
  String body;
  Object? error;
  final List<Uri> requests = [];

  /// Cuerpos que se sirven en orden antes de volver a [body].
  final List<String> queue = [];

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
      Uint8List.fromList(utf8.encode(queue.isEmpty ? body : queue.removeAt(0))),
    );
  }
}

JamendoTrack buildTrack(
  String id, {
  String name = 'Pista',
  String? artist = 'Artista',
  String? album = 'Álbum',
  int duration = 120,
  String? image = 'https://usercontent.jamendo.com?type=album&id=1&width=300&trackid=5',
  String? audio,
}) =>
    JamendoTrack(
      id: id,
      name: name,
      artistName: artist,
      albumName: album,
      durationSeconds: duration,
      albumImage: image,
      audio: audio ?? 'https://audio.example/$id',
      shareUrl: 'https://www.jamendo.com/track/$id',
      licenseUrl: 'http://creativecommons.org/licenses/by-nc-nd/3.0/',
    );

/// `JamendoApi` falso con tracks fijos; cuenta las llamadas.
class FakeJamendoApi implements JamendoApi {
  FakeJamendoApi({this.tracks = const [], this.error});

  List<JamendoTrack> tracks;
  Object? error;
  int searchCalls = 0;
  int listCalls = 0;
  final List<Map<String, Object?>> listArgs = [];
  final List<List<String>> idCalls = [];
  final List<Map<String, Object?>> searchArgs = [];
  bool hasMore = false;

  @override
  Future<JamendoTrackPage> searchTracks({
    String? name,
    String? artistName,
    String? tag,
    required int limit,
    required int offset,
  }) async {
    searchCalls++;
    searchArgs.add({
      'name': name,
      'artistName': artistName,
      'tag': tag,
      'limit': limit,
      'offset': offset,
    });
    if (error != null) throw error!;
    return JamendoTrackPage(tracks, hasMore: hasMore);
  }

  @override
  Future<JamendoTrackPage> listTracks({
    required JamendoTrackOrder order,
    String? tag,
    required int limit,
    required int offset,
  }) async {
    listCalls++;
    listArgs.add({'order': order, 'tag': tag, 'limit': limit, 'offset': offset});
    if (error != null) throw error!;
    return JamendoTrackPage(tracks, hasMore: hasMore);
  }

  @override
  Future<List<JamendoTrack>> tracksByIds(Iterable<String> ids) async {
    idCalls.add(ids.toList());
    if (error != null) throw error!;
    final wanted = ids.toSet();
    return [
      for (final t in tracks)
        if (wanted.contains(t.id)) t,
    ];
  }
}
