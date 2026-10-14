import 'dart:convert';

import '../domain/entities/jamendo_exception.dart';
import '../domain/entities/jamendo_track.dart';
import 'html_entities.dart';

/// Resultado de validar y parsear una respuesta de `/tracks`.
typedef JamendoParsedTracks = ({List<JamendoTrack> tracks, int rawCount});

/// Valida una respuesta de Jamendo y devuelve sus tracks.
///
/// Jamendo contesta HTTP 200 aunque falle: la verdad está en
/// `headers.status`/`headers.code` (5 = client_id, 3 = parámetro, 7 = método).
///
/// No lee `headers.next` (puede traer el `client_id`). Los mensajes de error
/// de la API se limpian de [clientId] antes de salir en una excepción.
JamendoParsedTracks parseJamendoTracks(String body, {String? clientId}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    throw const JamendoMalformedResponseException('el cuerpo no es JSON');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const JamendoMalformedResponseException('se esperaba un objeto');
  }

  final headers = decoded['headers'];
  if (headers is! Map<String, dynamic>) {
    throw const JamendoMalformedResponseException('falta headers');
  }
  final status = headers['status'];
  if (status is! String) {
    throw const JamendoMalformedResponseException('falta headers.status');
  }
  if (status != 'success') {
    throw _errorFor(headers, clientId);
  }

  final results = decoded['results'];
  if (results is! List<dynamic>) {
    throw const JamendoMalformedResponseException('falta results');
  }

  final tracks = <JamendoTrack>[];
  for (final item in results) {
    if (item is! Map<String, dynamic>) continue;
    final track = _parseTrack(item);
    if (track != null) tracks.add(track);
  }
  return (tracks: tracks, rawCount: results.length);
}

JamendoException _errorFor(Map<String, dynamic> headers, String? clientId) {
  final code = headers['code'];
  final intCode = code is int ? code : null;
  final message = _sanitize(headers['error_message'], clientId);
  return switch (intCode) {
    5 => const JamendoInvalidClientException(),
    3 => JamendoInvalidParameterException(message),
    _ => JamendoApiException(intCode, message),
  };
}

final RegExp _url = RegExp(r'https?://\S+', caseSensitive: false);

/// El texto de la API nunca sale con el `client_id` ni con URLs (podrían ser
/// una `next` u otra URL con credenciales).
String _sanitize(Object? raw, String? clientId) {
  var text = raw is String ? raw : 'error de la API';
  if (clientId != null && clientId.isNotEmpty) {
    text = text.replaceAll(clientId, '***');
  }
  return text.replaceAll(_url, '<url>');
}

/// Un track sin `id` o sin `name` no sirve y se omite; el resto de campos
/// opcionales ausentes o de otro tipo quedan en `null`/0.
JamendoTrack? _parseTrack(Map<String, dynamic> json) {
  final id = _idOf(json['id']);
  final rawName = json['name'];
  if (id == null || rawName is! String) return null;
  // Se decodifica antes de validar: un nombre `&nbsp;` es un nombre vacío.
  final name = decodeHtmlEntities(rawName);
  if (name.trim().isEmpty) return null;
  final duration = json['duration'];
  return JamendoTrack(
    id: id,
    name: name,
    artistName: _text(json['artist_name']),
    albumName: _text(json['album_name']),
    durationSeconds: duration is num ? duration.toInt() : 0,
    albumImage: _string(json['album_image']),
    audio: _string(json['audio']),
    shareUrl: _string(json['shareurl']),
    licenseUrl: _string(json['license_ccurl']),
  );
}

/// El id llega como cadena; si algún día llegara numérico, se convierte sin
/// otra normalización.
String? _idOf(Object? raw) {
  final id = switch (raw) {
    String() => raw,
    int() => raw.toString(),
    _ => null,
  };
  return id == null || id.trim().isEmpty ? null : id;
}

String? _string(Object? raw) => raw is String && raw.isNotEmpty ? raw : null;

/// Texto para mostrar (título, artista, álbum): sin entidades HTML. Las URLs,
/// los ids y la licencia usan [_string] y no se tocan.
String? _text(Object? raw) {
  final value = _string(raw);
  return value == null ? null : decodeHtmlEntities(value);
}
