import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/settings/settings_bloc.dart';
import '../bloc/settings/settings_event.dart';
import '../bloc/settings/settings_state.dart';
import '../services/notification_service.dart';
import '../services/presence_service.dart';
import '../core/design/brutalist_colors.dart';
import '../core/design/brutalist_theme.dart';
import '../core/widgets/brutalist_box.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        if (state.isLoading) {
          return Scaffold(
            backgroundColor: BrutalistColors.lightBackground,
            appBar: AppBar(
              title: Text(
                'SETTINGS',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          backgroundColor: BrutalistColors.lightBackground,
          appBar: AppBar(
            title: Text(
              'Settings',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(BrutalistTheme.spacingMD),
            children: [
              // Notifications Section
              _buildSectionHeader('Notifications'),
              const SizedBox(height: BrutalistTheme.spacingSM),
              BrutalistBox(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildSwitchTile(
                      context: context,
                      title: 'Enable notifications',
                      subtitle: 'Receive push notifications',
                      value: state.notificationsEnabled,
                      onChanged: (value) => context.read<SettingsBloc>().add(
                        ToggleNotifications(value),
                      ),
                    ),
                    _buildDivider(),
                    _buildSwitchTile(
                      context: context,
                      title: 'Sound',
                      subtitle: 'Play sound for notifications',
                      value: state.notificationSound,
                      onChanged: state.notificationsEnabled
                          ? (value) => context.read<SettingsBloc>().add(
                              ToggleNotificationSound(value),
                            )
                          : null,
                    ),
                    _buildDivider(),
                    _buildSwitchTile(
                      context: context,
                      title: 'Vibration',
                      subtitle: 'Vibrate for notifications',
                      value: state.notificationVibration,
                      onChanged: state.notificationsEnabled
                          ? (value) => context.read<SettingsBloc>().add(
                              ToggleNotificationVibration(value),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: BrutalistTheme.spacingLG),

              // Privacy Section
              _buildSectionHeader('Privacy'),
              const SizedBox(height: BrutalistTheme.spacingSM),
              BrutalistBox(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildSwitchTile(
                      context: context,
                      title: 'Read receipts',
                      subtitle: 'Let others know when you read their messages',
                      value: state.readReceipts,
                      onChanged: (value) => context.read<SettingsBloc>().add(
                        ToggleReadReceipts(value),
                      ),
                    ),
                    _buildDivider(),
                    _buildSwitchTile(
                      context: context,
                      title: 'Last seen',
                      subtitle: 'Show when you were last active',
                      value: state.lastSeen,
                      onChanged: (value) => context.read<SettingsBloc>().add(
                        ToggleLastSeen(value),
                      ),
                    ),
                    _buildDivider(),
                    _buildSwitchTile(
                      context: context,
                      title: 'Profile visibility',
                      subtitle: 'Allow others to find you by email',
                      value: state.profileVisibility,
                      onChanged: (value) => context.read<SettingsBloc>().add(
                        ToggleProfileVisibility(value),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: BrutalistTheme.spacingLG),

              // Account Section
              _buildSectionHeader('Account'),
              const SizedBox(height: BrutalistTheme.spacingSM),
              BrutalistBox(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: Icon(
                    Icons.logout_outlined,
                    color: BrutalistColors.dangerAccent,
                  ),
                  title: Text(
                    'Log out',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: BrutalistColors.dangerAccent,
                    ),
                  ),
                  onTap: () => _showLogoutDialog(context),
                ),
              ),
              const SizedBox(height: BrutalistTheme.spacingLG),

              // About Section
              _buildSectionHeader('About'),
              const SizedBox(height: BrutalistTheme.spacingSM),
              BrutalistBox(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: Icon(
                    Icons.info_outline,
                    color: BrutalistColors.lightTextSecondary,
                  ),
                  title: Text(
                    'App version',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    '1.0.0',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              const SizedBox(height: BrutalistTheme.spacingXXL),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Builder(
      builder: (context) => Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: BrutalistColors.lightTextSecondary,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return ListTile(
      title: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: BrutalistTheme.borderWidth,
      color: BrutalistColors.lightBorder,
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BrutalistColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BrutalistTheme.radiusMD),
          side: BorderSide(
            color: BrutalistColors.lightBorder,
            width: BrutalistTheme.borderWidth,
          ),
        ),
        title: Text(
          'Log out',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              navigator.pop();
              await NotificationService().deleteTokenForCurrentUser();
              await PresenceService().setOffline();
              await FirebaseAuth.instance.signOut();
              // The auth-state listener in `home` (main.dart) swaps the root
              // back to AuthScreen automatically; just pop pushed routes
              // (Settings/Profile) so that root becomes visible again.
              navigator.popUntil((route) => route.isFirst);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: BrutalistColors.dangerAccent,
              foregroundColor: BrutalistColors.pureWhite,
            ),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}
