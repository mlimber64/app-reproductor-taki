import 'package:permission_handler/permission_handler.dart';

import '../domain/ports/notification_permission_port.dart';

/// POST_NOTIFICATIONS con permission_handler. En Android 12 o anterior no hay
/// diálogo: el permiso figura como concedido y no se pide nada.
class PermissionHandlerNotificationPermission
    implements NotificationPermissionPort {
  bool _asked = false;

  @override
  Future<void> requestIfNeeded() async {
    if (_asked) return;
    _asked = true;
    try {
      final status = await Permission.notification.status;
      if (status.isDenied) await Permission.notification.request();
    } catch (_) {
      // Sin notificación la música sigue sonando: nada que hacer.
    }
  }
}
