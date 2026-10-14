/// Errors of the Audius API. They never carry URLs: the signed stream URLs
/// and the query strings stay out of messages and logs.
sealed class AudiusException implements Exception {
  const AudiusException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType($message)';
}

/// Transport failure: network, timeout or a non-2xx status.
final class AudiusNetworkException extends AudiusException {
  const AudiusNetworkException(super.message, {this.statusCode});

  final int? statusCode;
}

/// The response does not have the expected shape.
final class AudiusMalformedResponseException extends AudiusException {
  const AudiusMalformedResponseException(super.message);
}
