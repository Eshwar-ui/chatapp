import 'package:chatapp/models/chat_room_model.dart';
import 'package:chatapp/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserModel', () {
    test('uses display name when available', () {
      final user = UserModel(
        uid: 'user-1',
        email: 'person@example.com',
        displayName: 'Person',
      );

      expect(user.displayNameOrEmail, 'Person');
    });

    test('falls back to email prefix when display name is missing', () {
      final user = UserModel(uid: 'user-1', email: 'person@example.com');

      expect(user.displayNameOrEmail, 'person');
    });

    test('serializes profile image URL', () {
      final user = UserModel(
        uid: 'user-1',
        email: 'person@example.com',
        profilePictureUrl: 'https://example.com/profile.png',
      );

      expect(
        user.toFirestore()['profilePictureUrl'],
        'https://example.com/profile.png',
      );
    });
  });

  group('ChatRoomModel', () {
    test('finds the other participant in a one-to-one room', () {
      final room = ChatRoomModel(
        id: 'room-1',
        participants: const ['user-1', 'user-2'],
        lastMessageId: 'message-1',
        createdAt: DateTime(2026),
      );

      expect(room.getOtherParticipantId('user-1'), 'user-2');
      expect(room.toFirestore()['lastMessageId'], 'message-1');
    });

    test('returns null when room is not one-to-one', () {
      final room = ChatRoomModel(
        id: 'room-1',
        participants: const ['user-1', 'user-2', 'user-3'],
        createdAt: DateTime(2026),
      );

      expect(room.getOtherParticipantId('user-1'), isNull);
    });
  });
}
