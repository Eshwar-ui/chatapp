# Push Notification Options (Without Firebase Functions)

## ✅ Option 1: Node.js/Express Backend (RECOMMENDED)

**Status:** ✅ Implemented

This is the most secure and flexible option. A simple Node.js server handles sending notifications using Firebase Admin SDK.

### Setup:
1. Go to `notification-server/` directory
2. Follow the README.md instructions
3. Update `notificationServerUrl` in `lib/services/notification_service.dart`

### Pros:
- ✅ Secure (server key stays on server)
- ✅ Full control
- ✅ Easy to customize
- ✅ Can add rate limiting, logging, etc.

### Cons:
- Requires hosting a server (Heroku, Railway, Render, etc.)

---

## Option 2: Direct HTTP to FCM API (NOT RECOMMENDED)

**⚠️ Security Warning:** This requires exposing your FCM server key in the client, which is a **major security risk**.

### Implementation:
```dart
// Add to pubspec.yaml: http: ^1.2.0

Future<void> sendNotificationDirect({
  required String token,
  required String title,
  required String body,
}) async {
  const String serverKey = 'YOUR_FCM_SERVER_KEY'; // ⚠️ NEVER DO THIS!
  
  final response = await http.post(
    Uri.parse('https://fcm.googleapis.com/fcm/send'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'key=$serverKey',
    },
    body: jsonEncode({
      'to': token,
      'notification': {
        'title': title,
        'body': body,
      },
    }),
  );
}
```

### Why NOT recommended:
- ❌ Server key exposed in app code
- ❌ Anyone can extract it and spam notifications
- ❌ No rate limiting
- ❌ Violates Firebase security best practices

---

## Option 3: Third-Party Services

### A. OneSignal (Free tier available)

1. **Sign up:** https://onesignal.com
2. **Add package:**
   ```yaml
   dependencies:
     onesignal_flutter: ^5.0.0
   ```
3. **Initialize:**
   ```dart
   await OneSignal.shared.setAppId("YOUR_ONESIGNAL_APP_ID");
   await OneSignal.shared.setNotificationOpenedHandler((result) {
     // Handle notification opened
   });
   ```
4. **Send notifications via OneSignal REST API** from your backend or use their dashboard

### B. Pusher Beams

1. **Sign up:** https://pusher.com/beams
2. **Add package:**
   ```yaml
   dependencies:
     pusher_beams: ^1.0.0
   ```
3. Similar setup to OneSignal

### Pros:
- ✅ Managed service
- ✅ Good free tiers
- ✅ Analytics included
- ✅ Easy setup

### Cons:
- ❌ Additional dependency
- ❌ Vendor lock-in
- ❌ May have costs at scale

---

## Option 4: Python/Flask Backend

Similar to Node.js but using Python:

```python
from flask import Flask, request, jsonify
from firebase_admin import credentials, initialize_app, messaging

app = Flask(__name__)
cred = credentials.Certificate("serviceAccountKey.json")
initialize_app(cred)

@app.route('/send-notification', methods=['POST'])
def send_notification():
    data = request.json
    message = messaging.Message(
        notification=messaging.Notification(
            title=data['title'],
            body=data['body']
        ),
        token=data['token']
    )
    response = messaging.send(message)
    return jsonify({'success': True, 'messageId': response})

if __name__ == '__main__':
    app.run(port=3000)
```

---

## Option 5: Cloud Run / AWS Lambda / Serverless

Deploy the Node.js server as a serverless function:

### Google Cloud Run:
```bash
gcloud run deploy notification-server \
  --source . \
  --platform managed \
  --allow-unauthenticated
```

### AWS Lambda:
- Use Serverless Framework
- Package Node.js code
- Deploy to Lambda

### Pros:
- ✅ Pay per use
- ✅ Auto-scaling
- ✅ No server management

---

## Comparison Table

| Option | Security | Cost | Complexity | Recommended |
|--------|----------|------|------------|-------------|
| Node.js Backend | ✅ High | Free-$ | Medium | ✅ Yes |
| Direct FCM API | ❌ Low | Free | Low | ❌ No |
| OneSignal | ✅ High | Free-$ | Low | ✅ Yes |
| Python Backend | ✅ High | Free-$ | Medium | ✅ Yes |
| Serverless | ✅ High | Pay-per-use | High | ✅ Yes |

---

## Current Implementation

The app now uses **Option 1 (Node.js Backend)**. To use it:

1. Set up the server (see `notification-server/README.md`)
2. Update `notificationServerUrl` in `lib/services/notification_service.dart`
3. Deploy the server to a hosting service
4. Update the URL in your Flutter app

The Flutter app will now call your backend API instead of writing to Firestore.

