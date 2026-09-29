/// Permiso para mostrar la notificación de reproducción (Android 13+).
abstract interface class NotificationPermissionPort {
  /// Pide el permiso si todavía no se pidió. Nunca lanza: si se rechaza, la
  /// reproducción sigue igual, solo sin notificación.
  Future<void> requestIfNeeded();
}
