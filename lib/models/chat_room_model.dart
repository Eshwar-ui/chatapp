import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoomModel {
  final String id;
  final List<String> participants; // User IDs
  final String? lastMessage;
  final String? lastMessageId;
  final DateTime? lastMessageTime;
  final String? lastMessageSenderId;
  final Map<String, int> unreadCount; // userId -> unread count
  final List<String> pinnedBy;
  final DateTime createdAt;

  ChatRoomModel({
    required this.id,
    required this.participants,
    this.lastMessage,
    this.lastMessageId,
    this.lastMessageTime,
    this.lastMessageSenderId,
    this.unreadCount = const {},
    this.pinnedBy = const [],
    required this.createdAt,
  });

  factory ChatRoomModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatRoomModel(
      id: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'],
      lastMessageId: data['lastMessageId'],
      lastMessageTime: data['lastMessageTime']?.toDate(),
      lastMessageSenderId: data['lastMessageSenderId'],
      unreadCount: Map<String, int>.from(data['unreadCount'] ?? {}),
      pinnedBy: List<String>.from(data['pinnedBy'] ?? []),
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageId': lastMessageId,
      'lastMessageTime': lastMessageTime,
      'lastMessageSenderId': lastMessageSenderId,
      'unreadCount': unreadCount,
      'pinnedBy': pinnedBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Get the other participant's ID
  String? getOtherParticipantId(String currentUserId) {
    if (participants.length != 2) return null;
    return participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => participants.first,
    );
  }
}
