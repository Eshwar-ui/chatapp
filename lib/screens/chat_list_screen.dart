import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../models/chat_room_model.dart';
import '../models/user_model.dart';
import '../core/design/brutalist_colors.dart';
import '../core/design/brutalist_theme.dart';
import 'individual_chat_screen.dart';
import 'users_list_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  ImageProvider? _getProfileImage({String? imageUrl, String? base64Image}) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return NetworkImage(imageUrl);
    }
    if (base64Image == null || base64Image.isEmpty) return null;
    try {
      final bytes = base64Decode(base64Image);
      return MemoryImage(bytes);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Please log in',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: BrutalistColors.lightBackground,
      appBar: AppBar(
        title: Text('Chats', style: Theme.of(context).textTheme.headlineMedium),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('chatRooms')
            .where('participants', arrayContains: currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 80,
                    color: BrutalistColors.lightTextSecondary,
                  ),
                  const SizedBox(height: BrutalistTheme.spacingMD),
                  Text(
                    'No chats yet',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: BrutalistTheme.spacingSM),
                  Text(
                    'Start a new conversation',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: BrutalistTheme.spacingLG),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const UsersListScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.people_outline),
                    label: const Text('Find people'),
                  ),
                ],
              ),
            );
          }

          final chatRooms =
              snapshot.data!.docs
                  .map((doc) => ChatRoomModel.fromFirestore(doc))
                  .toList()
                ..sort((a, b) {
                  final aPinned = a.pinnedBy.contains(currentUserId);
                  final bPinned = b.pinnedBy.contains(currentUserId);
                  if (aPinned != bPinned) return aPinned ? -1 : 1;

                  final timeA = a.lastMessageTime ?? a.createdAt;
                  final timeB = b.lastMessageTime ?? b.createdAt;
                  return timeB.compareTo(timeA);
                });

          return ListView.separated(
            padding: const EdgeInsets.symmetric(
              vertical: BrutalistTheme.spacingSM,
            ),
            itemCount: chatRooms.length,
            separatorBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(left: 84),
              child: Divider(
                height: 1,
                thickness: 1,
                color: BrutalistColors.lightBorder.withValues(alpha: 0.6),
              ),
            ),
            itemBuilder: (context, index) {
              final chatRoom = chatRooms[index];
              final otherUserId = chatRoom.getOtherParticipantId(currentUserId);
              final unreadCount = chatRoom.unreadCount[currentUserId] ?? 0;

              return StreamBuilder<DocumentSnapshot>(
                stream: _firestore
                    .collection('users')
                    .doc(otherUserId)
                    .snapshots(),
                builder: (context, userSnapshot) {
                  final userData =
                      userSnapshot.data?.data() as Map<String, dynamic>?;
                  final user = userData != null
                      ? UserModel.fromFirestore(userData, otherUserId!)
                      : null;

                  final profileImage = _getProfileImage(
                    imageUrl: userData?['profilePictureUrl'] as String?,
                    base64Image: userData?['profilePictureBase64'] as String?,
                  );

                  final hasUnread = unreadCount > 0;

                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => IndividualChatScreen(
                            chatRoomId: chatRoom.id,
                            otherUser: user,
                          ),
                        ),
                      );
                    },
                    onLongPress: () {
                      _showChatActions(chatRoom, currentUserId);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: BrutalistTheme.spacingMD,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: BrutalistColors.cream,
                              shape: BoxShape.circle,
                              image: profileImage != null
                                  ? DecorationImage(
                                      image: profileImage,
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: profileImage == null
                                ? Center(
                                    child: Text(
                                      user?.displayNameOrEmail[0]
                                              .toUpperCase() ??
                                          '?',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(
                                            fontSize: 24,
                                            color:
                                                BrutalistColors.primaryAccent,
                                          ),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: BrutalistTheme.spacingMD),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        user?.displayNameOrEmail ??
                                            'Unknown user',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (chatRoom.lastMessageTime != null)
                                      Text(
                                        _formatTime(chatRoom.lastMessageTime!),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: hasUnread
                                                  ? BrutalistColors
                                                        .primaryAccent
                                                  : BrutalistColors
                                                        .lightTextSecondary,
                                              fontWeight: hasUnread
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                            ),
                                      ),
                                  ],
                                ),
                                const SizedBox(
                                  height: BrutalistTheme.spacingXS,
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        chatRoom.lastMessage ??
                                            'No messages yet',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: hasUnread
                                                  ? BrutalistColors.lightText
                                                  : BrutalistColors
                                                        .lightTextSecondary,
                                              fontWeight: hasUnread
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (hasUnread)
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        constraints: const BoxConstraints(
                                          minWidth: 20,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: BrutalistColors.primaryAccent,
                                          borderRadius: BorderRadius.circular(
                                            BrutalistTheme.radiusPill,
                                          ),
                                        ),
                                        child: Text(
                                          unreadCount > 99
                                              ? '99+'
                                              : unreadCount.toString(),
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color:
                                                    BrutalistColors.pureWhite,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                    if (!hasUnread &&
                                        chatRoom.pinnedBy.contains(
                                          currentUserId,
                                        ))
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: Icon(
                                          Icons.push_pin,
                                          size: 14,
                                          color: BrutalistColors
                                              .lightTextSecondary,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(time);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE').format(time);
    } else {
      return DateFormat('MMM d').format(time);
    }
  }

  void _showChatActions(ChatRoomModel chatRoom, String currentUserId) {
    final isPinned = chatRoom.pinnedBy.contains(currentUserId);
    showModalBottomSheet(
      context: context,
      backgroundColor: BrutalistColors.chatPanel,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(BrutalistTheme.radiusLG),
        ),
        side: BorderSide(
          color: BrutalistColors.lightBorder,
          width: BrutalistTheme.borderWidthThin,
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: ListTile(
            leading: Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin),
            title: Text(isPinned ? 'Unpin chat' : 'Pin chat'),
            onTap: () async {
              Navigator.pop(context);
              await _firestore.collection('chatRooms').doc(chatRoom.id).update({
                'pinnedBy': isPinned
                    ? FieldValue.arrayRemove([currentUserId])
                    : FieldValue.arrayUnion([currentUserId]),
              });
            },
          ),
        );
      },
    );
  }
}
