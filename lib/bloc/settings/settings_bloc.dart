import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/settings_service.dart';
import 'settings_event.dart';
import 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final SettingsService _settingsService;

  SettingsBloc(this._settingsService) : super(const SettingsState()) {
    on<LoadSettings>(_onLoadSettings);
    on<ChangeThemeMode>(_onChangeThemeMode);
    on<ToggleNotifications>(_onToggleNotifications);
    on<ToggleNotificationSound>(_onToggleNotificationSound);
    on<ToggleNotificationVibration>(_onToggleNotificationVibration);
    on<ToggleReadReceipts>(_onToggleReadReceipts);
    on<ToggleLastSeen>(_onToggleLastSeen);
    on<ToggleProfileVisibility>(_onToggleProfileVisibility);
  }

  Future<void> _onLoadSettings(
    LoadSettings event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    try {
      final themeMode = await _settingsService.getThemeMode();
      final notificationSettings = await _settingsService
          .getNotificationSettings();
      final privacySettings = await _settingsService.getPrivacySettings();

      emit(
        state.copyWith(
          themeMode: themeMode,
          notificationsEnabled: notificationSettings['enabled'] ?? true,
          notificationSound: notificationSettings['sound'] ?? true,
          notificationVibration: notificationSettings['vibration'] ?? true,
          readReceipts: privacySettings['readReceipts'] ?? true,
          lastSeen: privacySettings['lastSeen'] ?? true,
          profileVisibility: privacySettings['profileVisibility'] ?? true,
          isLoading: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onChangeThemeMode(
    ChangeThemeMode event,
    Emitter<SettingsState> emit,
  ) async {
    await _settingsService.setThemeMode(event.themeMode);
    emit(state.copyWith(themeMode: event.themeMode));
  }

  Future<void> _onToggleNotifications(
    ToggleNotifications event,
    Emitter<SettingsState> emit,
  ) async {
    await _settingsService.setNotificationSettings(enabled: event.enabled);
    emit(state.copyWith(notificationsEnabled: event.enabled));
  }

  Future<void> _onToggleNotificationSound(
    ToggleNotificationSound event,
    Emitter<SettingsState> emit,
  ) async {
    await _settingsService.setNotificationSettings(sound: event.enabled);
    emit(state.copyWith(notificationSound: event.enabled));
  }

  Future<void> _onToggleNotificationVibration(
    ToggleNotificationVibration event,
    Emitter<SettingsState> emit,
  ) async {
    await _settingsService.setNotificationSettings(vibration: event.enabled);
    emit(state.copyWith(notificationVibration: event.enabled));
  }

  Future<void> _onToggleReadReceipts(
    ToggleReadReceipts event,
    Emitter<SettingsState> emit,
  ) async {
    await _settingsService.setPrivacySettings(readReceipts: event.enabled);
    emit(state.copyWith(readReceipts: event.enabled));
  }

  Future<void> _onToggleLastSeen(
    ToggleLastSeen event,
    Emitter<SettingsState> emit,
  ) async {
    await _settingsService.setPrivacySettings(lastSeen: event.enabled);
    emit(state.copyWith(lastSeen: event.enabled));
  }

  Future<void> _onToggleProfileVisibility(
    ToggleProfileVisibility event,
    Emitter<SettingsState> emit,
  ) async {
    await _settingsService.setPrivacySettings(profileVisibility: event.enabled);
    emit(state.copyWith(profileVisibility: event.enabled));
  }
}
