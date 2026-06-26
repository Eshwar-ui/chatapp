import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'screens/auth_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'services/notification_service.dart';
import 'services/presence_service.dart';
import 'services/settings_service.dart';
import 'bloc/settings/settings_bloc.dart';
import 'bloc/settings/settings_event.dart';
import 'bloc/settings/settings_state.dart';
import 'core/design/brutalist_theme.dart';
import 'core/navigation/app_navigator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize notifications
    await NotificationService().initialize();
  } catch (e) {
    // If Firebase is already initialized, we can safely ignore the error
    if (!e.toString().contains('duplicate-app')) {
      debugPrint('Firebase initialization error: $e');
      rethrow;
    }
  }
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _presenceService = PresenceService();
  final _settingsService = SettingsService();
  final _notificationService = NotificationService();
  late final SettingsBloc _settingsBloc;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _presenceService.initialize();
    _settingsBloc = SettingsBloc(_settingsService);
    _settingsBloc.add(const LoadSettings());
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _notificationService.saveTokenForCurrentUser();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          AppNavigator.flushPendingNavigation();
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _settingsBloc.close();
    _presenceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SettingsBloc>.value(
      value: _settingsBloc,
      child: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          return MaterialApp(
            title: 'Chat App',
            debugShowCheckedModeBanner: false,
            navigatorKey: AppNavigator.navigatorKey,
            theme: BrutalistTheme.theme,
            home: StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasData) {
                  return const MainNavigationScreen();
                }
                return const AuthScreen();
              },
            ),
          );
        },
      ),
    );
  }
}
