const {setGlobalOptions} = require('firebase-functions/v2');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {logger} = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

setGlobalOptions({
  region: 'asia-south1',
  maxInstances: 10,
});

const db = admin.firestore();

function normalizeData(data) {
  if (!data || typeof data !== 'object' || Array.isArray(data)) {
    return {};
  }

  return Object.fromEntries(
    Object.entries(data).map(([key, value]) => [key, String(value)]),
  );
}

function isInvalidTokenError(error) {
  return [
    'messaging/registration-token-not-registered',
    'messaging/invalid-registration-token',
  ].includes(error?.code);
}

exports.sendChatNotification = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      'unauthenticated',
      'You must be signed in to send chat notifications.',
    );
  }

  const {recipientUserId, chatRoomId, body, data} = request.data || {};
  const senderUserId = request.auth.uid;

  if (
    typeof recipientUserId !== 'string' ||
    typeof chatRoomId !== 'string' ||
    typeof body !== 'string' ||
    body.trim().length === 0
  ) {
    throw new HttpsError('invalid-argument', 'Missing required fields.');
  }

  if (recipientUserId === senderUserId) {
    throw new HttpsError('invalid-argument', 'Cannot notify yourself.');
  }

  const chatRoomDoc = await db.collection('chatRooms').doc(chatRoomId).get();
  if (!chatRoomDoc.exists) {
    throw new HttpsError('not-found', 'Chat room not found.');
  }

  const participants = chatRoomDoc.data().participants || [];
  if (
    !participants.includes(senderUserId) ||
    !participants.includes(recipientUserId)
  ) {
    throw new HttpsError('permission-denied', 'Not a chat participant.');
  }

  const tokenDoc = await db.collection('user_tokens').doc(recipientUserId).get();
  const token = tokenDoc.exists ? tokenDoc.data().token : null;

  if (!token) {
    return {
      success: false,
      reason: 'recipient-token-missing',
    };
  }

  const settingsDoc = await db
    .collection('user_settings')
    .doc(recipientUserId)
    .get();
  const settings = settingsDoc.exists ? settingsDoc.data() : {};
  const mutedChatRoomIds = Array.isArray(settings.mutedChatRoomIds)
    ? settings.mutedChatRoomIds
    : [];
  const blockedUserIds = Array.isArray(settings.blockedUserIds)
    ? settings.blockedUserIds
    : [];

  if (
    settings.notificationsEnabled === false ||
    mutedChatRoomIds.includes(chatRoomId) ||
    blockedUserIds.includes(senderUserId)
  ) {
    return {
      success: false,
      reason: 'recipient-notifications-muted',
    };
  }

  const senderDoc = await db.collection('users').doc(senderUserId).get();
  const senderData = senderDoc.exists ? senderDoc.data() : {};
  const senderName =
    senderData.displayName ||
    request.auth.token.email?.split('@')[0] ||
    'Someone';

  try {
    const messageId = await admin.messaging().send({
      notification: {
        title: senderName,
        body,
      },
      data: {
        ...normalizeData(data),
        chatRoomId,
        senderUserId,
      },
      token,
      android: {
        priority: 'high',
      },
      apns: {
        headers: {
          'apns-priority': '10',
        },
      },
    });

    return {
      success: true,
      messageId,
    };
  } catch (error) {
    if (isInvalidTokenError(error)) {
      await db.collection('user_tokens').doc(recipientUserId).delete();
      return {
        success: false,
        reason: 'recipient-token-invalid',
      };
    }

    logger.error('Error sending chat notification', error);
    throw new HttpsError('internal', 'Failed to send chat notification.');
  }
});
