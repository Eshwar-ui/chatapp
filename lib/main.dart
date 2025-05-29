import 'package:chatapp/services/applock.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/auth_screen.dart';
import 'screens/chat_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize notifications
    await NotificationService().initialize();
    await initializeNotifications();
    await Permission.storage.request();
  } catch (e) {
    // If Firebase is already initialized, we can safely ignore the error
    if (!e.toString().contains('duplicate-app')) {
      print('Firebase initialization error: $e');
      rethrow;
    }
  }
  await _requestPermissions();
  await SharedPreferences.getInstance();
  runApp(const MyApp());
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initializeNotifications() async {
  const AndroidInitializationSettings androidInitializationSettings =
      AndroidInitializationSettings(
        '@drawable/ic_notification',
      ); // Ensure this file exists

  const InitializationSettings initializationSettings = InitializationSettings(
    android: androidInitializationSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

Future<void> _requestPermissions() async {
  // Request notification permission
  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);

  // Request storage permission
  final storageStatus = await Permission.storage.request();
  if (!storageStatus.isGranted) {
    // Optional: Show alert or handle permission denial
    debugPrint("Storage permission not granted");
  }

  // For Android 13+ media access (optional based on use case)
  await Permission.photos.request();
  await Permission.videos.request();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasData) {
            return AppLockManager(child: const ChatScreen());
          }
          return const AuthScreen();
        },
      ),
    );
  }
}
