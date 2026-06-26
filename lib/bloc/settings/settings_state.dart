import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class SettingsState extends Equatable {
  final ThemeMode themeMode;
  final bool notificationsEnabled;
  final bool notificationSound;
  final bool notificationVibration;
  final bool readReceipts;
  final bool lastSeen;
  final bool profileVisibility;
  final bool isLoading;

  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.notificationsEnabled = true,
    this.notificationSound = true,
    this.notificationVibration = true,
    this.readReceipts = true,
    this.lastSeen = true,
    this.profileVisibility = true,
    this.isLoading = false,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    bool? notificationsEnabled,
    bool? notificationSound,
    bool? notificationVibration,
    bool? readReceipts,
    bool? lastSeen,
    bool? profileVisibility,
    bool? isLoading,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notificationSound: notificationSound ?? this.notificationSound,
      notificationVibration:
          notificationVibration ?? this.notificationVibration,
      readReceipts: readReceipts ?? this.readReceipts,
      lastSeen: lastSeen ?? this.lastSeen,
      profileVisibility: profileVisibility ?? this.profileVisibility,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [
    themeMode,
    notificationsEnabled,
    notificationSound,
    notificationVibration,
    readReceipts,
    lastSeen,
    profileVisibility,
    isLoading,
  ];
}
