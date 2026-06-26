import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Service to track user online/offline status
class PresenceService extends WidgetsBindingObserver {
  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;
  PresenceService._internal();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isInitialized = false;

  /// Initialize the presence service
  void initialize() {
    if (_isInitialized) return;

    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;
    _setOnline();
  }

  /// Dispose the presence service
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setOffline();
    _isInitialized = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    final user = _auth.currentUser;
    if (user == null) return;

    switch (state) {
      case AppLifecycleState.resumed:
        // App came to foreground - set online
        _setOnline();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App went to background - set offline
        _setOffline();
        break;
    }
  }

  /// Set user as online
  Future<void> _setOnline() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error setting online status: $e');
    }
  }

  /// Set user as offline
  Future<void> _setOffline() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error setting offline status: $e');
    }
  }

  /// Manually set online status (for login)
  Future<void> setOnline() async {
    await _setOnline();
  }

  /// Manually set offline status (for logout)
  Future<void> setOffline() async {
    await _setOffline();
  }
}
