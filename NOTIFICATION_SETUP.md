# Notification Server Setup Guide

## 🔴 Current Error:
```
Connection refused (OS Error: Connection refused, errno = 111), 
address = localhost, port = 34770, uri=http://localhost:3000/send-notifications
```

## ✅ Solution:

### Step 1: Start the Notification Server

1. **Open a terminal/command prompt**
2. **Navigate to the notification-server directory:**
   ```bash
   cd notification-server
   ```
3. **Start the server:**
   ```bash
   npm start
   ```
4. **You should see:**
   ```
   ✅ Loaded service account from file
   ✅ Firebase Admin SDK initialized successfully
   Notification server running on port 3000
   ```

### Step 2: Update the Server URL in Flutter App

The URL depends on where you're running the app:

#### Option A: Android Emulator
- Use: `http://10.0.2.2:3000`
- This is already set in the code ✅

#### Option B: iOS Simulator
- Use: `http://localhost:3000`
- Update `lib/services/notification_service.dart`:
  ```dart
  static const String notificationServerUrl = 'http://localhost:3000';
  ```

#### Option C: Physical Device (Android/iOS)
- Use: `http://YOUR_COMPUTER_IP:3000`
- **Find your computer's IP address:**

  **Windows:**
  ```powershell
  ipconfig
  ```
  Look for "IPv4 Address" (e.g., `192.168.1.100`)

  **Mac/Linux:**
  ```bash
  ifconfig
  # or
  ip addr
  ```
  Look for your local network IP (usually starts with `192.168.x.x` or `10.x.x.x`)

- **Update `lib/services/notification_service.dart`:**
  ```dart
  static const String notificationServerUrl = 'http://192.168.1.100:3000'; // Your IP
  ```

### Step 3: Make Sure Your Computer and Device are on the Same Network

- ✅ Both must be on the same Wi-Fi network
- ✅ Firewall might block the connection - allow port 3000

### Step 4: Test the Connection

1. **Make sure server is running** (Step 1)
2. **Update the URL** in Flutter app (Step 2)
3. **Restart your Flutter app**
4. **Send a message** - notification should work!

---

## 🐛 Troubleshooting:

### Error: "Connection refused"

**Possible causes:**
1. ❌ Server is not running
   - **Fix:** Start the server (`npm start` in notification-server folder)

2. ❌ Wrong IP address
   - **Fix:** Check your computer's IP address and update the URL

3. ❌ Firewall blocking connection
   - **Fix:** Allow port 3000 in Windows Firewall
   - Windows: Windows Defender Firewall → Advanced Settings → Inbound Rules → New Rule → Port → 3000

4. ❌ Device and computer on different networks
   - **Fix:** Connect both to the same Wi-Fi network

### Error: "Network is unreachable"

- Check your IP address is correct
- Make sure server is running
- Try pinging the IP from your device

### Server starts but notifications don't work

1. **Check server logs** - are requests coming in?
2. **Check Firebase service account key** - is it valid?
3. **Check FCM tokens** - are they saved in Firestore?
4. **Check notification permissions** - granted in device settings?

---

## 📱 Quick Reference:

### For Android Emulator:
```dart
static const String notificationServerUrl = 'http://10.0.2.2:3000';
```

### For iOS Simulator:
```dart
static const String notificationServerUrl = 'http://localhost:3000';
```

### For Physical Device:
```dart
static const String notificationServerUrl = 'http://192.168.1.XXX:3000'; // Your IP
```

---

## 🚀 Production Setup:

For production, deploy your server to:
- Heroku
- Railway
- Render
- AWS
- Any Node.js hosting

Then update the URL:
```dart
static const String notificationServerUrl = 'https://your-server.com';
```

