import 'package:flutter/material.dart';
import '../services/permission_service.dart';
import '../core/design/brutalist_colors.dart';

class PermissionScreen extends StatefulWidget {
  final VoidCallback onPermissionsGranted;

  const PermissionScreen({super.key, required this.onPermissionsGranted});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  final _permissionService = PermissionService();
  bool _isLoading = false;
  final Map<String, bool> _permissions = {
    'notifications': false,
    'media': false,
    'camera': false,
  };

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final statuses = await _permissionService.checkAllPermissions();
    if (!mounted) return;
    setState(() {
      _permissions['notifications'] = statuses['notifications'] ?? false;
      _permissions['media'] = statuses['media'] ?? false;
      _permissions['camera'] = statuses['camera'] ?? false;
    });
  }

  Future<void> _requestPermission(String permissionType) async {
    setState(() => _isLoading = true);

    bool granted = false;
    if (permissionType == 'notifications') {
      granted = await _permissionService.requestNotificationPermission();
    } else if (permissionType == 'media') {
      granted = await _permissionService.requestMediaPermission();
    } else if (permissionType == 'camera') {
      granted = await _permissionService.requestCameraPermission();
    }

    if (!mounted) return;
    setState(() {
      _permissions[permissionType] = granted;
      _isLoading = false;
    });

    if (granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$permissionType permission granted!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$permissionType permission denied. You can enable it in settings.',
            ),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Open Settings',
              onPressed: _permissionService.openSettings,
            ),
          ),
        );
      }
    }

    _checkIfAllGranted();
  }

  Future<void> _requestAllPermissions() async {
    setState(() => _isLoading = true);

    final results = await _permissionService.requestAllPermissions();

    if (!mounted) return;
    setState(() {
      _permissions['notifications'] = results['notifications'] ?? false;
      _permissions['media'] = results['media'] ?? false;
      _permissions['camera'] = results['camera'] ?? false;
      _isLoading = false;
    });

    _checkIfAllGranted();
  }

  void _checkIfAllGranted() {
    // Allow user to continue even if not all permissions are granted
    // They can grant them later when needed
  }

  Widget _buildPermissionCard({
    required String title,
    required String description,
    required IconData icon,
    required String permissionType,
    required bool isGranted,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isGranted
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.orange.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isGranted ? Colors.green : Colors.orange,
            size: 28,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: BrutalistColors.lightTextSecondary,
            ),
          ),
        ),
        trailing: isGranted
            ? const Icon(Icons.check_circle, color: Colors.green, size: 28)
            : ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () => _requestPermission(permissionType),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                child: const Text('Allow'),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allGranted = _permissions.values.every((granted) => granted);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Permissions'),
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.security,
                      size: 50,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'We need some permissions',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'To provide the best experience, please grant the following permissions',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildPermissionCard(
              title: 'Notifications',
              description:
                  'Receive push notifications when you get new messages',
              icon: Icons.notifications_active,
              permissionType: 'notifications',
              isGranted: _permissions['notifications'] ?? false,
            ),
            _buildPermissionCard(
              title: 'Media Access',
              description: 'Select photos from your gallery to share in chats',
              icon: Icons.photo_library,
              permissionType: 'media',
              isGranted: _permissions['media'] ?? false,
            ),
            _buildPermissionCard(
              title: 'Camera',
              description: 'Take photos directly in the app to share in chats',
              icon: Icons.camera_alt,
              permissionType: 'camera',
              isGranted: _permissions['camera'] ?? false,
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (!allGranted)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _requestAllPermissions,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle),
                        label: const Text('Allow All Permissions'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  if (allGranted)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: widget.onPermissionsGranted,
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Continue'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: widget.onPermissionsGranted,
                    child: const Text('Skip for now'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
