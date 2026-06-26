# Chat App Capabilities

This document summarizes what the current Flutter chat app can do based on the implemented screens, services, Firebase Functions, and Firebase configuration.

## Overview

The app is a Firebase-backed one-to-one chat application. Users can sign up, sign in, discover other users, start conversations, send text and image messages, receive push notifications, manage their profile, and control chat/privacy settings.

## Account And Authentication

- Sign up with email and password.
- Sign in with email and password.
- Validate email and password fields before submission.
- Automatically create a Firestore user profile after sign-up.
- Track logged-in state with Firebase Auth and route users to either authentication or the main app.
- Log out from the settings screen.
- Remove the user's FCM token on logout.
- Mark the user offline on logout.

## Main Navigation

The app has three main tabs:

- Chats
- Contacts
- Profile

The navigation shell keeps each tab alive with an `IndexedStack`, so switching tabs does not rebuild every screen from scratch.

## Permissions

The app includes a one-time permission onboarding screen for:

- Notifications
- Media/gallery access
- Camera access

Permission handling supports:

- Android notification permission.
- Android 13+ photo/media permission.
- Older Android storage permission fallback.
- Camera permission.
- Limited photo access where supported.
- Opening app settings when a permission is denied.

The app declares Android permissions for internet, notifications, vibration, boot completed events, camera, modern media image access, selected visual media access, legacy read storage, legacy write storage, biometric, and fingerprint access.

## Contacts And Starting Chats

- Show all registered users from Firestore except the current user.
- Search contacts by display name or email prefix.
- Show profile avatars from URL or base64 image data.
- Start a one-to-one chat with another user.
- Reuse an existing one-to-one chat room if one already exists.
- Create a new Firestore chat room when starting a new conversation.

## Chat List

- Show all chat rooms that include the current user.
- Sort chats with pinned conversations first.
- Sort remaining chats by most recent activity.
- Show the other participant's name and avatar.
- Show the latest message preview.
- Show latest message time.
- Show unread message count.
- Show pinned state.
- Long-press a chat to pin or unpin it.
- Show an empty state with a shortcut to find people.

## Individual Chat

The individual chat screen supports:

- Real-time message streaming from Firestore.
- Text messages.
- Image messages from gallery.
- Image messages from camera.
- Firebase Storage upload for chat images.
- Upload progress indicator.
- Push notification trigger after sending a message.
- Message read tracking.
- Chat unread count reset when opening a conversation.
- Message delivery/read status indicators.
- Typing indicators.
- Online/last-seen display for the other participant.
- Conversation header with avatar, name, and presence.

## Message Actions

Users can long-press a message to:

- React with quick emoji reactions.
- Reply to a message.
- Copy message text.
- Edit their own text messages.
- Delete a message for themselves.
- Delete their own messages for everyone.

The composer supports:

- Reply preview.
- Edit mode preview.
- Cancel reply/edit mode.
- Disabled send button when there is no text.
- Disabled attachment button during image upload.
- Attachment sheet for gallery and camera.

## Shared Media And Search

Inside conversation info, users can:

- Open shared media for the chat.
- Browse image messages in a grid.
- Open image previews with zoom/pan support.
- Search message text in the current chat.

## Conversation Controls

The conversation info panel supports:

- View shared media.
- Mute or unmute notifications for a chat.
- Clear chat for the current user.
- Block or unblock the other user.
- Report the other user.

Reports are saved to the `user_reports` Firestore collection.

## Profile

The profile screen supports:

- Display current user's avatar.
- Display display name or email prefix.
- Display email address.
- Display Firebase Auth user ID.
- Display online/offline status.
- Navigate to profile editing.
- Navigate to settings.

Profile editing supports:

- Update display name.
- Pick a profile picture from the gallery.
- Compress profile images before upload.
- Upload profile images to Firebase Storage.
- Save profile image URL to Firestore.

## Settings

The settings screen supports:

- Enable or disable notifications.
- Enable or disable notification sound.
- Enable or disable notification vibration.
- Toggle read receipts.
- Toggle last seen visibility.
- Toggle profile visibility.
- Log out.
- View app version.

Settings are stored in Firestore for signed-in users and partially in local preferences where needed.

## Presence

The app tracks user presence through Firestore:

- Sets users online when the app is active.
- Sets users offline when the app is paused, inactive, detached, hidden, or disposed.
- Updates `lastSeen` timestamps.

## Push Notifications

The app uses Firebase Cloud Messaging and local notifications:

- Requests notification permission.
- Saves the user's FCM token in Firestore.
- Deletes the user's FCM token on logout.
- Shows local notifications when messages arrive in the foreground.
- Handles background notification messages.
- Opens the correct chat when a notification is tapped.
- Refreshes saved FCM tokens when Firebase rotates them.

A Firebase Callable Function named `sendChatNotification`:

- Requires authentication.
- Validates required fields.
- Verifies the sender and recipient are both chat participants.
- Reads the recipient FCM token.
- Respects recipient notification settings.
- Respects muted chat rooms.
- Respects blocked users.
- Sends high-priority FCM notifications.
- Deletes invalid recipient tokens when Firebase reports them as invalid.

## Firebase Data Used

The app uses these main Firestore collections:

- `users`: user profiles, profile images, online status, and last seen.
- `chatRooms`: chat room metadata, participants, unread counts, typing state, pinned state, and last message info.
- `chatRooms/{chatRoomId}/messages`: text/image messages, read status, edits, deletes, reactions, and replies.
- `user_tokens`: FCM token storage.
- `user_settings`: notification, privacy, muted chat, and blocked user settings.
- `user_reports`: user reports submitted from conversation info.

The app uses Firebase Storage for:

- Chat image uploads.
- Profile image uploads.

## Platform Support

This is a Flutter project with platform folders for:

- Android
- iOS
- Web
- Windows
- macOS
- Linux

The actively configured mobile Firebase behavior is centered on Android/iOS style chat, media, notification, and permission flows.

## Currently Disabled Or Not Fully Wired

- App lock / PIN / biometric lock code exists in `lib/services/applock.dart`, but it is commented out and currently disabled.
- Theme mode support exists in `SettingsService`, but the visible settings UI currently focuses on notifications, privacy, account, and about.
- Firestore was recently cleared for a fresh start, so users/chats need to be recreated by signing up and using the app again.
