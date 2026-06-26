import 'package:chatapp/utils/chat_message_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatMessageUtils', () {
    test('hides messages deleted for the current user', () {
      final message = {
        'deletedFor': ['user-1'],
      };

      expect(ChatMessageUtils.shouldShowMessage(message, 'user-1'), isFalse);
      expect(ChatMessageUtils.shouldShowMessage(message, 'user-2'), isTrue);
    });

    test('detects deleted-for-everyone messages', () {
      expect(
        ChatMessageUtils.isDeletedForEveryone({'deletedForEveryone': true}),
        isTrue,
      );
    });

    test('aggregates reactions by emoji', () {
      final reactions = {'user-1': '❤️', 'user-2': '❤️', 'user-3': '😂'};

      expect(ChatMessageUtils.aggregateReactions(reactions), {
        '❤️': 2,
        '😂': 1,
      });
    });

    test('builds reply preview data from text messages', () {
      final fields = ChatMessageUtils.buildReplyFields(
        messageId: 'message-1',
        data: {'text': 'Hello', 'userId': 'user-1'},
      );

      expect(fields['replyToMessageId'], 'message-1');
      expect(fields['replyPreviewText'], 'Hello');
      expect(fields['replyPreviewSenderId'], 'user-1');
    });

    test('builds reply preview data from image messages', () {
      final fields = ChatMessageUtils.buildReplyFields(
        messageId: 'message-1',
        data: {'imageUrl': 'https://example.com/image.png', 'userId': 'user-1'},
      );

      expect(fields['replyPreviewText'], 'Photo');
      expect(fields['replyPreviewImageUrl'], 'https://example.com/image.png');
    });

    test('uses deleted placeholder for deleted reply previews', () {
      expect(
        ChatMessageUtils.buildReplyPreviewText({
          'deletedForEveryone': true,
          'text': 'Hidden text',
        }),
        'Deleted message',
      );
    });

    test('detects fresh typing timestamps', () {
      final now = DateTime(2026, 5, 2, 10);
      final recent = Timestamp.fromDate(
        now.subtract(const Duration(seconds: 3)),
      );
      final stale = Timestamp.fromDate(
        now.subtract(const Duration(seconds: 8)),
      );

      expect(ChatMessageUtils.isTypingRecently(recent, now: now), isTrue);
      expect(ChatMessageUtils.isTypingRecently(stale, now: now), isFalse);
    });
  });
}
