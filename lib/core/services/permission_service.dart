import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> requestCameraPermission() async {
    if (kIsWeb) return true; // Web browser handles camera prompts natively
    final status = await Permission.camera.request();
    return status.isGranted || status.isLimited;
  }

  static Future<bool> requestPhotosPermission() async {
    if (kIsWeb) return true; // Web browser handles file picker natively
    if (await Permission.photos.isGranted || await Permission.photos.isLimited) {
      return true;
    }
    final status = await Permission.photos.request();
    if (status.isGranted || status.isLimited) return true;

    // Fallback for older Android versions using storage
    final storageStatus = await Permission.storage.request();
    return storageStatus.isGranted;
  }

  static Future<bool> checkCameraAndPhotosPermissions() async {
    if (kIsWeb) return true;
    final cameraStatus = await Permission.camera.status;
    final photosStatus = await Permission.photos.status;
    return (cameraStatus.isGranted || cameraStatus.isLimited) &&
        (photosStatus.isGranted || photosStatus.isLimited);
  }
}
