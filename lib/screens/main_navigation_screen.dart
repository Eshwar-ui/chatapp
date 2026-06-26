import 'package:flutter/material.dart';
import '../core/design/brutalist_colors.dart';
import '../core/design/brutalist_theme.dart';
import '../core/navigation/app_navigator.dart';
import '../services/settings_service.dart';
import 'chat_list_screen.dart';
import 'users_list_screen.dart';
import 'permission_screen.dart';
import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final _settingsService = SettingsService();

  final List<Widget> _screens = [
    const ChatListScreen(),
    const UsersListScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _maybeShowPermissionOnboarding();
      AppNavigator.flushPendingNavigation();
    });
  }

  Future<void> _maybeShowPermissionOnboarding() async {
    if (await _settingsService.hasSeenPermissionOnboarding()) return;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => PermissionScreen(
          onPermissionsGranted: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
    // Mark as seen regardless of how it was dismissed (Continue, Skip or back),
    // so the gate only ever appears once.
    await _settingsService.setSeenPermissionOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: BrutalistColors.lightBackground,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(BrutalistTheme.radiusLG),
          ),
          border: Border(
            top: BorderSide(
              color: BrutalistColors.lightBorder,
              width: BrutalistTheme.borderWidth,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          backgroundColor: BrutalistColors.lightBackground,
          indicatorColor: Colors.transparent,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          destinations: [
            NavigationDestination(
              icon: Icon(
                Icons.chat_bubble_outline,
                color: BrutalistColors.lightTextSecondary,
              ),
              selectedIcon: Icon(
                Icons.chat_bubble,
                color: BrutalistColors.lightText,
              ),
              label: 'Chats',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.people_outline,
                color: BrutalistColors.lightTextSecondary,
              ),
              selectedIcon: Icon(
                Icons.people,
                color: BrutalistColors.lightText,
              ),
              label: 'Contacts',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.person_outline,
                color: BrutalistColors.lightTextSecondary,
              ),
              selectedIcon: Icon(
                Icons.person,
                color: BrutalistColors.lightText,
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
