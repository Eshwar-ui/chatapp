import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessageUtils {
  static const typingTimeout = Duration(seconds: 6);
  static const quickReactions = ['👍', '❤️', '😂', '😢', '😮', '🔥'];

  static bool isDeletedForEveryone(Map<String, dynamic> data) {
    return data['deletedForEveryone'] == true;
  }

  static bool isDeletedForCurrentUser(
    Map<String, dynamic> data,
    String currentUserId,
  ) {
    final deletedFor = List<String>.from(data['deletedFor'] ?? []);
    return deletedFor.contains(currentUserId);
  }

  static bool shouldShowMessage(
    Map<String, dynamic> data,
    String currentUserId,
  ) {
    return !isDeletedForCurrentUser(data, currentUserId);
  }

  static Map<String, int> aggregateReactions(Map<String, dynamic>? reactions) {
    final counts = <String, int>{};
    if (reactions == null) return counts;

    for (final reaction in reactions.values) {
      if (reaction is! String || reaction.trim().isEmpty) continue;
      counts[reaction] = (counts[reaction] ?? 0) + 1;
    }

    final sortedCounts = <String, int>{};
    for (final reaction in quickReactions) {
      final count = counts.remove(reaction);
      if (count != null) sortedCounts[reaction] = count;
    }
    sortedCounts.addAll(counts);
    return sortedCounts;
  }

  static String buildReplyPreviewText(Map<String, dynamic> data) {
    if (isDeletedForEveryone(data)) return 'Deleted message';

    final text = data['text'] as String?;
    if (text != null && text.trim().isNotEmpty) return text.trim();

    final hasImage =
        (data['imageUrl'] as String?)?.isNotEmpty == true ||
        (data['imageBase64'] as String?)?.isNotEmpty == true;
    if (hasImage) return 'Photo';

    return 'Message';
  }

  static Map<String, dynamic> buildReplyFields({
    required String messageId,
    required Map<String, dynamic> data,
  }) {
    return {
      'replyToMessageId': messageId,
      'replyPreviewText': buildReplyPreviewText(data),
      'replyPreviewImageUrl': data['imageUrl'],
      'replyPreviewSenderId': data['userId'],
    };
  }

  static DateTime? timestampToDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static bool isTypingRecently(dynamic value, {DateTime? now}) {
    final typedAt = timestampToDateTime(value);
    if (typedAt == null) return false;

    final referenceTime = now ?? DateTime.now();
    return referenceTime.difference(typedAt) <= typingTimeout;
  }
}
