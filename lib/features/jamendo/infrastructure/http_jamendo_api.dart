import 'dart:convert';

import '../../../core/domain/ports/artwork_http_client.dart';
import '../domain/entities/jamendo_exception.dart';
import '../domain/entities/jamendo_track.dart';
import '../domain/ports/jamendo_api.dart';
import 'jamendo_credentials.dart';
import 'jamendo_response_parser.dart';

/// [JamendoApi] sobre HTTP.
///
/// Reutiliza el [ArtworkHttpClient] existente como transporte GET genérico
/// (bytes + status + timeout + tope de tamaño) para no duplicar clientes HTTP;
/// su nombre es histórico.
///
/// Seguridad: el `client_id` solo viaja en la query de la petición. Ninguna
/// excepción incluye la URI ni la causa original (el mensaje de un
/// `HttpException` suele contener la URI).
class HttpJamendoApi implements JamendoApi {
  HttpJamendoApi(
    this._http,
    this._credentials, {
    this.timeout = const Duration(seconds: 10),
    this.maxBytes = 4 * 1024 * 1024,
    this.host = 'api.jamendo.com',
    this.emptyRetries = 3,
    this.retryDelay = const Duration(milliseconds: 300),
  });

  /// Máximo de valores que Jamendo admite en un parámetro múltiple (`id`).
  static const int maxIdsPerRequest = 50;

  final ArtworkHttpClient _http;
  final JamendoCredentials _credentials;
  final Duration timeout;
  final int maxBytes;
  final String host;

  /// Jamendo a veces contesta `success` con 0 resultados para consultas que
  /// sí tienen resultados (intermitente, observado en 3.1B; también con
  /// `search=` y con `id=` de pistas existentes). Una respuesta vacía se
  /// reintenta hasta [emptyRetries] veces antes de darla por buena.
  final int emptyRetries;
  final Duration retryDelay;

  @override
  Future<JamendoTrackPage> searchTracks({
    String? name,
    String? artistName,
    String? tag,
    required int limit,
    required int offset,
  }) async {
    final parsed = await _tracks({
      'limit': '$limit',
      'offset': '$offset',
      // `search=` devuelve 0 resultados (spike); `namesearch=` funciona.
      if (_has(name)) 'namesearch': name!,
      if (_has(artistName)) 'artist_name': artistName!,
      if (_has(tag)) 'tags': tag!,
    });
    return JamendoTrackPage(parsed.tracks, hasMore: parsed.rawCount >= limit);
  }

  @override
  Future<List<JamendoTrack>> tracksByIds(Iterable<String> ids) async {
    final unique = ids.toSet().toList();
    if (unique.isEmpty) return const [];
    final chunks = <List<String>>[
      for (var i = 0; i < unique.length; i += maxIdsPerRequest)
        unique.sublist(
          i,
          i + maxIdsPerRequest > unique.length
              ? unique.length
              : i + maxIdsPerRequest,
        ),
    ];
    final pages = await Future.wait([
      for (final chunk in chunks)
        _tracks({
          'limit': '${chunk.length}',
          // Varios ids van separados por espacio (se codifica como `+`).
          'id': chunk.join(' '),
        }),
    ]);
    return [for (final page in pages) ...page.tracks];
  }

  Future<JamendoParsedTracks> _tracks(Map<String, String> params) async {
    var parsed = await _tracksOnce(params);
    for (var retry = 0; retry < emptyRetries && parsed.rawCount == 0; retry++) {
      if (retryDelay > Duration.zero) await Future<void>.delayed(retryDelay);
      parsed = await _tracksOnce(params);
    }
    return parsed;
  }

  Future<JamendoParsedTracks> _tracksOnce(Map<String, String> params) async {
    final clientId = _credentials.clientId;
    if (clientId == null || clientId.trim().isEmpty) {
      throw const JamendoInvalidClientException();
    }
    final uri = Uri.https(host, '/v3.0/tracks/', {
      'client_id': clientId,
      'format': 'json',
      'audioformat': 'mp32',
      ...params,
    });

    final ArtworkHttpResponse response;
    try {
      response = await _http.get(uri, timeout: timeout, maxBytes: maxBytes);
    } catch (error) {
      throw JamendoNetworkException('fallo de red (${error.runtimeType})');
    }
    if (response.statusCode < 200 || response.statusCode > 299) {
      throw JamendoNetworkException(
        'HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final String body;
    try {
      body = utf8.decode(response.bodyBytes);
    } on FormatException {
      throw const JamendoMalformedResponseException('UTF-8 inválido');
    }
    return parseJamendoTracks(body, clientId: clientId);
  }

  static bool _has(String? value) => value != null && value.trim().isNotEmpty;
}
