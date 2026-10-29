import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../models/chat_room_model.dart';
import '../services/permission_service.dart';
import '../services/settings_service.dart';
import '../utils/chat_message_utils.dart';
import '../utils/image_compressor.dart';
import '../core/design/brutalist_colors.dart';
import '../core/design/brutalist_theme.dart';

class IndividualChatScreen extends StatefulWidget {
  final String chatRoomId;
  final UserModel? otherUser;

  const IndividualChatScreen({
    super.key,
    required this.chatRoomId,
    this.otherUser,
  });

  @override
  State<IndividualChatScreen> createState() => _IndividualChatScreenState();
}

class _IndividualChatScreenState extends State<IndividualChatScreen> {
  final _messageController = TextEditingController();
  final _messageFocusNode = FocusNode();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;
  final _permissionService = PermissionService();
  final _settingsService = SettingsService();
  final _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  UserModel? _otherUser;
  String? _otherUserId;
  Timer? _typingDebounce;
  Timer? _typingExpiryTimer;
  _ReplyDraft? _replyDraft;
  String? _editingMessageId;
  String? _editingOriginalText;
  double? _imageUploadProgress;
  bool _isSendingText = false;
  bool _hasComposerText = false;

  DocumentReference<Map<String, dynamic>> get _chatRoomRef =>
      _firestore.collection('chatRooms').doc(widget.chatRoomId);

