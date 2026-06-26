import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import '../services/permission_service.dart';
import '../utils/image_compressor.dart';
import '../core/design/brutalist_colors.dart';
import '../core/design/brutalist_theme.dart';

class ProfileEditScreen extends StatefulWidget {
  final UserModel currentUser;

  const ProfileEditScreen({super.key, required this.currentUser});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;
  final _permissionService = PermissionService();
  final _nameController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  String? _profilePictureUrl;
  String? _profilePictureBase64;
  bool _isLoading = false;
  File? _pickedImage;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.currentUser.displayName ?? '';
    _profilePictureUrl = widget.currentUser.profilePictureUrl;
    _profilePictureBase64 = widget.currentUser.profilePictureBase64;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickProfilePicture() async {
    try {
      // Check permission first
      bool hasPermission = await _permissionService.requestMediaPermission();

      if (!hasPermission && mounted) {
        // Show explanation dialog
        final shouldRequest = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Media Permission'),
            content: const Text(
              'We need media permission to let you select a profile picture from your gallery.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Allow'),
              ),
            ],
          ),
        );

        if (shouldRequest == true) {
          hasPermission = await _permissionService.requestMediaPermission();
        }
      }

      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Permission is required to select images.'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: _permissionService.openSettings,
              ),
            ),
          );
        }
        return;
      }

      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 60, // Lower quality for better compression
      );

      if (pickedFile != null) {
        setState(() {
          _pickedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      String? profilePictureUrl;

      if (_pickedImage != null) {
        final compressedBytes = await ImageCompressor.compressImage(
          _pickedImage!,
          maxWidth: 400, // Smaller for profile pictures
          maxHeight: 400,
          quality: 75,
        );

        if (compressedBytes != null) {
          final imageRef = _storage.ref('users/${user.uid}/profile.png');
          await imageRef.putData(
            compressedBytes,
            SettableMetadata(contentType: 'image/png'),
          );
          profilePictureUrl = await imageRef.getDownloadURL();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to compress image. Please try again.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      // Update user profile
      final updateData = <String, dynamic>{
        'displayName': _nameController.text.trim(),
      };

      if (profilePictureUrl != null) {
        updateData['profilePictureUrl'] = profilePictureUrl;
        updateData['profilePictureBase64'] = FieldValue.delete();
      }

      await _firestore.collection('users').doc(user.uid).update(updateData);

      setState(() {
        _profilePictureUrl = profilePictureUrl ?? _profilePictureUrl;
        if (profilePictureUrl != null) {
          _profilePictureBase64 = null;
        }
        _pickedImage = null;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(
          context,
          true,
        ); // Return true to indicate profile was updated
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  ImageProvider? _getProfileImage() {
    if (_pickedImage != null) {
      return FileImage(_pickedImage!);
    }
    if (_profilePictureUrl != null && _profilePictureUrl!.isNotEmpty) {
      return NetworkImage(_profilePictureUrl!);
    }
    if (_profilePictureBase64 != null && _profilePictureBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(_profilePictureBase64!);
        return MemoryImage(bytes);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final profileImage = _getProfileImage();

    return Scaffold(
      backgroundColor: BrutalistColors.lightBackground,
      appBar: AppBar(
        title: Text(
          'EDIT PROFILE',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: Text(
              'Save',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: BrutalistColors.lightText,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: profileImage,
                        backgroundColor: BrutalistColors.lightSurface,
                        child: profileImage == null
                            ? Text(
                                user?.email?[0].toUpperCase() ?? '?',
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: BrutalistColors.lightText,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: BrutalistColors.lightText,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: BrutalistColors.pureWhite,
                              width: 2,
                            ),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.camera_alt_outlined,
                              size: 20,
                              color: BrutalistColors.pureWhite,
                            ),
                            onPressed: _pickProfilePicture,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _nameController,
                    style: TextStyle(color: BrutalistColors.lightText),
                    decoration: InputDecoration(
                      labelText: 'Display Name',
                      labelStyle: TextStyle(
                        color: BrutalistColors.lightTextSecondary,
                      ),
                      prefixIcon: Icon(
                        Icons.person_outline,
                        color: BrutalistColors.lightTextSecondary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          BrutalistTheme.radiusMD,
                        ),
                        borderSide: BorderSide(
                          color: BrutalistColors.lightBorder,
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          BrutalistTheme.radiusMD,
                        ),
                        borderSide: BorderSide(
                          color: BrutalistColors.lightBorder,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          BrutalistTheme.radiusMD,
                        ),
                        borderSide: BorderSide(
                          color: BrutalistColors.lightText,
                          width: 2,
                        ),
                      ),
                      filled: false,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
