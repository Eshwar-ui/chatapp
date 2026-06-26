# Background & Terminated App Notifications

## ✅ Yes, notifications will work when app is not active!

Your app is now configured to receive notifications in **all three states**:

### 📱 App States:

1. **✅ Foreground (App is open)**
   - Handled by: `FirebaseMessaging.onMessage.listen()`
   - Shows local notification via `showNotification()`

2. **✅ Background (App is minimized)**
   - Handled by: `_firebaseMessagingBackgroundHandler()`
   - Automatically shows notification
   - Works even when app is in background

3. **✅ Terminated (App is closed)**
   - Handled by: `_firebaseMessagingBackgroundHandler()`
   - FCM automatically wakes up the app
   - Shows notification to user
   - User can tap to open app

---

## 🔧 How It Works:

### When App is Active (Foreground):
```dart
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  showNotification(...); // Shows local notification
});
```

### When App is Background/Terminated:
```dart
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initializes Firebase & Local Notifications
  // Shows notification automatically
}
```

**Key Points:**
- ✅ Background handler is a **top-level function** (required by FCM)
- ✅ It initializes Firebase and Local Notifications
- ✅ It automatically displays the notification
- ✅ Works even when app is completely closed

---

## 🚀 Server Configuration:

Your Node.js server is already configured correctly:

```javascript
const message = {
  notification: {  // ← This makes it work in background/terminated
    title: title,
    body: body,
  },
  data: data || {},  // ← Optional custom data
  token: token,
  android: { priority: 'high' },
  apns: { headers: { 'apns-priority': '10' } },
};
```

**Important:** The `notification` field is what makes notifications appear when the app is closed!

---

## 📋 Testing Checklist:

### Test 1: Foreground Notifications
1. Open your app
2. Have another user send a message
3. ✅ Notification should appear at top of screen

### Test 2: Background Notifications
1. Minimize your app (press home button)
2. Have another user send a message
3. ✅ Notification should appear in notification tray

### Test 3: Terminated Notifications
1. **Force close** your app (swipe away from recent apps)
2. Have another user send a message
3. ✅ Notification should appear in notification tray
4. Tap notification → App should open

---

## ⚠️ Important Notes:

### Android:
- ✅ Already configured in `AndroidManifest.xml`
- ✅ FCM service is registered
- ✅ Permissions are set

### iOS:
- ⚠️ Requires additional setup:
  - APNs certificate in Firebase Console
  - Push notification capability enabled in Xcode
  - `Info.plist` configuration

### Permissions:
- ✅ App requests notification permission on first launch
- ✅ User must grant permission for notifications to work

---

## 🐛 Troubleshooting:

### Notifications not working in background/terminated?

1. **Check FCM Token:**
   ```dart
   final token = await NotificationService().getToken();
   print('FCM Token: $token');
   ```
   - Make sure token is saved to Firestore
   - Token should be sent to your backend

2. **Check Server:**
   - Verify server is running
   - Check server logs for errors
   - Ensure `notification` field is included in message

3. **Check Permissions:**
   - Android: Settings → Apps → Your App → Notifications (should be ON)
   - iOS: Settings → Notifications → Your App (should be ON)

4. **Check Firebase Console:**
   - Go to Firebase Console → Cloud Messaging
   - Test sending a notification manually
   - Check if it appears on your device

5. **Check Background Handler:**
   - Make sure `@pragma('vm:entry-point')` is present
   - Handler must be top-level function (not inside a class)
   - Handler must be registered before `runApp()`

---

## 📱 Platform-Specific Notes:

### Android:
- ✅ Works automatically with current setup
- ✅ No additional configuration needed
- ✅ Background handler works out of the box

### iOS:
- ⚠️ Requires APNs (Apple Push Notification service)
- ⚠️ Need to configure in Firebase Console
- ⚠️ Need to enable Push Notifications capability in Xcode
- ⚠️ Need to test on a real device (simulator doesn't support push)

---

## ✅ Summary:

**Your notifications WILL work when the app is not active!**

The background handler is properly configured to:
- ✅ Initialize Firebase when app is terminated
- ✅ Initialize Local Notifications
- ✅ Display notifications automatically
- ✅ Work in both background and terminated states

Just make sure:
1. ✅ Server is running and sending notifications
2. ✅ FCM tokens are saved and sent to server
3. ✅ User has granted notification permissions
4. ✅ Server includes `notification` field in message payload

