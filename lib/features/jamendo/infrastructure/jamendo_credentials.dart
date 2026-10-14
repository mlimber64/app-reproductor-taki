/// Origen del `client_id` de Jamendo. Configuración de infraestructura: no
/// entra en el dominio, en `Song`, en SQLite ni en el repositorio.
abstract interface class JamendoCredentials {
  /// El `client_id` **ya validado**, o `null` si no hay uno utilizable
  /// (ausente, vacío o con formato inválido).
  String? get clientId;
}

/// Un `client_id` utilizable: 4–64 caracteres `[A-Za-z0-9_-]`, sin espacios.
///
/// Es deliberadamente laxo (el real observado tiene 8 hexadecimales, pero
/// Jamendo no documenta el formato): solo descarta lo que es evidentemente un
/// error de configuración (espacios, `=`, `&`, `?`, `/`, comillas, vacío…) y
/// lo que rompería la query. Se recortan los espacios de los extremos.
final RegExp _clientIdFormat = RegExp(r'^[A-Za-z0-9_-]{4,64}$');

/// Devuelve [raw] recortado si es un `client_id` válido; si no, `null`.
String? normalizeJamendoClientId(String? raw) {
  final trimmed = raw?.trim();
  if (trimmed == null || !_clientIdFormat.hasMatch(trimmed)) return null;
  return trimmed;
}

/// Lee el `client_id` de `--dart-define=JAMENDO_CLIENT_ID=<CLIENT_ID>` (en
/// compilación; igual en debug y en release).
///
/// El nombre exacto de la variable es [variableName]. Si falta, está vacío o
/// tiene formato inválido, [clientId] es `null` y Jamendo no se registra.
///
/// Ojo: un valor pasado por `--dart-define` queda dentro del binario de esa
/// compilación. Jamendo lo trata como identificador de aplicación, no como
/// secreto de servidor.
class EnvironmentJamendoCredentials implements JamendoCredentials {
  const EnvironmentJamendoCredentials();

  static const String variableName = 'JAMENDO_CLIENT_ID';

  @override
  String? get clientId {
    const value = String.fromEnvironment(variableName);
    return normalizeJamendoClientId(value);
  }

  @override
  String toString() => 'EnvironmentJamendoCredentials()';
}

/// Credencial fija (tests, o un origen distinto en el futuro). Se valida igual
/// que la del entorno y nunca revela el valor en `toString`.
class StaticJamendoCredentials implements JamendoCredentials {
  const StaticJamendoCredentials(this._raw);

  final String? _raw;

  @override
  String? get clientId => normalizeJamendoClientId(_raw);

  @override
  String toString() => 'StaticJamendoCredentials()';
}
