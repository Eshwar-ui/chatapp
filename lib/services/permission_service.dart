import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  bool _isUsableStatus(
    PermissionStatus status, {
    bool allowLimited = false,
    bool allowProvisional = false,
  }) {
    return status.isGranted ||
        (allowLimited && status.isLimited) ||
        (allowProvisional && status.isProvisional);
  }

  Future<bool> _requestIfNeeded(
    Permission permission, {
    bool allowLimited = false,
    bool allowProvisional = false,
  }) async {
    final currentStatus = await permission.status;
    if (_isUsableStatus(
      currentStatus,
      allowLimited: allowLimited,
      allowProvisional: allowProvisional,
    )) {
      return true;
    }
    if (currentStatus.isPermanentlyDenied || currentStatus.isRestricted) {
      return false;
    }

    final requestedStatus = await permission.request();
    return _isUsableStatus(
      requestedStatus,
      allowLimited: allowLimited,
      allowProvisional: allowProvisional,
    );
  }

  /// Request notification permission
  Future<bool> requestNotificationPermission() async {
    return _requestIfNeeded(Permission.notification, allowProvisional: true);
  }

  /// Request media/gallery permission
  Future<bool> requestMediaPermission() async {
    // Android 13+ uses READ_MEDIA_IMAGES through Permission.photos.
    // Android 12 and below still use READ_EXTERNAL_STORAGE.
    try {
      final photosGranted = await _requestIfNeeded(
        Permission.photos,
        allowLimited: true,
      );
      if (photosGranted) {
        return true;
      }
    } catch (e) {
      // Photos permission is unavailable on some Android versions/platforms.
    }

    return _requestIfNeeded(Permission.storage);
  }

  /// Request camera permission
  Future<bool> requestCameraPermission() async {
    return _requestIfNeeded(Permission.camera);
  }

  /// Check if all required permissions are granted
  Future<Map<String, bool>> checkAllPermissions() async {
    bool mediaGranted = false;
    try {
      final photosStatus = await Permission.photos.status;
      mediaGranted = _isUsableStatus(photosStatus, allowLimited: true);
    } catch (e) {
      mediaGranted = false;
    }

    if (!mediaGranted) {
      final storageStatus = await Permission.storage.status;
      mediaGranted = _isUsableStatus(storageStatus);
    }

    final notificationStatus = await Permission.notification.status;
    final cameraStatus = await Permission.camera.status;

    return {
      'notifications': _isUsableStatus(
        notificationStatus,
        allowProvisional: true,
      ),
      'media': mediaGranted,
      'camera': _isUsableStatus(cameraStatus),
    };
  }

  /// Request all permissions at once
  Future<Map<String, bool>> requestAllPermissions() async {
    final results = <String, bool>{};

    results['notifications'] = await requestNotificationPermission();
    results['media'] = await requestMediaPermission();
    results['camera'] = await requestCameraPermission();

    return results;
  }

  /// Show permission explanation dialog
  Future<bool> showPermissionDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String permissionType,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Now'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
