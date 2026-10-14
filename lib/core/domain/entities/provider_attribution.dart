import 'music_identity.dart';

/// Atribución que un proveedor exige mostrar para una canción.
///
/// Es **metadata del proveedor**, no de `Song`: se obtiene del track del
/// proveedor cuando una pantalla la necesita, y no se persiste.
///
/// Contrato:
/// - [identity] y [providerName] **siempre** están: identifican a qué
///   contenido y de qué proveedor es la atribución.
/// - [pageUrl] y [licenseUrl] pueden faltar (`null`) si el proveedor no los
///   entregó o no son URLs http(s) válidas. Nunca se inventan ni se deducen.
/// - [licenseName] es una etiqueta legible derivada **solo** de [licenseUrl]
///   cuando es reconocible (p. ej. `CC BY-NC-ND 3.0`); si no, `null`.
/// - La licencia es **por canción**: dos canciones del mismo proveedor pueden
///   tener licencias distintas.
///
/// La UI debe tratar la atribución como posiblemente incompleta
/// ([hasPageUrl], [hasLicense]) y degradar con gracia (mostrar el proveedor
/// sin enlace, o «licencia no disponible»).
final class ProviderAttribution {
  const ProviderAttribution({
    required this.identity,
    required this.providerName,
    this.pageUrl,
    this.licenseUrl,
    this.licenseName,
  });

  final MusicIdentity identity;
  final String providerName;

  /// Enlace directo al contenido en el proveedor.
  final Uri? pageUrl;

  /// Licencia del contenido.
  final Uri? licenseUrl;
  final String? licenseName;

  bool get hasPageUrl => pageUrl != null;
  bool get hasLicense => licenseUrl != null;

  /// Tiene todo lo que un proveedor con enlace y licencia por pista exige.
  bool get isComplete => hasPageUrl && hasLicense;

  @override
  bool operator ==(Object other) =>
      other is ProviderAttribution &&
      other.identity == identity &&
      other.providerName == providerName &&
      other.pageUrl == pageUrl &&
      other.licenseUrl == licenseUrl &&
      other.licenseName == licenseName;

  @override
  int get hashCode => Object.hash(
        identity,
        providerName,
        pageUrl,
        licenseUrl,
        licenseName,
      );

  @override
  String toString() => 'ProviderAttribution($identity, $providerName, '
      'page: $pageUrl, license: $licenseName)';
}
