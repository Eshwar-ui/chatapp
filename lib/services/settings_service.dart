import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(
    ThemeMode.system,
  );

  // Keys for SharedPreferences
  static const String _themeModeKey = 'theme_mode';
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _notificationSoundKey = 'notification_sound';
  static const String _notificationVibrationKey = 'notification_vibration';
  static const String _permissionOnboardingKey = 'permission_onboarding_done';

  /// Whether the one-time permission onboarding screen has been shown.
  Future<bool> hasSeenPermissionOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_permissionOnboardingKey) ?? false;
  }

  /// Mark the one-time permission onboarding screen as shown.
  Future<void> setSeenPermissionOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_permissionOnboardingKey, true);
  }

  // Get theme mode
  Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeString = prefs.getString(_themeModeKey) ?? 'system';
    ThemeMode mode;
    switch (themeModeString) {
      case 'light':
        mode = ThemeMode.light;
        break;
      case 'dark':
        mode = ThemeMode.dark;
        break;
      default:
        mode = ThemeMode.system;
    }
    themeModeNotifier.value = mode;
    return mode;
  }

  // Set theme mode
  Future<void> setThemeMode(ThemeMode themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    String themeModeString;
    switch (themeMode) {
      case ThemeMode.light:
        themeModeString = 'light';
        break;
      case ThemeMode.dark:
        themeModeString = 'dark';
        break;
      default:
        themeModeString = 'system';
    }
    await prefs.setString(_themeModeKey, themeModeString);
    themeModeNotifier.value = themeMode;
  }

  // Get notification settings from Firestore
  Future<Map<String, bool>> getNotificationSettings() async {
    final user = _auth.currentUser;
    if (user == null) {
      // Return defaults from SharedPreferences if not logged in
      final prefs = await SharedPreferences.getInstance();
      return {
        'enabled': prefs.getBool(_notificationsEnabledKey) ?? true,
        'sound': prefs.getBool(_notificationSoundKey) ?? true,
        'vibration': prefs.getBool(_notificationVibrationKey) ?? true,
      };
    }

    try {
      final doc = await _firestore
          .collection('user_settings')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        return {
          'enabled': data['notificationsEnabled'] ?? true,
          'sound': data['notificationSound'] ?? true,
          'vibration': data['notificationVibration'] ?? true,
        };
      }
    } catch (e) {
      debugPrint('Error getting notification settings: $e');
    }

    // Return defaults
    return {'enabled': true, 'sound': true, 'vibration': true};
  }

  Future<List<String>> getMutedChatRoomIds() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final doc = await _firestore
          .collection('user_settings')
          .doc(user.uid)
          .get();
      return List<String>.from(doc.data()?['mutedChatRoomIds'] ?? []);
    } catch (e) {
      debugPrint('Error getting muted chat rooms: $e');
      return [];
    }
  }

  Future<bool> isChatMuted(String chatRoomId) async {
    final mutedRooms = await getMutedChatRoomIds();
    return mutedRooms.contains(chatRoomId);
  }

  Future<void> setChatMuted(String chatRoomId, bool muted) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('user_settings').doc(user.uid).set({
        'mutedChatRoomIds': muted
            ? FieldValue.arrayUnion([chatRoomId])
            : FieldValue.arrayRemove([chatRoomId]),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error setting chat mute: $e');
    }
  }

  Future<List<String>> getBlockedUserIds() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final doc = await _firestore
          .collection('user_settings')
          .doc(user.uid)
          .get();
      return List<String>.from(doc.data()?['blockedUserIds'] ?? []);
    } catch (e) {
      debugPrint('Error getting blocked users: $e');
      return [];
    }
  }

  Future<bool> isUserBlocked(String userId) async {
    final blockedUsers = await getBlockedUserIds();
    return blockedUsers.contains(userId);
  }

  Future<void> setUserBlocked(String userId, bool blocked) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('user_settings').doc(user.uid).set({
        'blockedUserIds': blocked
            ? FieldValue.arrayUnion([userId])
            : FieldValue.arrayRemove([userId]),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error setting blocked user: $e');
    }
  }

  // Set notification settings
  Future<void> setNotificationSettings({
    bool? enabled,
    bool? sound,
    bool? vibration,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      // Save to SharedPreferences if not logged in
      final prefs = await SharedPreferences.getInstance();
      if (enabled != null) {
        await prefs.setBool(_notificationsEnabledKey, enabled);
      }
      if (sound != null) {
        await prefs.setBool(_notificationSoundKey, sound);
      }
      if (vibration != null) {
        await prefs.setBool(_notificationVibrationKey, vibration);
      }
      return;
    }

    try {
      final updateData = <String, dynamic>{};
      if (enabled != null) {
        updateData['notificationsEnabled'] = enabled;
      }
      if (sound != null) {
        updateData['notificationSound'] = sound;
      }
      if (vibration != null) {
        updateData['notificationVibration'] = vibration;
      }

      await _firestore
          .collection('user_settings')
          .doc(user.uid)
          .set(updateData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error setting notification settings: $e');
    }
  }

  // Get privacy settings from Firestore
  Future<Map<String, bool>> getPrivacySettings() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {
        'readReceipts': true,
        'lastSeen': true,
        'profileVisibility': true,
      };
    }

    try {
      final doc = await _firestore
          .collection('user_settings')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        return {
          'readReceipts': data['readReceipts'] ?? true,
          'lastSeen': data['lastSeen'] ?? true,
          'profileVisibility': data['profileVisibility'] ?? true,
        };
      }
    } catch (e) {
      debugPrint('Error getting privacy settings: $e');
    }

    return {'readReceipts': true, 'lastSeen': true, 'profileVisibility': true};
  }

  // Set privacy settings
  Future<void> setPrivacySettings({
    bool? readReceipts,
    bool? lastSeen,
    bool? profileVisibility,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final updateData = <String, dynamic>{};
      if (readReceipts != null) {
        updateData['readReceipts'] = readReceipts;
      }
      if (lastSeen != null) {
        updateData['lastSeen'] = lastSeen;
      }
      if (profileVisibility != null) {
        updateData['profileVisibility'] = profileVisibility;
      }

      await _firestore
          .collection('user_settings')
          .doc(user.uid)
          .set(updateData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error setting privacy settings: $e');
    }
  }
}