  CollectionReference<Map<String, dynamic>> get _messagesRef =>
      _chatRoomRef.collection('messages');

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_handleComposerChanged);
    _loadOtherUser();
    _markAsRead();
  }

  Future<void> _loadOtherUser() async {
    if (widget.otherUser != null) {
      setState(() {
        _otherUser = widget.otherUser;
        _otherUserId = widget.otherUser!.uid;
      });
      return;
    }

    final chatRoomDoc = await _firestore
        .collection('chatRooms')
        .doc(widget.chatRoomId)
        .get();
    if (chatRoomDoc.exists) {
      final chatRoom = ChatRoomModel.fromFirestore(chatRoomDoc);
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId != null) {
        _otherUserId = chatRoom.getOtherParticipantId(currentUserId);
        if (_otherUserId != null) {
          final userDoc = await _firestore
              .collection('users')
              .doc(_otherUserId)
              .get();
          if (userDoc.exists) {
            setState(() {
              _otherUser = UserModel.fromFirestore(
                userDoc.data()!,
                _otherUserId!,
              );
            });
          }
        }
      }
    }
  }

  void _handleComposerChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (hasText != _hasComposerText && mounted) {
      setState(() => _hasComposerText = hasText);
    }

    _typingDebounce?.cancel();

    if (_editingMessageId != null) {
      _clearTyping();
      return;
    }

    _typingDebounce = Timer(const Duration(milliseconds: 500), () {
      if (_messageController.text.trim().isEmpty) {
        _clearTyping();
      } else {
        _setTypingActive();
      }
    });
  }

  Future<void> _setTypingActive() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    _typingExpiryTimer?.cancel();
    _typingExpiryTimer = Timer(ChatMessageUtils.typingTimeout, _clearTyping);

    try {
      await _chatRoomRef.update({'typing.$currentUserId': Timestamp.now()});
    } catch (e) {
      debugPrint('Error updating typing status: $e');
    }
  }

  Future<void> _clearTyping() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    _typingExpiryTimer?.cancel();

    try {
      await _chatRoomRef.update({'typing.$currentUserId': FieldValue.delete()});
    } catch (e) {
      debugPrint('Error clearing typing status: $e');
    }
  }

  Future<void> _markAsRead() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    await _chatRoomRef.update({'unreadCount.$currentUserId': 0});
  }

  Future<void> _markMessagesAsRead(List<QueryDocumentSnapshot> messages) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    final batch = _firestore.batch();
    bool hasUpdates = false;

    for (var message in messages) {
      final data = message.data() as Map<String, dynamic>;
      final messageUserId = data['userId'] as String?;

      if (messageUserId != null && messageUserId != currentUserId) {
        final readBy = List<String>.from(data['readBy'] ?? []);
        if (!readBy.contains(currentUserId)) {
          batch.update(message.reference, {
            'readBy': FieldValue.arrayUnion([currentUserId]),
            'status': 'read',
          });
          hasUpdates = true;
        }
      }
    }

    if (hasUpdates) {
      await batch.commit();
    }
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _isSendingText || _imageUploadProgress != null) {
      return;
    }

    final user = _auth.currentUser;
    if (user == null) return;
    if (_otherUserId != null &&
        await _settingsService.isUserBlocked(_otherUserId!)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unblock this user to send messages.')),
      );
      return;
    }

    if (_editingMessageId != null) {
      await _submitMessageEdit(messageText, user.uid);
      return;
    }

    final replyFields = _replyDraft?.toFirestore() ?? {};
    final replyDraft = _replyDraft;
    setState(() => _isSendingText = true);
    _messageController.clear();
    setState(() => _hasComposerText = false);
    setState(() => _replyDraft = null);
    await _clearTyping();

    try {
      final messageRef = await _messagesRef.add({
        'text': messageText,
        'createdAt': Timestamp.now(),
        'userId': user.uid,
        'userEmail': user.email,
        'status': 'sent',
        'readBy': [user.uid],
        'isEdited': false,
        'editedAt': null,
        'deletedFor': [],
        'deletedForEveryone': false,
        'deletedAt': null,
        'reactions': {},
        ...replyFields,
      });

      final chatRoomUpdate = <String, dynamic>{
        'lastMessage': messageText,
        'lastMessageId': messageRef.id,
        'lastMessageTime': Timestamp.now(),
        'lastMessageSenderId': user.uid,
      };
      if (_otherUserId != null) {
        chatRoomUpdate['unreadCount.$_otherUserId'] = FieldValue.increment(1);
      }
      await _chatRoomRef.update(chatRoomUpdate);

    } catch (e) {
      _messageController.text = messageText;
      setState(() => _replyDraft = replyDraft);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            action: SnackBarAction(label: 'Retry', onPressed: _sendMessage),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingText = false);
      }
    }
  }

  Future<void> _submitMessageEdit(
    String messageText,
    String currentUserId,
  ) async {
    final messageId = _editingMessageId;
    if (messageId == null) return;

    await _messagesRef.doc(messageId).update({
      'text': messageText,
      'isEdited': true,
      'editedAt': Timestamp.now(),
    });

    final chatRoomDoc = await _chatRoomRef.get();
    final chatRoomData = chatRoomDoc.data();
    if (chatRoomData?['lastMessageId'] == messageId ||
        (chatRoomData?['lastMessageSenderId'] == currentUserId &&
            chatRoomData?['lastMessage'] == _editingOriginalText)) {
      await _chatRoomRef.update({'lastMessage': messageText});
    }

    _messageController.clear();
    setState(() {
      _editingMessageId = null;
      _editingOriginalText = null;
    });
  }

  void _startReply(String messageId, Map<String, dynamic> data) {
    setState(() {
      _editingMessageId = null;
      _editingOriginalText = null;
      _replyDraft = _ReplyDraft.fromMessage(messageId, data);
    });
    _messageFocusNode.requestFocus();
  }

  void _startEdit(String messageId, Map<String, dynamic> data) {
    final text = data['text'] as String?;
    if (text == null || text.trim().isEmpty) return;

    setState(() {
      _replyDraft = null;
      _editingMessageId = messageId;
      _editingOriginalText = text;
    });
    _messageController.text = text;
    _messageController.selection = TextSelection.collapsed(
      offset: _messageController.text.length,
    );
    _messageFocusNode.requestFocus();
  }

  void _cancelComposerMode() {
    final wasEditing = _editingMessageId != null;
    setState(() {
      _replyDraft = null;
      _editingMessageId = null;
      _editingOriginalText = null;
    });
    if (wasEditing) {
      _messageController.clear();
      _clearTyping();
    }
  }

  Future<void> _reactToMessage(
    String messageId,
    Map<String, dynamic> data,
    String emoji,
  ) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    final reactions = Map<String, dynamic>.from(data['reactions'] ?? {});
    final currentReaction = reactions[currentUserId] as String?;
    final reactionValue = currentReaction == emoji
        ? FieldValue.delete()
        : emoji;

    await _messagesRef.doc(messageId).update({
      'reactions.$currentUserId': reactionValue,
    });
  }

  Future<void> _deleteMessageForMe(String messageId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    await _messagesRef.doc(messageId).update({
      'deletedFor': FieldValue.arrayUnion([currentUserId]),
    });
  }

  Future<void> _deleteMessageForEveryone(String messageId) async {
    await _messagesRef.doc(messageId).update({
      'deletedForEveryone': true,
      'deletedAt': Timestamp.now(),
    });

    final chatRoomDoc = await _chatRoomRef.get();
    final chatRoomData = chatRoomDoc.data();
    if (chatRoomData?['lastMessageId'] == messageId) {
      await _chatRoomRef.update({'lastMessage': 'Message deleted'});
    }
  }

  Future<void> _copyMessageText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Message copied')));
  }

  Future<void> _clearChatForMe() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear chat?'),
        content: const Text('This hides all messages in this chat for you.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final messages = await _messagesRef.limit(500).get();
    final batch = _firestore.batch();
    for (final message in messages.docs) {
      batch.update(message.reference, {
        'deletedFor': FieldValue.arrayUnion([currentUserId]),
      });
    }
    await batch.commit();
  }

  void _showConversationInfo() {
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildConversationInfoHeader(),
                const SizedBox(height: BrutalistTheme.spacingMD),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Shared media'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _SharedMediaScreen(
                          chatRoomId: widget.chatRoomId,
                          currentUserId: _auth.currentUser?.uid,
                        ),
                      ),
                    );
                  },
                ),
                FutureBuilder<bool>(
                  future: _settingsService.isChatMuted(widget.chatRoomId),
                  builder: (context, snapshot) {
                    final isMuted = snapshot.data ?? false;
                    return SwitchListTile(
                      secondary: Icon(
                        isMuted
                            ? Icons.notifications_off
                            : Icons.notifications_active_outlined,
                      ),
                      title: const Text('Mute notifications'),
                      value: isMuted,
                      onChanged: (value) async {
                        await _settingsService.setChatMuted(
                          widget.chatRoomId,
                          value,
                        );
                        if (context.mounted) Navigator.pop(context);
                      },
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_sweep_outlined),
                  title: const Text('Clear chat'),
                  onTap: () {
                    Navigator.pop(context);
                    _clearChatForMe();
                  },
                ),
                FutureBuilder<bool>(
                  future: _otherUserId == null
                      ? Future.value(false)
                      : _settingsService.isUserBlocked(_otherUserId!),
                  builder: (context, snapshot) {
                    final isBlocked = snapshot.data ?? false;
                    return SwitchListTile(
                      secondary: Icon(
                        isBlocked ? Icons.block : Icons.block_flipped,
                      ),
                      title: Text(isBlocked ? 'Blocked' : 'Block user'),
                      value: isBlocked,
                      onChanged: _otherUserId == null
                          ? null
                          : (value) async {
                              await _settingsService.setUserBlocked(
                                _otherUserId!,
                                value,
                              );
                              if (context.mounted) Navigator.pop(context);
                            },
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.report_outlined),
                  title: const Text('Report user'),
                  onTap: () {
                    Navigator.pop(context);
                    _reportUser();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _reportUser() async {
    final currentUserId = _auth.currentUser?.uid;
    final reportedUserId = _otherUserId;
    if (currentUserId == null || reportedUserId == null) return;

    await _firestore.collection('user_reports').add({
      'reporterUserId': currentUserId,
      'reportedUserId': reportedUserId,
      'chatRoomId': widget.chatRoomId,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'open',
    });

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Report submitted')));
  }

  Widget _buildConversationInfoHeader() {
    return Row(
      children: [
        _buildHeaderAvatar(),
        const SizedBox(width: BrutalistTheme.spacingMD),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _otherUser?.displayNameOrEmail ?? 'User',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                _otherUser?.email ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: BrutalistColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showMessageActions({
    required String messageId,
    required Map<String, dynamic> data,
    required bool isMe,
  }) {
    final isDeleted = ChatMessageUtils.isDeletedForEveryone(data);
    final hasText = (data['text'] as String?)?.trim().isNotEmpty == true;

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
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isDeleted)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: ChatMessageUtils.quickReactions.map((emoji) {
                        return InkWell(
                          borderRadius: BorderRadius.circular(
                            BrutalistTheme.radiusPill,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _reactToMessage(messageId, data, emoji);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 26),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                if (!isDeleted)
                  ListTile(
                    leading: const Icon(Icons.reply_outlined),
                    title: const Text('Reply'),
                    onTap: () {
                      Navigator.pop(context);
                      _startReply(messageId, data);
                    },
                  ),
                if (hasText && !isDeleted)
                  ListTile(
                    leading: const Icon(Icons.copy_outlined),
                    title: const Text('Copy'),
                    onTap: () {
                      Navigator.pop(context);
                      _copyMessageText(data['text'] as String);
                    },
                  ),
                if (isMe && hasText && !isDeleted)
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Edit'),
                    onTap: () {
                      Navigator.pop(context);
                      _startEdit(messageId, data);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Delete for me'),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMessageForMe(messageId);
                  },
                ),
                if (isMe && !isDeleted)
                  ListTile(
                    leading: const Icon(Icons.delete_forever_outlined),
                    title: const Text('Delete for everyone'),
                    onTap: () {
                      Navigator.pop(context);
                      _deleteMessageForEveryone(messageId);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendImage(ImageSource source) async {
    try {
      // Check permission first
      bool hasPermission = false;
      if (source == ImageSource.camera) {
        hasPermission = await _permissionService.requestCameraPermission();
        if (!hasPermission && mounted) {
          final shouldRequest = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Camera Permission'),
              content: const Text(
                'We need camera permission to let you take photos and send them in your chats.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Allow'),
                ),
              ],
            ),
          );
          if (shouldRequest == true) {
            hasPermission = await _permissionService.requestCameraPermission();
          }
        }
      } else {
        hasPermission = await _permissionService.requestMediaPermission();
        if (!hasPermission && mounted) {
          final shouldRequest = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Media Permission'),
              content: const Text(
                'We need media permission to let you select photos from your gallery and send them in your chats.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Allow'),
                ),
              ],
            ),
          );
          if (shouldRequest == true) {
            hasPermission = await _permissionService.requestMediaPermission();
          }
        }
      }

      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Permission is required to select or capture images.',
              ),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: _permissionService.openSettings,
              ),
            ),
          );
        }
        return;
      }

      final pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 60, // Lower quality for better compression
      );

      if (pickedFile != null) {
        final user = _auth.currentUser;
        if (user == null) return;
        if (_otherUserId != null &&
            await _settingsService.isUserBlocked(_otherUserId!)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unblock this user to send images.'),
              ),
            );
          }
          return;
        }

        // Compress image before encoding to base64
        final compressedBytes = await ImageCompressor.compressImage(
          File(pickedFile.path),
          maxWidth: 800,
          maxHeight: 800,
          quality: 70,
        );

        if (compressedBytes == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to process image. Please try again.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }

        final imagePath =
            'chatRooms/${widget.chatRoomId}/messages/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.png';
        final imageRef = _storage.ref(imagePath);
        debugPrint(
          'Uploading chat image to gs://${imageRef.bucket}/${imageRef.fullPath}',
        );
        setState(() => _imageUploadProgress = 0);
        final uploadTask = imageRef.putData(
          compressedBytes,
          SettableMetadata(contentType: 'image/png'),
        );
        final uploadSubscription = uploadTask.snapshotEvents.listen((snapshot) {
          if (!mounted || snapshot.totalBytes == 0) return;
          setState(() {
            _imageUploadProgress =
                snapshot.bytesTransferred / snapshot.totalBytes;
          });
        });
        await uploadTask;
        await uploadSubscription.cancel();
        if (mounted) setState(() => _imageUploadProgress = null);
        final imageUrl = await imageRef.getDownloadURL();

        final replyFields = _replyDraft?.toFirestore() ?? {};
        setState(() => _replyDraft = null);
        await _clearTyping();

        // Add message with Storage image URL.
        final messageRef = await _messagesRef.add({
          'imageUrl': imageUrl,
          'imagePath': imagePath,
          'createdAt': Timestamp.now(),
          'userId': user.uid,
          'userEmail': user.email,
          'status': 'sent',
          'readBy': [user.uid],
          'isEdited': false,
          'editedAt': null,
          'deletedFor': [],
          'deletedForEveryone': false,
          'deletedAt': null,
          'reactions': {},
          ...replyFields,
        });

        // Update chat room
        final chatRoomUpdate = <String, dynamic>{
          'lastMessage': 'Image',
          'lastMessageId': messageRef.id,
          'lastMessageTime': Timestamp.now(),
          'lastMessageSenderId': user.uid,
        };
        if (_otherUserId != null) {
          chatRoomUpdate['unreadCount.$_otherUserId'] = FieldValue.increment(1);
        }
        await _chatRoomRef.update(chatRoomUpdate);

      }
    } on FirebaseException catch (e) {
      debugPrint(
        'Firebase Storage upload failed: code=${e.code}, '
        'message=${e.message}, bucket=${_storage.bucket}, '
        'chatRoomId=${widget.chatRoomId}, userId=${_auth.currentUser?.uid}',
      );
      if (mounted) setState(() => _imageUploadProgress = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to send image: ${e.code} ${e.message ?? ''}'.trim(),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _imageUploadProgress = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send image: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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

  Widget _buildHeaderAvatar() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(_otherUserId).snapshots(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final profileImage = _getProfileImage(
          imageUrl: userData?['profilePictureUrl'] as String?,
          base64Image: userData?['profilePictureBase64'] as String?,
        );

        return InkWell(
          customBorder: const CircleBorder(),
          onTap: _showConversationInfo,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: BrutalistColors.lightSurface,
              shape: BoxShape.circle,
              border: Border.all(
                color: BrutalistColors.lightBorder,
                width: BrutalistTheme.borderWidthThin,
              ),
              image: profileImage != null
                  ? DecorationImage(image: profileImage, fit: BoxFit.cover)
                  : null,
            ),
            child: profileImage == null
                ? Center(
                    child: Text(
                      _otherUser?.displayNameOrEmail[0].toUpperCase() ?? '?',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildHeaderPresence() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _otherUserId == null
          ? null
          : _firestore.collection('users').doc(_otherUserId).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final isOnline = data?['isOnline'] == true;
        final lastSeen = ChatMessageUtils.timestampToDateTime(
          data?['lastSeen'],
        );
        final label = isOnline
            ? 'Active now'
            : lastSeen == null
            ? 'Offline'
            : 'Last seen ${DateFormat('MMM d, HH:mm').format(lastSeen)}';

        return Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: BrutalistColors.lightTextSecondary,
            fontSize: 11,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrutalistColors.lightBackground,
      appBar: AppBar(
        title: Row(
          children: [
            _buildHeaderAvatar(),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(BrutalistTheme.radiusSM),
                onTap: _showConversationInfo,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _otherUser?.displayNameOrEmail ?? 'Loading...',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    _buildHeaderPresence(),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Search messages',
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _MessageSearchScreen(
                    chatRoomId: widget.chatRoomId,
                    currentUserId: _auth.currentUser?.uid,
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Conversation info',
            icon: const Icon(Icons.info_outline),
            onPressed: _showConversationInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chatRooms')
                  .doc(widget.chatRoomId)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .limit(100)
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
                          'No messages yet',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: BrutalistTheme.spacingSM),
                        Text(
                          'Start the conversation',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                }

                final currentUserId = _auth.currentUser?.uid;
                final messages = snapshot.data!.docs.where((message) {
                  if (currentUserId == null) return true;
                  final data = message.data() as Map<String, dynamic>;
                  return ChatMessageUtils.shouldShowMessage(
                    data,
                    currentUserId,
                  );
                }).toList();

                if (messages.isEmpty) {
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
                          'No messages yet',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: BrutalistTheme.spacingSM),
                        Text(
                          'Start the conversation',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _markMessagesAsRead(messages);
                });

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 18,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final data = message.data() as Map<String, dynamic>;
                    final isMe = _auth.currentUser?.uid == data['userId'];
                    final readBy = List<String>.from(data['readBy'] ?? []);
                    final isRead = readBy.contains(_otherUserId);

                    return _buildMessageBubble(
                      messageId: message.id,
                      data: data,
                      isMe: isMe,
                      time: (data['createdAt'] as Timestamp).toDate(),
                      status: isRead ? 'read' : (data['status'] ?? 'sent'),
                    );
                  },
                );
              },
            ),
          ),
          _buildTypingIndicator(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({
    required String messageId,
    required Map<String, dynamic> data,
    required bool isMe,
    required DateTime time,
    String? status,
  }) {
    final text = data['text'] as String?;
    final imageUrl = data['imageUrl'] as String?;
    final imageBase64 = data['imageBase64'] as String?;
    final isDeleted = ChatMessageUtils.isDeletedForEveryone(data);
    final isEdited = data['isEdited'] == true;
    final reactions = ChatMessageUtils.aggregateReactions(
      Map<String, dynamic>.from(data['reactions'] ?? {}),
    );

    ImageProvider? imageProvider;
    if (!isDeleted && imageUrl != null && imageUrl.isNotEmpty) {
      imageProvider = NetworkImage(imageUrl);
    } else if (!isDeleted && imageBase64 != null && imageBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(imageBase64);
        imageProvider = MemoryImage(bytes);
      } catch (e) {
        debugPrint('Error decoding image: $e');
      }
    }

    final bubbleColor = isMe
        ? BrutalistColors.chatOutgoing
        : BrutalistColors.chatIncoming;
    final textColor = isMe
        ? BrutalistColors.pureWhite
        : BrutalistColors.lightText;
    final metaColor = isMe
        ? BrutalistColors.pureWhite.withValues(alpha: 0.82)
        : BrutalistColors.lightTextSecondary;
    final bubbleRadius = BorderRadius.only(
      topLeft: const Radius.circular(BrutalistTheme.radiusLG),
      topRight: const Radius.circular(BrutalistTheme.radiusLG),
      bottomLeft: Radius.circular(isMe ? BrutalistTheme.radiusLG : 6),
      bottomRight: Radius.circular(isMe ? 6 : BrutalistTheme.radiusLG),
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: BrutalistTheme.spacingSM,
        left: isMe ? 56 : 0,
        right: isMe ? 0 : 56,
      ),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showMessageActions(
                messageId: messageId,
                data: data,
                isMe: isMe,
              ),
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity.abs() > 350 && !isDeleted) {
                  _startReply(messageId, data);
                }
              },
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: bubbleRadius,
                        border: isMe
                            ? null
                            : Border.all(
                                color: BrutalistColors.lightBorder,
                                width: BrutalistTheme.borderWidthThin,
                              ),
                        boxShadow: [
                          BoxShadow(
                            color: BrutalistColors.lightShadow.withValues(
                              alpha: isMe ? 0.28 : 0.2,
                            ),
                            offset: const Offset(0, 4),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          imageProvider != null ? 6 : 14,
                          imageProvider != null ? 6 : 10,
                          imageProvider != null ? 6 : 12,
                          8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_hasReplyPreview(data))
                              _ReplyPreview(
                                text:
                                    data['replyPreviewText'] as String? ??
                                    'Message',
                                imageUrl:
                                    data['replyPreviewImageUrl'] as String?,
                                isMe: isMe,
                              ),
                            if (isDeleted)
                              Text(
                                'This message was deleted',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: metaColor,
                                      fontStyle: FontStyle.italic,
                                      fontWeight: FontWeight.w500,
                                    ),
                              )
                            else ...[
                              if (imageProvider != null)
                                GestureDetector(
                                  onTap: () =>
                                      _openImagePreview(imageProvider!),
                                  child: Hero(
                                    tag: 'message-image-$messageId',
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        BrutalistTheme.radiusMD,
                                      ),
                                      child: Image(
                                        image: imageProvider,
                                        width: 220,
                                        height: 220,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                              if (text != null && text.trim().isNotEmpty) ...[
                                if (imageProvider != null)
                                  const SizedBox(
                                    height: BrutalistTheme.spacingSM,
                                  ),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: imageProvider != null ? 8 : 0,
                                  ),
                                  child: Text(
                                    text,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: textColor,
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w500,
                                          height: 1.38,
                                        ),
                                  ),
                                ),
                              ],
                            ],
                            const SizedBox(height: 4),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: imageProvider != null ? 8 : 0,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    DateFormat('HH:mm').format(time),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: metaColor,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                  if (isEdited && !isDeleted) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      'edited',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: metaColor,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ],
                                  if (isMe) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      status == 'read'
                                          ? Icons.done_all
                                          : Icons.done,
                                      size: 15,
                                      color: status == 'read'
                                          ? const Color(0xFF60A5FA)
                                          : metaColor,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (reactions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: reactions.entries.map((entry) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: BrutalistColors.chatPanel,
                              borderRadius: BorderRadius.circular(
                                BrutalistTheme.radiusPill,
                              ),
                              border: Border.all(
                                color: BrutalistColors.lightBorder,
                                width: BrutalistTheme.borderWidthThin,
                              ),
                            ),
                            child: Text(
                              '${entry.key} ${entry.value}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: BrutalistColors.lightText,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasReplyPreview(Map<String, dynamic> data) {
    return (data['replyToMessageId'] as String?)?.isNotEmpty == true;
  }

  void _openImagePreview(ImageProvider imageProvider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ImagePreviewScreen(imageProvider: imageProvider),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _chatRoomRef.snapshots(),
      builder: (context, snapshot) {
        final typing = Map<String, dynamic>.from(
          snapshot.data?.data()?['typing'] ?? {},
        );
        final otherUserTypingAt = _otherUserId == null
            ? null
            : typing[_otherUserId];
        final isTyping = ChatMessageUtils.isTypingRecently(otherUserTypingAt);

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: isTyping
              ? Container(
                  key: const ValueKey('typing'),
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                  child: Text(
                    '${_otherUser?.displayNameOrEmail ?? 'User'} is typing...',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: BrutalistColors.lightTextSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('not-typing')),
        );
      },
    );
  }

  Widget _buildMessageInput() {
    final isUploadingImage = _imageUploadProgress != null;
    final canSubmit = _hasComposerText && !_isSendingText && !isUploadingImage;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: BrutalistColors.chatComposer,
        border: Border(
          top: BorderSide(
            color: BrutalistColors.lightBorder,
            width: BrutalistTheme.borderWidthThin,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: BrutalistColors.lightShadow.withValues(alpha: 0.28),
            offset: const Offset(0, -4),
            blurRadius: 14,
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_imageUploadProgress != null) _buildUploadProgress(),
            if (_replyDraft != null || _editingMessageId != null)
              _buildComposerContext(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _ComposerIconButton(
                  icon: Icons.image_outlined,
                  tooltip: 'Attach image',
                  onPressed: isUploadingImage ? null : _showAttachmentSheet,
                ),
                const SizedBox(width: BrutalistTheme.spacingSM),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _messageFocusNode,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: BrutalistColors.lightText,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: _editingMessageId == null
                          ? 'Message'
                          : 'Edit message',
                      filled: true,
                      fillColor: BrutalistColors.cream,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: _composerInputBorder(BrutalistColors.lightBorder),
                      enabledBorder: _composerInputBorder(
                        BrutalistColors.lightBorder,
                      ),
                      focusedBorder: _composerInputBorder(
                        BrutalistColors.primaryAccent,
                        width: BrutalistTheme.borderWidthThick,
                      ),
                    ),
                    maxLines: null,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: BrutalistTheme.spacingSM),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: canSubmit
                          ? BrutalistColors.primaryAccent
                          : BrutalistColors.concrete400,
                      borderRadius: BorderRadius.circular(
                        BrutalistTheme.radiusPill,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (canSubmit
                                      ? BrutalistColors.primaryAccent
                                      : BrutalistColors.concrete400)
                                  .withValues(alpha: 0.22),
                          offset: const Offset(0, 4),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: IconButton(
                      tooltip: _editingMessageId == null
                          ? 'Send message'
                          : 'Save edit',
                      padding: EdgeInsets.zero,
                      icon: _isSendingText
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: BrutalistColors.pureWhite,
                              ),
                            )
                          : Icon(
                              _editingMessageId == null
                                  ? Icons.send
                                  : Icons.check,
                              color: canSubmit
                                  ? BrutalistColors.pureWhite
                                  : BrutalistColors.pureWhite.withValues(
                                      alpha: 0.72,
                                    ),
                            ),
                      onPressed: canSubmit ? _sendMessage : null,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentSheet() {
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
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: BrutalistColors.lightBorder,
                  borderRadius: BorderRadius.circular(
                    BrutalistTheme.radiusPill,
                  ),
                ),
              ),
              const SizedBox(height: BrutalistTheme.spacingMD),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                subtitle: const Text('Send an existing photo'),
                onTap: () {
                  Navigator.pop(context);
                  _sendImage(ImageSource.gallery);
                },
              ),
              Divider(
                thickness: BrutalistTheme.borderWidthThin,
                color: BrutalistColors.lightBorder,
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take photo'),
                subtitle: const Text('Capture and send now'),
                onTap: () {
                  Navigator.pop(context);
                  _sendImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposerContext() {
    final isEditing = _editingMessageId != null;
    final title = isEditing ? 'Editing message' : 'Replying';
    final body = isEditing
        ? _messageController.text
        : _replyDraft?.previewText ?? 'Message';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: BrutalistColors.cream,
        borderRadius: BorderRadius.circular(BrutalistTheme.radiusMD),
        border: Border.all(
          color: BrutalistColors.lightBorder,
          width: BrutalistTheme.borderWidthThin,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 34,
            decoration: BoxDecoration(
              color: BrutalistColors.primaryAccent,
              borderRadius: BorderRadius.circular(BrutalistTheme.radiusPill),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: BrutalistColors.primaryAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: BrutalistColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cancel',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 18),
            onPressed: _cancelComposerMode,
          ),
        ],
      ),
    );
  }

  Widget _buildUploadProgress() {
    final progress = _imageUploadProgress ?? 0;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BrutalistColors.cream,
        borderRadius: BorderRadius.circular(BrutalistTheme.radiusMD),
        border: Border.all(
          color: BrutalistColors.lightBorder,
          width: BrutalistTheme.borderWidthThin,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_upload_outlined, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              backgroundColor: BrutalistColors.lightBorder,
              color: BrutalistColors.primaryAccent,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${(progress * 100).clamp(0, 100).round()}%',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _composerInputBorder(Color color, {double? width}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(BrutalistTheme.radiusLG),
      borderSide: BorderSide(
        color: color,
        width: width ?? BrutalistTheme.borderWidthThin,
      ),
    );
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _typingExpiryTimer?.cancel();
    _clearTyping();
    _messageFocusNode.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _ComposerIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _ComposerIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: onPressed == null
              ? BrutalistColors.beige
              : BrutalistColors.cream,
          borderRadius: BorderRadius.circular(BrutalistTheme.radiusPill),
          border: Border.all(
            color: BrutalistColors.lightBorder,
            width: BrutalistTheme.borderWidthThin,
          ),
        ),
        child: IconButton(
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          icon: Icon(
            icon,
            color: onPressed == null
                ? BrutalistColors.lightTextSecondary
                : BrutalistColors.lightText,
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _ReplyDraft {
  final String messageId;
  final String previewText;
  final String? previewImageUrl;
  final String? previewSenderId;

  const _ReplyDraft({
    required this.messageId,
    required this.previewText,
    this.previewImageUrl,
    this.previewSenderId,
  });

  factory _ReplyDraft.fromMessage(String messageId, Map<String, dynamic> data) {
    final fields = ChatMessageUtils.buildReplyFields(
      messageId: messageId,
      data: data,
    );
    return _ReplyDraft(
      messageId: fields['replyToMessageId'] as String,
      previewText: fields['replyPreviewText'] as String,
      previewImageUrl: fields['replyPreviewImageUrl'] as String?,
      previewSenderId: fields['replyPreviewSenderId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'replyToMessageId': messageId,
      'replyPreviewText': previewText,
      'replyPreviewImageUrl': previewImageUrl,
      'replyPreviewSenderId': previewSenderId,
    };
  }
}

class _ReplyPreview extends StatelessWidget {
  final String text;
  final String? imageUrl;
  final bool isMe;

  const _ReplyPreview({
    required this.text,
    required this.imageUrl,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = isMe
        ? BrutalistColors.pureWhite
        : BrutalistColors.lightText;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMe
            ? BrutalistColors.pureWhite.withValues(alpha: 0.14)
            : BrutalistColors.cream,
        borderRadius: BorderRadius.circular(BrutalistTheme.radiusMD),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 32,
            decoration: BoxDecoration(
              color: isMe
                  ? BrutalistColors.pureWhite.withValues(alpha: 0.75)
                  : BrutalistColors.primaryAccent,
              borderRadius: BorderRadius.circular(BrutalistTheme.radiusPill),
            ),
          ),
          const SizedBox(width: 8),
          if (imageUrl != null && imageUrl!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(BrutalistTheme.radiusSM),
              child: Image.network(
                imageUrl!,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: foreground.withValues(alpha: 0.82),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePreviewScreen extends StatelessWidget {
  final ImageProvider imageProvider;

  const _ImagePreviewScreen({required this.imageProvider});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrutalistColors.concrete900,
      appBar: AppBar(
        backgroundColor: BrutalistColors.concrete900,
        foregroundColor: BrutalistColors.pureWhite,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Image(image: imageProvider, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class _SharedMediaScreen extends StatelessWidget {
  final String chatRoomId;
  final String? currentUserId;

  const _SharedMediaScreen({
    required this.chatRoomId,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrutalistColors.lightBackground,
      appBar: AppBar(title: const Text('Shared media')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('chatRooms')
            .doc(chatRoomId)
            .collection('messages')
            .orderBy('createdAt', descending: true)
            .limit(300)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final media =
              snapshot.data?.docs.where((doc) {
                final data = doc.data();
                if (currentUserId != null &&
                    !ChatMessageUtils.shouldShowMessage(data, currentUserId!)) {
                  return false;
                }
                if (ChatMessageUtils.isDeletedForEveryone(data)) return false;
                return (data['imageUrl'] as String?)?.isNotEmpty == true ||
                    (data['imageBase64'] as String?)?.isNotEmpty == true;
              }).toList() ??
              [];

          if (media.isEmpty) {
            return Center(
              child: Text(
                'No shared media',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(BrutalistTheme.spacingMD),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: media.length,
            itemBuilder: (context, index) {
              final data = media[index].data();
              final imageProvider = _mediaImageProvider(data);
              if (imageProvider == null) return const SizedBox.shrink();

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          _ImagePreviewScreen(imageProvider: imageProvider),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(BrutalistTheme.radiusMD),
                  child: Image(image: imageProvider, fit: BoxFit.cover),
                ),
              );
            },
          );
        },
      ),
    );
  }

  ImageProvider? _mediaImageProvider(Map<String, dynamic> data) {
    final imageUrl = data['imageUrl'] as String?;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return NetworkImage(imageUrl);
    }

    final imageBase64 = data['imageBase64'] as String?;
    if (imageBase64 == null || imageBase64.isEmpty) return null;

    try {
      return MemoryImage(base64Decode(imageBase64));
    } catch (_) {
      return null;
    }
  }
}

class _MessageSearchScreen extends StatefulWidget {
  final String chatRoomId;
  final String? currentUserId;

  const _MessageSearchScreen({
    required this.chatRoomId,
    required this.currentUserId,
  });

  @override
  State<_MessageSearchScreen> createState() => _MessageSearchScreenState();
}

class _MessageSearchScreenState extends State<_MessageSearchScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrutalistColors.lightBackground,
      appBar: AppBar(title: const Text('Search messages')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(BrutalistTheme.spacingMD),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search message text',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() => _query = value.trim().toLowerCase());
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('chatRooms')
                  .doc(widget.chatRoomId)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .limit(500)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final results =
                    snapshot.data?.docs.where((doc) {
                      final data = doc.data();
                      if (widget.currentUserId != null &&
                          !ChatMessageUtils.shouldShowMessage(
                            data,
                            widget.currentUserId!,
                          )) {
                        return false;
                      }
                      if (ChatMessageUtils.isDeletedForEveryone(data)) {
                        return false;
                      }
                      final text = (data['text'] as String?)?.toLowerCase();
                      return _query.isNotEmpty &&
                          text?.contains(_query) == true;
                    }).toList() ??
                    [];

                if (_query.isEmpty) {
                  return Center(
                    child: Text(
                      'Type to search',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  );
                }

                if (results.isEmpty) {
                  return Center(
                    child: Text(
                      'No results',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(BrutalistTheme.spacingMD),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final data = results[index].data();
                    final createdAt = ChatMessageUtils.timestampToDateTime(
                      data['createdAt'],
                    );
                    return ListTile(
                      title: Text(
                        data['text'] as String? ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: createdAt == null
                          ? null
                          : Text(DateFormat('MMM d, HH:mm').format(createdAt)),
                      onTap: () => Navigator.pop(context),
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
