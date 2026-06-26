import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

class LoadSettings extends SettingsEvent {
  const LoadSettings();
}

class ChangeThemeMode extends SettingsEvent {
  final ThemeMode themeMode;

  const ChangeThemeMode(this.themeMode);

  @override
  List<Object?> get props => [themeMode];
}

class ToggleNotifications extends SettingsEvent {
  final bool enabled;

  const ToggleNotifications(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

class ToggleNotificationSound extends SettingsEvent {
  final bool enabled;

  const ToggleNotificationSound(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

class ToggleNotificationVibration extends SettingsEvent {
  final bool enabled;

  const ToggleNotificationVibration(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

class ToggleReadReceipts extends SettingsEvent {
  final bool enabled;

  const ToggleReadReceipts(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

class ToggleLastSeen extends SettingsEvent {
  final bool enabled;

  const ToggleLastSeen(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

class ToggleProfileVisibility extends SettingsEvent {
  final bool enabled;

  const ToggleProfileVisibility(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

