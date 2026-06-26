import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../core/design/brutalist_colors.dart';
import '../core/design/brutalist_theme.dart';
import '../core/widgets/brutalist_box.dart';
import 'profile_edit_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  UserModel? _currentUser;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      setState(() {
        _currentUser = UserModel.fromFirestore(userDoc.data()!, user.uid);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  ImageProvider? _getProfileImage({String? imageUrl, String? base64Image}) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return NetworkImage(imageUrl);
    }
    if (base64Image == null || base64Image.isEmpty) return null;
    try {
      final bytes = base64Decode(base64Image);
      return MemoryImage(bytes);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final profileImage = _getProfileImage(
      imageUrl: _currentUser?.profilePictureUrl,
      base64Image: _currentUser?.profilePictureBase64,
    );

    return Scaffold(
      backgroundColor: BrutalistColors.lightBackground,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        actions: [
          if (_currentUser != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final updated = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ProfileEditScreen(currentUser: _currentUser!),
                  ),
                );
                if (updated == true) {
                  _loadUserProfile();
                }
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(BrutalistTheme.spacingXL),
        child: Column(
          children: [
            const SizedBox(height: BrutalistTheme.spacingXL),
            Container(
              width: 116,
              height: 116,
              decoration: BoxDecoration(
                color: BrutalistColors.cream,
                shape: BoxShape.circle,
                image: profileImage != null
                    ? DecorationImage(image: profileImage, fit: BoxFit.cover)
                    : null,
              ),
              child: profileImage == null
                  ? Center(
                      child: Text(
                        user?.email?[0].toUpperCase() ?? '?',
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(
                              fontSize: 48,
                              color: BrutalistColors.primaryAccent,
                            ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: BrutalistTheme.spacingLG),
            Text(
              _currentUser?.displayNameOrEmail ?? 'Loading...',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: BrutalistTheme.spacingXS),
            Text(
              user?.email ?? '',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: BrutalistTheme.spacingXL),
            BrutalistBox(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: Text(
                      'Email',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      user?.email ?? 'No email',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Divider(
                    thickness: BrutalistTheme.borderWidth,
                    color: BrutalistColors.lightBorder,
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(
                      'User ID',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      user?.uid ?? 'No ID',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ),
                  Divider(
                    thickness: BrutalistTheme.borderWidth,
                    color: BrutalistColors.lightBorder,
                  ),
                  ListTile(
                    leading: Icon(
                      _currentUser?.isOnline == true
                          ? Icons.circle
                          : Icons.circle_outlined,
                      color: _currentUser?.isOnline == true
                          ? BrutalistColors.successAccent
                          : BrutalistColors.lightTextSecondary,
                    ),
                    title: Text(
                      'Status',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      _currentUser?.isOnline == true ? 'Online' : 'Offline',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _currentUser?.isOnline == true
                            ? BrutalistColors.successAccent
                            : BrutalistColors.lightTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: BrutalistTheme.spacingXL),
            BrutalistBox(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: Text(
                  'Settings',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
