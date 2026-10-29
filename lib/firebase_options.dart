import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for ${defaultTargetPlatform.name}',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey:
        'AIzaSyCUXoP89WIJHR3KjNDJ_k6ljtfA1eo-QgY', // Replace with your API key
    appId:
        '1:157971224429:android:545f3d7494a8ec48326c64', // Replace with your App ID
    messagingSenderId: '157971224429', // Replace with your Sender ID
    projectId: 'my-chat-app-7b3a3', // Your project ID from the error message
    storageBucket: 'my-chat-app-7b3a3.firebasestorage.app',
  );
}
