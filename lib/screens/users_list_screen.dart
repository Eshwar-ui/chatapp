import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import '../models/user_model.dart';
import '../models/chat_room_model.dart';
import '../core/design/brutalist_colors.dart';
import '../core/design/brutalist_theme.dart';
import 'individual_chat_screen.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  Future<String?> _getOrCreateChatRoom(String otherUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return null;

    final existingRooms = await _firestore
        .collection('chatRooms')
        .where('participants', arrayContains: currentUserId)
        .get();

    for (var room in existingRooms.docs) {
      final chatRoom = ChatRoomModel.fromFirestore(room);
      if (chatRoom.participants.length == 2 &&
          chatRoom.participants.contains(otherUserId)) {
        return room.id;
      }
    }

    final now = Timestamp.now();
    final newRoom = await _firestore.collection('chatRooms').add({
      'participants': [currentUserId, otherUserId],
      'lastMessage': null,
      'lastMessageId': null,
      'lastMessageTime': now,
      'lastMessageSenderId': null,
      'unreadCount': {currentUserId: 0, otherUserId: 0},
      'typing': {},
      'pinnedBy': [],
      'createdAt': FieldValue.serverTimestamp(),
    });

    return newRoom.id;
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: BrutalistColors.lightBackground,
      appBar: AppBar(
        title: Text(
          'Contacts',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(BrutalistTheme.spacingMD),
            child: TextField(
              controller: _searchController,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: const InputDecoration(
                hintText: 'Search people',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData) {
                  return Center(
                    child: Text(
                      'No users found',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  );
                }

                final allUsers = snapshot.data!.docs
                    .map(
                      (doc) => UserModel.fromFirestore(
                        doc.data() as Map<String, dynamic>,
                        doc.id,
                      ),
                    )
                    .where(
                      (user) =>
                          user.uid != currentUserId &&
                          (_searchQuery.isEmpty ||
                              user.displayNameOrEmail.toLowerCase().contains(
                                _searchQuery,
                              )),
                    )
                    .toList();

                if (allUsers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 80,
                          color: BrutalistColors.lightTextSecondary,
                        ),
                        const SizedBox(height: BrutalistTheme.spacingMD),
                        Text(
                          'No users found',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    vertical: BrutalistTheme.spacingSM,
                  ),
                  itemCount: allUsers.length,
                  separatorBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(left: 84),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: BrutalistColors.lightBorder.withValues(alpha: 0.6),
                    ),
                  ),
                  itemBuilder: (context, index) {
                    final user = allUsers[index];
                    final userData =
                        snapshot.data!.docs
                                .firstWhere((doc) => doc.id == user.uid)
                                .data()
                            as Map<String, dynamic>;
                    final profileImage = _getProfileImage(
                      imageUrl: userData['profilePictureUrl'] as String?,
                      base64Image: userData['profilePictureBase64'] as String?,
                    );

                    return InkWell(
                      onTap: () async {
                        final chatRoomId = await _getOrCreateChatRoom(
                          user.uid,
                        );
                        if (!context.mounted || chatRoomId == null) {
                          return;
                        }

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => IndividualChatScreen(
                              chatRoomId: chatRoomId,
                              otherUser: user,
                            ),
                          ),
                        );
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
                                        user.displayNameOrEmail[0]
                                            .toUpperCase(),
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
                                  Text(
                                    user.displayNameOrEmail,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(
                                    height: BrutalistTheme.spacingXS,
                                  ),
                                  Text(
                                    user.email,
                                    style: Theme.of(context).textTheme.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 20,
                              color: BrutalistColors.lightTextSecondary,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
