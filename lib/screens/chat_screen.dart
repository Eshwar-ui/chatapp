import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:chatapp/screens/auth_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _notificationService = NotificationService();
  final _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  Color _chatBackground = Colors.white;
  String? _lastMessageId;
  bool _isLoadingMore = false;
  DocumentSnapshot? _lastDocument;

  @override
  void initState() {
    super.initState();
    _loadBackground();
    _setupMessageListener();
    _updateUserToken();
    // _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadBackground() async {
    final prefs = await SharedPreferences.getInstance();
    final bgIndex = prefs.getInt('chatBackground') ?? 0;
    final backgrounds = _getBackgroundOptions();
    setState(() => _chatBackground = backgrounds[bgIndex]);
  }

  List<Color> _getBackgroundOptions() => [
    Colors.white,
    Colors.grey[200]!,
    Colors.blue[50]!,
    Colors.green[50]!,
    Colors.pink[50]!,
  ];

  Future<void> _updateUserToken() async {
    final user = _auth.currentUser;
    if (user != null) {
      final token = await _notificationService.getToken();
      if (token != null) {
        await _firestore.collection('user_tokens').doc(user.uid).set({
          'token': token,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  void _setupMessageListener() {
    _firestore
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            _lastDocument = snapshot.docs.last;
            final latestMessage = snapshot.docs.first;
            final currentUser = _auth.currentUser;

            if (_lastMessageId != latestMessage.id &&
                latestMessage.data()['userId'] != currentUser?.uid) {
              _notificationService.showNotification(
                title:
                    '${latestMessage.data()['userEmail']?.toString().split('@')[0] ?? 'Someone'} sent a message',
                body: latestMessage.data()['text'] ?? 'Sent an attachment',
              );
              _updateMessageStatus(latestMessage.id, 'delivered');
            }
            _lastMessageId = latestMessage.id;
          }
        });
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        !_isLoadingMore &&
        _lastDocument != null) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadMoreMessages() async {
    setState(() => _isLoadingMore = true);
    final query = _firestore
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .startAfterDocument(_lastDocument!)
        .limit(100);

    final snapshot = await query.get();
    if (snapshot.docs.isNotEmpty) {
      _lastDocument = snapshot.docs.last;
    }
    setState(() => _isLoadingMore = false);
  }

  Future<void> _updateMessageStatus(String messageId, String status) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('messages').doc(messageId).update({
      'status': status,
      'readBy': FieldValue.arrayUnion([user.uid]),
    });
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    final user = _auth.currentUser;
    if (user == null) return;

    _messageController.clear();

    await _firestore.collection('messages').add({
      'text': messageText,
      'createdAt': Timestamp.now(),
      'userId': user.uid,
      'userEmail': user.email,
      'status': 'sent',
      'readBy': [user.uid],
      'isEdited': false,
      'deletedFor': [],
      'reactions': {},
    });

    _sendNotificationToRecipient(messageText, user);
  }

  Future<void> _sendNotificationToRecipient(
    String messageText,
    User sender,
  ) async {
    final tokenSnapshot = await _firestore
        .collection('user_tokens')
        .where(FieldPath.documentId, isNotEqualTo: sender.uid)
        .get();

    for (var doc in tokenSnapshot.docs) {
      await _notificationService.sendNotification(
        token: doc.data()['token'],
        title: '${sender.email?.split('@')[0] ?? 'Someone'} sent a message',
        body: messageText,
      );
    }
  }

  void _pickImage() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _getImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _getImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final user = _auth.currentUser;
        if (user == null) return;

        await _firestore.collection('messages').add({
          'image': base64Encode(bytes),
          'createdAt': Timestamp.now(),
          'userId': user.uid,
          'userEmail': user.email,
          'status': 'sent',
          'readBy': [user.uid],
          'deletedFor': [],
          'reactions': {},
        });
      }
    } catch (e) {
      _showErrorSnackbar('Failed to send image: ${e.toString()}');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (ctx) => const ChatSettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _chatBackground,
      appBar: AppBar(
        title: const Text('Chat App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _navigateToSettings,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              _auth.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (ctx) => const AuthScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .limit(100)
                  .snapshots(),
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No messages yet!'));
                }

                final messages = snapshot.data!.docs;
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: messages.length + (_isLoadingMore ? 1 : 0),
                  itemBuilder: (ctx, index) {
                    if (index >= messages.length) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final message = messages[index];
                    final data = message.data() as Map<String, dynamic>;
                    final isMe = _auth.currentUser?.uid == data['userId'];

                    // Skip messages deleted for current user
                    if ((data['deletedFor'] as List?)?.contains(
                          _auth.currentUser?.uid,
                        ) ==
                        true) {
                      return const SizedBox.shrink();
                    }

                    return MessageBubble(
                      key: ValueKey(message.id),
                      messageId: message.id,
                      text: data['text'],
                      imageBase64: data['image'],
                      gifUrl: data['gifUrl'],
                      isMe: isMe,
                      time: (data['createdAt'] as Timestamp).toDate(),
                      status: data['status'],
                      isEdited: data['isEdited'] ?? false,
                      reactions: Map<String, String>.from(
                        data['reactions'] ?? {},
                      ),
                      currentUserId: _auth.currentUser?.uid,
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.image), onPressed: _pickImage),

          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Send a message...',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage),
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final String messageId;
  final String? text;
  final String? imageBase64;
  final String? gifUrl;
  final bool isMe;
  final DateTime time;
  final String? status;
  final bool isEdited;
  final Map<String, String> reactions;
  final String? currentUserId;

  const MessageBubble({
    super.key,
    required this.messageId,
    required this.text,
    required this.imageBase64,
    required this.gifUrl,
    required this.isMe,
    required this.time,
    required this.status,
    required this.isEdited,
    required this.reactions,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: GestureDetector(
            onLongPress: () => _showMessageOptions(context),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: isMe
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.3),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(12),
                      topRight: const Radius.circular(12),
                      bottomLeft: Radius.circular(isMe ? 12 : 0),
                      bottomRight: Radius.circular(isMe ? 0 : 12),
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      if (imageBase64 != null) _buildImage(context),
                      if (gifUrl != null) _buildGif(context),
                      if (text?.isNotEmpty == true) _buildText(context),
                      _buildMessageFooter(),
                      if (reactions.isNotEmpty) _buildReactions(),
                    ],
                  ),
                ),
                if (reactions.isNotEmpty) _buildReactions(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImage(BuildContext context) {
    final bytes = base64Decode(imageBase64!);
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            width: 200,
            height: 200,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white),
                onPressed: () => _shareImage(bytes, context),
              ),
              IconButton(
                icon: const Icon(Icons.download, color: Colors.white),
                onPressed: () => _saveImageToGallery(context, bytes),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGif(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(gifUrl!, width: 200, height: 200, fit: BoxFit.cover),
    );
  }

  Widget _buildText(BuildContext context) {
    final isEmoji = _isSingleEmoji(text!);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text!,
        style: TextStyle(
          fontSize: isEmoji ? 32 : 16,
          color: isMe ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  Widget _buildMessageFooter() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          DateFormat.jm().format(time),
          style: TextStyle(
            color: isMe ? Colors.white70 : Colors.black54,
            fontSize: 10,
          ),
        ),
        if (isEdited) ...[
          const SizedBox(width: 4),
          Text(
            'edited',
            style: TextStyle(
              color: isMe ? Colors.white70 : Colors.black54,
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        if (isMe) ...[
          const SizedBox(width: 4),
          Icon(
            status == 'read' ? Icons.done_all : Icons.done,
            size: 12,
            color: status == 'read' ? Colors.blue : Colors.white70,
          ),
        ],
      ],
    );
  }

  Widget _buildReactions() {
    return Align(
      alignment: isMe ? Alignment.bottomRight : Alignment.bottomLeft,
      child: Wrap(
        spacing: 4,
        children: reactions.entries.map((entry) {
          return GestureDetector(
            onTap: () => _toggleReaction(entry.key),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(entry.value),
            ),
          );
        }).toList(),
      ),
    );
  }

  bool _isSingleEmoji(String input) {
    final emojiRegex = RegExp(
      r'^(?:[\u2190-\u21FF\u2300-\u27BF\u2B00-\u2BFF\u1F000-\u1F9FF\u1FA70-\u1FAFF\u2600-\u26FF\u2700-\u27BF]|[\uD83C-\uDBFF\uDC00-\uDFFF])+$',
    );
    return emojiRegex.hasMatch(input.trim()) && input.trim().runes.length <= 2;
  }

  Future<void> _showMessageOptions(BuildContext context) async {
    bool isCurrentUser = false;
    if (currentUserId != null) {
      final doc = await FirebaseFirestore.instance
          .collection('messages')
          .doc(messageId)
          .get();
      isCurrentUser = doc.data()?['userId'] == currentUserId;
    }

    await showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCurrentUser)
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(ctx);
                _editMessage(context);
              },
            ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Copy'),
            onTap: () {
              Clipboard.setData(ClipboardData(text: text ?? ''));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete for me'),
            onTap: () {
              Navigator.pop(ctx);
              _deleteMessage(false);
            },
          ),
          if (isCurrentUser)
            ListTile(
              leading: const Icon(Icons.delete_forever),
              title: const Text('Delete for everyone'),
              onTap: () {
                Navigator.pop(ctx);
                _deleteMessage(true);
              },
            ),
          ListTile(
            leading: const Icon(Icons.add_reaction),
            title: const Text('Add reaction'),
            onTap: () {
              Navigator.pop(ctx);
              _showReactionMenu(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _editMessage(BuildContext context) async {
    final doc = await FirebaseFirestore.instance
        .collection('messages')
        .doc(messageId)
        .get();
    final currentText = doc.data()?['text'] ?? '';

    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: TextEditingController(text: currentText),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              (ctx.widget as TextField).controller?.text ?? '',
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newText != null && newText != currentText) {
      await FirebaseFirestore.instance
          .collection('messages')
          .doc(messageId)
          .update({
            'text': newText,
            'isEdited': true,
            'editedAt': Timestamp.now(),
          });
    }
  }

  Future<void> _deleteMessage(bool forEveryone) async {
    if (forEveryone) {
      await FirebaseFirestore.instance
          .collection('messages')
          .doc(messageId)
          .delete();
    } else {
      await FirebaseFirestore.instance
          .collection('messages')
          .doc(messageId)
          .update({
            'deletedFor': FieldValue.arrayUnion([currentUserId]),
          });
    }
  }

  Future<void> _showReactionMenu(BuildContext context) async {
    final reactions = ['❤️', '😂', '😮', '😢', '👍', '👎'];
    final selectedReaction = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SizedBox(
        height: 60,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: reactions
              .map(
                (reaction) => IconButton(
                  icon: Text(reaction, style: const TextStyle(fontSize: 24)),
                  onPressed: () => Navigator.pop(ctx, reaction),
                ),
              )
              .toList(),
        ),
      ),
    );

    if (selectedReaction != null) {
      await FirebaseFirestore.instance
          .collection('messages')
          .doc(messageId)
          .update({'reactions.$currentUserId': selectedReaction});
    }
  }

  Future<void> _toggleReaction(String userId) async {
    if (userId == currentUserId) {
      await FirebaseFirestore.instance
          .collection('messages')
          .doc(messageId)
          .update({'reactions.$userId': FieldValue.delete()});
    }
  }

  Future<void> _saveImageToGallery(
    BuildContext context,
    Uint8List bytes,
  ) async {
    try {
      await Permission.storage.request();
      final result = await ImageGallerySaverPlus.saveImage(
        bytes,
        quality: 100,
        name: "chat_image_${DateTime.now().millisecondsSinceEpoch}",
      );
      if (result['isSuccess']) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Image saved to gallery')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save image: ${e.toString()}')),
      );
    }
  }

  Future<void> _shareImage(Uint8List bytes, BuildContext context) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/shared_image.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share image: ${e.toString()}')),
      );
    }
  }
}

class ChatSettingsScreen extends StatelessWidget {
  const ChatSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final backgrounds = [
      Colors.white,
      Colors.grey[200]!,
      Colors.blue[50]!,
      Colors.green[50]!,
      Colors.pink[50]!,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Chat Settings')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Chat Background',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          ...backgrounds.asMap().entries.map((entry) {
            final index = entry.key;
            final color = entry.value;
            return ListTile(
              tileColor: color,
              title: Text('Option ${index + 1}'),
              trailing: const Icon(Icons.check),
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('chatBackground', index);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ],
      ),
    );
  }
}
