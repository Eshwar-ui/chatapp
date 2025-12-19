const express = require('express');
const admin = require('firebase-admin');
const cors = require('cors');
const fs = require('fs');
const path = require('path');

const app = express();
app.use(cors());
app.use(express.json());

// Initialize Firebase Admin SDK
// Supports both file-based and environment variable credentials
let serviceAccount = null;

// Try to load from file first
const serviceAccountPath = path.join(__dirname, 'serviceAccountKey.json');
if (fs.existsSync(serviceAccountPath)) {
  serviceAccount = require(serviceAccountPath);
  console.log('✅ Loaded service account from file');
} else if (process.env.FIREBASE_SERVICE_ACCOUNT) {
  // Try to load from environment variable (JSON string)
  try {
    serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    console.log('✅ Loaded service account from environment variable');
  } catch (e) {
    console.error('❌ Failed to parse FIREBASE_SERVICE_ACCOUNT environment variable');
  }
} else {
  console.error('❌ ERROR: serviceAccountKey.json not found!');
  console.error('\n📋 To fix this:');
  console.error('1. Go to Firebase Console: https://console.firebase.google.com');
  console.error('2. Select your project');
  console.error('3. Go to Project Settings (gear icon) > Service Accounts');
  console.error('4. Click "Generate New Private Key"');
  console.error('5. Save the JSON file as "serviceAccountKey.json" in this directory');
  console.error('6. Or set FIREBASE_SERVICE_ACCOUNT environment variable with the JSON content\n');
  process.exit(1);
}

try {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  console.log('✅ Firebase Admin SDK initialized successfully');
} catch (error) {
  console.error('❌ Failed to initialize Firebase Admin SDK:', error.message);
  process.exit(1);
}

// Endpoint to send push notification
app.post('/send-notification', async (req, res) => {
  try {
    const { token, title, body, data } = req.body;

    if (!token || !title || !body) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: data || {},
      token: token,
      android: {
        priority: 'high',
      },
      apns: {
        headers: {
          'apns-priority': '10',
        },
      },
    };

    const response = await admin.messaging().send(message);
    res.json({ success: true, messageId: response });
  } catch (error) {
    console.error('Error sending notification:', error);
    res.status(500).json({ error: error.message });
  }
});

// Endpoint to send to multiple tokens
app.post('/send-notifications', async (req, res) => {
  try {
    const { tokens, title, body, data } = req.body;

    if (!tokens || !Array.isArray(tokens) || tokens.length === 0) {
      return res.status(400).json({ error: 'Invalid tokens array' });
    }

    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: data || {},
      tokens: tokens,
      android: {
        priority: 'high',
      },
    };

    const response = await admin.messaging().sendEachForMulticast(message);
    res.json({
      success: true,
      successCount: response.successCount,
      failureCount: response.failureCount,
    });
  } catch (error) {
    console.error('Error sending notifications:', error);
    res.status(500).json({ error: error.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Notification server running on port ${PORT}`);
});

