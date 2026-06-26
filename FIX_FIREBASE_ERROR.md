# Fix Firebase DEVELOPER_ERROR

## 🔴 Error:
```
SecurityException: Unknown calling package name 'com.google.android.gms'
ConnectionResult{statusCode=DEVELOPER_ERROR}
```

## ✅ Solution: Add SHA-1 Fingerprint to Firebase

This error occurs because Firebase doesn't recognize your app's debug keystore signature.

### Step 1: Get Your SHA-1 Fingerprint

**Windows (PowerShell):**
```powershell
cd android
.\gradlew signingReport
```

**Or use keytool directly:**
```powershell
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

**Mac/Linux:**
```bash
cd android
./gradlew signingReport
```

**Or:**
```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

### Step 2: Copy the SHA-1 Fingerprint

Look for output like:
```
Certificate fingerprints:
     SHA1: A1:B2:C3:D4:E5:F6:...
```

Copy the SHA-1 value (the part after `SHA1:`)

### Step 3: Add to Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project: **my-chat-app-7b3a3**
3. Click the **⚙️ gear icon** → **Project Settings**
4. Scroll down to **Your apps** section
5. Find your Android app (package: `com.example.chatapp`)
6. Click **Add fingerprint**
7. Paste your SHA-1 fingerprint
8. Click **Save**

### Step 4: Download New google-services.json

1. Still in Firebase Console → Project Settings
2. Scroll to **Your apps**
3. Click the **Android app** (`com.example.chatapp`)
4. Click **Download google-services.json**
5. Replace the file in `android/app/google-services.json`

### Step 5: Rebuild the App

```bash
flutter clean
flutter pub get
flutter run
```

---

## 🔍 Alternative: Check if App is Registered

1. Go to Firebase Console
2. Project Settings → Your apps
3. Verify you see an Android app with package name: `com.example.chatapp`
4. If not, click **Add app** → **Android** → Register it

---

## 📋 Quick Checklist

- [ ] SHA-1 fingerprint obtained
- [ ] SHA-1 added to Firebase Console
- [ ] New `google-services.json` downloaded
- [ ] `google-services.json` placed in `android/app/`
- [ ] App rebuilt (`flutter clean` then `flutter run`)

---

## 🐛 Still Not Working?

### Check 1: Verify Package Name
- Package name in `build.gradle.kts`: `com.example.chatapp`
- Package name in `google-services.json`: `com.example.chatapp`
- Must match exactly!

### Check 2: Verify google-services.json Location
- Must be in: `android/app/google-services.json`
- Not in `android/` root

### Check 3: Check Firebase Project
- Make sure you're using the correct Firebase project
- Project ID should be: `my-chat-app-7b3a3`

### Check 4: Re-enable Google Services
- In Firebase Console → Project Settings
- Make sure **Google Services** are enabled
- Check **Cloud Messaging API** is enabled

---

## ⚡ Quick Fix Command

**Get SHA-1 on Windows:**
```powershell
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android | Select-String "SHA1"
```

This will show just the SHA-1 line.

