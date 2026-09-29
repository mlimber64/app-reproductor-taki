import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/ports/media_permission_port.dart';

/// Permiso de lectura de música con permission_handler.
///
/// Android 13+ (API 33) usa READ_MEDIA_AUDIO (`Permission.audio`); versiones
/// anteriores, READ_EXTERNAL_STORAGE (`Permission.storage`).
class PermissionHandlerMediaPermission implements MediaPermissionPort {
  PermissionHandlerMediaPermission({Future<int> Function()? androidSdkInt})
      : _androidSdkInt = androidSdkInt ?? _readAndroidSdkInt;

  static const int _android13 = 33;

  final Future<int> Function() _androidSdkInt;
  Permission? _permission;

  static Future<int> _readAndroidSdkInt() async =>
      (await DeviceInfoPlugin().androidInfo).version.sdkInt;

  Future<Permission> _resolvePermission() async => _permission ??=
      await _androidSdkInt() >= _android13
          ? Permission.audio
          : Permission.storage;

  @override
  Future<bool> isGranted() async =>
      (await _resolvePermission()).isGranted;

  @override
  Future<bool> request() async =>
      (await (await _resolvePermission()).request()).isGranted;

  @override
  Future<bool> isPermanentlyDenied() async =>
      (await _resolvePermission()).isPermanentlyDenied;

  @override
  Future<bool> openSettings() => openAppSettings();
}
