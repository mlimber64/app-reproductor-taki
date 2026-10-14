import '../../../../core/domain/entities/music_identity.dart';
import '../../../../core/domain/entities/provider_attribution.dart';

/// Identificador de fuente de Jamendo en `MusicIdentity.source`.
const String jamendoSource = 'jamendo';

/// Track de Jamendo tal como lo entrega la API (solo campos observados).
///
/// Conserva lo que `Song` no debe llevar: la URL de audio (temporal) y la
/// atribución ([attribution]). Es específico del proveedor y no se persiste.
final class JamendoTrack {
  const JamendoTrack({
    required this.id,
    required this.name,
    this.artistName,
    this.albumName,
    this.durationSeconds = 0,
    this.albumImage,
    this.audio,
    this.shareUrl,
    this.licenseUrl,
  });

  /// `id` de Jamendo, siempre como texto, sin normalizar.
  final String id;
  final String name;
  final String? artistName;
  final String? albumName;
  final int durationSeconds;
  final String? albumImage;

  /// URL de streaming. Puede llevar parámetros temporales; no persistir.
  final String? audio;
  final String? shareUrl;
  final String? licenseUrl;

  /// Atribución que debe mostrar la UI para este track (ver
  /// [ProviderAttribution]). Los datos faltantes o inválidos quedan en `null`;
  /// nunca se deducen (p. ej. no se fabrica un enlace a partir del id).
  ProviderAttribution get attribution => ProviderAttribution(
        identity: MusicIdentity(jamendoSource, id),
        providerName: jamendoProviderName,
        pageUrl: _httpUri(shareUrl),
        licenseUrl: _httpUri(licenseUrl),
        licenseName: _creativeCommonsName(_httpUri(licenseUrl)),
      );
}

/// Nombre de Jamendo para mostrar en la atribución.
const String jamendoProviderName = 'Jamendo';

Uri? _httpUri(String? raw) {
  final value = raw?.trim();
  if (value == null) return null;
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !(uri.scheme == 'http' || uri.scheme == 'https') ||
      uri.host.isEmpty) {
    return null;
  }
  return uri;
}

final RegExp _ccCode = RegExp(r'^by(-(nc|nd|sa))*$');
final RegExp _ccVersion = RegExp(r'^\d+(\.\d+)?$');

/// `https://creativecommons.org/licenses/by-nc-nd/3.0/` da `CC BY-NC-ND 3.0`.
/// Cualquier otra URL no se interpreta (`null`).
String? _creativeCommonsName(Uri? uri) {
  if (uri == null) return null;
  if (uri.host != 'creativecommons.org' &&
      uri.host != 'www.creativecommons.org') {
    return null;
  }
  final parts = [
    for (final segment in uri.pathSegments)
      if (segment.isNotEmpty) segment,
  ];
  if (parts.length != 3 || parts[0] != 'licenses') return null;
  final code = parts[1];
  final version = parts[2];
  if (!_ccCode.hasMatch(code) || !_ccVersion.hasMatch(version)) return null;
  return 'CC ${code.toUpperCase()} $version';
}

/// Página de tracks. [hasMore]: la API devolvió tantos como se pidieron.
final class JamendoTrackPage {
  const JamendoTrackPage(this.tracks, {required this.hasMore});

  final List<JamendoTrack> tracks;
  final bool hasMore;
}
