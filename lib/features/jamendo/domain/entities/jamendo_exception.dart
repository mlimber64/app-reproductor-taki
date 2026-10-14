/// Errores de la API de Jamendo. Nunca contienen URLs ni el `client_id`.
sealed class JamendoException implements Exception {
  const JamendoException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType($message)';
}

/// `client_id` ausente o rechazado (código 5 de la API).
final class JamendoInvalidClientException extends JamendoException {
  const JamendoInvalidClientException()
      : super('client_id ausente o no autorizado');
}

/// Parámetro inválido (código 3 de la API).
final class JamendoInvalidParameterException extends JamendoException {
  const JamendoInvalidParameterException(super.message);
}

/// Método inexistente (código 7) u otro código de error de la API.
final class JamendoApiException extends JamendoException {
  const JamendoApiException(this.code, super.message);

  final int? code;
}

/// Fallo de transporte: red, tiempo agotado o HTTP no 2xx.
final class JamendoNetworkException extends JamendoException {
  const JamendoNetworkException(super.message, {this.statusCode});

  final int? statusCode;
}

/// La respuesta no tiene la forma esperada.
final class JamendoMalformedResponseException extends JamendoException {
  const JamendoMalformedResponseException(super.message);
}
