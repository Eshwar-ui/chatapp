# Push Notification Debugging Guide

## 🔍 Step-by-Step Debugging

### Step 1: Check FCM Token is Saved

**In Flutter app logs, look for:**
```
✅ FCM token saved for user: [user-id]
📱 Token: [token-preview]...
```

**If you don't see this:**
- Token might not be generated
- Check Firebase configuration
- Check notification permissions

**To verify in Firestore:**
1. Go to Firebase Console → Firestore
2. Check `user_tokens` collection
3. Should have documents with user IDs
4. Each document should have a `token` field

---

### Step 2: Check Server is Receiving Requests

**Check Render logs:**
1. Go to Render dashboard
2. Click on your service
3. Go to "Logs" tab
4. Look for incoming POST requests to `/send-notifications`

**What to look for:**
- ✅ `POST /send-notifications` requests
- ✅ `✅ Firebase Admin SDK initialized successfully`
- ❌ Any error messages

---

### Step 3: Check Flutter App is Calling Server

**In Flutter app logs, look for:**
```
📤 Sending notification to recipients...
📊 Found X user tokens
📱 Valid tokens: X
✅ Notifications sent: X success, X failed
```

**If you see errors:**
- `❌ Error sending notifications: [error]` - Check server URL
- `❌ Failed to send notifications: [status code]` - Check server response

---

### Step 4: Common Issues & Fixes

#### Issue 1: No FCM Tokens Saved
**Symptoms:**
- `⚠️ No other users found to send notifications to`
- `user_tokens` collection is empty

**Fix:**
- Make sure `_updateUserToken()` is called when user logs in
- Check Firebase Messaging is initialized
- Check notification permissions are granted

#### Issue 2: Server Not Receiving Requests
**Symptoms:**
- No logs in Render dashboard
- Connection errors in Flutter

**Fix:**
- Verify server URL is correct: `https://notification-server-tnux.onrender.com`
- Check server is running (Render dashboard shows "Live")
- Check CORS is enabled (already done in server.js)

#### Issue 3: Server Error
**Symptoms:**
- Server logs show errors
- `500 Internal Server Error` responses

**Fix:**
- Check `FIREBASE_SERVICE_ACCOUNT` environment variable is set in Render
- Verify service account JSON is valid
- Check Firebase project is correct

#### Issue 4: Notifications Sent But Not Received
**Symptoms:**
- Server logs show success
- Flutter logs show "Notifications sent: X success"
- But no notification appears

**Fix:**
- Check notification permissions on device
- Check device notification settings
- Verify FCM token is valid (not expired)
- Check if app is in foreground (might need different handling)

---

### Step 5: Test Server Manually

**Test the server endpoint directly:**

```bash
curl -X POST https://notification-server-tnux.onrender.com/send-notification \
  -H "Content-Type: application/json" \
  -d '{
    "token": "YOUR_FCM_TOKEN_HERE",
    "title": "Test Notification",
    "body": "This is a test"
  }'
```

**Expected response:**
```json
{
  "success": true,
  "messageId": "projects/.../messages/..."
}
```

**If you get an error:**
- Check the error message
- Verify FCM token is valid
- Check service account is configured correctly

---

### Step 6: Check Firebase Console

1. **Go to Firebase Console → Cloud Messaging**
2. **Send a test notification:**
   - Click "Send test message"
   - Enter your FCM token
   - Send
   - If this works, FCM is configured correctly

3. **Check Firebase project settings:**
   - Verify Cloud Messaging API is enabled
   - Check Android app is registered
   - Verify `google-services.json` is correct

---

## 🐛 Quick Debug Checklist

- [ ] FCM token is saved in Firestore (`user_tokens` collection)
- [ ] Server is running (check Render dashboard)
- [ ] Server URL is correct in Flutter app
- [ ] `FIREBASE_SERVICE_ACCOUNT` is set in Render
- [ ] Notification permissions are granted
- [ ] Firebase Cloud Messaging API is enabled
- [ ] `google-services.json` is in `android/app/`
- [ ] Server logs show incoming requests
- [ ] No errors in Flutter logs
- [ ] Test notification from Firebase Console works

---

## 📱 Testing on Different Devices

### Android Emulator:
- Should work with current setup
- Check notification tray

### Physical Android Device:
- Make sure app has notification permissions
- Check device notification settings
- Verify FCM token is valid

### iOS:
- Requires APNs certificate
- Must test on real device (simulator doesn't support push)
- Check notification permissions

---

## 🔧 Enable More Debugging

Add this to see more details:

```dart
// In notification_service.dart, add more logging:
debugPrint('Request URL: $notificationServerUrl/send-notifications');
debugPrint('Request body: ${jsonEncode({...})}');
```

Check Render logs for:
- Request received
- Firebase Admin SDK status
- FCM send response
- Any errors

