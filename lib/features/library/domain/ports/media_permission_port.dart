/// Permiso para leer la música del dispositivo.
abstract interface class MediaPermissionPort {
  Future<bool> isGranted();

  /// Muestra el diálogo del sistema. Devuelve `true` si quedó concedido.
  Future<bool> request();

  /// `true` si el sistema ya no mostrará el diálogo (hay que ir a Ajustes).
  Future<bool> isPermanentlyDenied();

  /// Abre los ajustes de la app. Devuelve `false` si no se pudieron abrir.
  Future<bool> openSettings();
}
