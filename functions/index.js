const {setGlobalOptions} = require('firebase-functions/v2');
const {onDocumentCreated} = require('firebase-functions/v2/firestore');
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

function messagePreview(messageData) {
  const text = messageData?.text;
  if (typeof text === 'string' && text.trim().length > 0) {
    return text.trim();
  }

  if (typeof messageData?.imageUrl === 'string' && messageData.imageUrl) {
    return 'Sent an image';
  }

  return 'Sent a message';
}

async function getSenderName(senderUserId, fallbackEmail) {
  const senderDoc = await db.collection('users').doc(senderUserId).get();
  const senderData = senderDoc.exists ? senderDoc.data() : {};

  return (
    senderData.displayName ||
    senderData.email?.split('@')[0] ||
    fallbackEmail?.split('@')[0] ||
    'Someone'
  );
}

async function shouldSkipRecipient({
  recipientUserId,
  senderUserId,
  chatRoomId,
}) {
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

  return (
    settings.notificationsEnabled === false ||
    mutedChatRoomIds.includes(chatRoomId) ||
    blockedUserIds.includes(senderUserId)
  );
}

async function sendChatNotificationToRecipient({
  recipientUserId,
  senderUserId,
  senderName,
  chatRoomId,
  messageId,
  body,
  data = {},
}) {
  const tokenDoc = await db.collection('user_tokens').doc(recipientUserId).get();
  const token = tokenDoc.exists ? tokenDoc.data().token : null;

  if (!token) {
    return {
      success: false,
      reason: 'recipient-token-missing',
    };
  }

  if (
    await shouldSkipRecipient({recipientUserId, senderUserId, chatRoomId})
  ) {
    return {
      success: false,
      reason: 'recipient-notifications-muted',
    };
  }

  try {
    const fcmMessageId = await admin.messaging().send({
      notification: {
        title: senderName,
        body,
      },
      data: {
        ...normalizeData(data),
        chatRoomId,
        senderUserId,
        ...(messageId ? {messageId} : {}),
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
      messageId: fcmMessageId,
    };
  } catch (error) {
    if (isInvalidTokenError(error)) {
      await db.collection('user_tokens').doc(recipientUserId).delete();
      return {
        success: false,
        reason: 'recipient-token-invalid',
      };
    }

    logger.error('Error sending chat notification', {
      error,
      recipientUserId,
      chatRoomId,
      messageId,
    });
    return {
      success: false,
      reason: 'send-failed',
    };
  }
}

exports.sendNotificationOnMessageCreated = onDocumentCreated(
  'chatRooms/{chatRoomId}/messages/{messageId}',
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const {chatRoomId, messageId} = event.params;
    const messageData = snapshot.data();
    const senderUserId = messageData.userId;

    if (typeof senderUserId !== 'string' || senderUserId.length === 0) {
      logger.warn('Message missing sender user id', {chatRoomId, messageId});
      return;
    }

    const chatRoomDoc = await db.collection('chatRooms').doc(chatRoomId).get();
    if (!chatRoomDoc.exists) {
      logger.warn('Message created for missing chat room', {
        chatRoomId,
        messageId,
      });
      return;
    }

    const participants = chatRoomDoc.data().participants || [];
    if (!participants.includes(senderUserId)) {
      logger.warn('Message sender is not a chat participant', {
        chatRoomId,
        messageId,
        senderUserId,
      });
      return;
    }

    const recipientUserIds = participants.filter((id) => id !== senderUserId);
    if (recipientUserIds.length === 0) return;

    const senderName = await getSenderName(senderUserId, messageData.userEmail);
    const body = messagePreview(messageData);

    const results = await Promise.all(
      recipientUserIds.map((recipientUserId) =>
        sendChatNotificationToRecipient({
          recipientUserId,
          senderUserId,
          senderName,
          chatRoomId,
          messageId,
          body,
        }),
      ),
    );

    logger.info('Message notification trigger completed', {
      chatRoomId,
      messageId,
      recipientCount: recipientUserIds.length,
      results,
    });
  },
);

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

  const senderName = await getSenderName(
    senderUserId,
    request.auth.token.email,
  );

  const result = await sendChatNotificationToRecipient({
    recipientUserId,
    senderUserId,
    senderName,
    chatRoomId,
    body,
    data,
  });

  if (result.reason === 'send-failed') {
    throw new HttpsError('internal', 'Failed to send chat notification.');
  }

  return result;
});
