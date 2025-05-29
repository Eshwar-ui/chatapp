import 'dart:io';

import 'package:chatapp/screens/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../services/notification_service.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

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
  String? _lastMessageId;

  @override
  void initState() {
    super.initState();
    _setupMessageListener();
    _updateUserToken();
  }

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
        .snapshots()
        .listen((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            final latestMessage = snapshot.docs.first;
            final currentUser = _auth.currentUser;

            // Show notification if the message is new and not from current user
            if (_lastMessageId != latestMessage.id &&
                latestMessage.data()['userId'] != currentUser?.uid) {
              _notificationService.showNotification(
                title:
                    '${latestMessage.data()['userEmail']?.toString().split('@')[0] ?? 'Someone'} sent a message',
                body: latestMessage.data()['text'],
              );
            }
            _lastMessageId = latestMessage.id;
          }
        });
  }

  void _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    final user = _auth.currentUser;
    if (user == null) return;

    _messageController.clear();

    // Add message to Firestore
    await _firestore.collection('messages').add({
      'text': messageText,
      'createdAt': Timestamp.now(),
      'userId': user.uid,
      'userEmail': user.email,
    });

    // Get all user tokens except current user
    final tokenSnapshot = await _firestore
        .collection('user_tokens')
        .where(FieldPath.documentId, isNotEqualTo: user.uid)
        .get();

    // Send notifications to all other users
    for (var doc in tokenSnapshot.docs) {
      await _notificationService.sendNotification(
        token: doc.data()['token'],
        title: '${user.email?.split('@')[0] ?? 'Someone'} sent a message',
        body: messageText,
      );
    }
  }

  // final ImagePicker _picker = ImagePicker();

  void _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _getImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.of(context).pop();
                  _getImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _getImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70);

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('messages').add({
        'text': '', // if needed
        'image': base64Image,
        'createdAt': Timestamp.now(),
        'userId': user.uid,
        'userEmail': user.email,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              FirebaseAuth.instance.signOut();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (ctx) => const AuthScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: _firestore
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (ctx, chatSnapshot) {
                if (chatSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!chatSnapshot.hasData || chatSnapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No messages yet!'));
                }

                final chatDocs = chatSnapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  itemCount: chatDocs.length,
                  itemBuilder: (ctx, index) {
                    final chatDoc = chatDocs[index].data();
                    final currentUser = FirebaseAuth.instance.currentUser;
                    final isMe = currentUser?.uid == chatDoc['userId'];

                    return MessageBubble(
                      message: chatDoc['text'] ?? '',
                      imageBase64: chatDoc['image'],
                      isMe: isMe,
                      time: (chatDoc['createdAt'] as Timestamp).toDate(),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image),
                  onPressed: () {
                    _pickImage();
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      labelText: 'Send a message...',
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final String? imageBase64;
  // final String userEmail;
  final DateTime time;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    // required this.userEmail,
    required this.time,
    this.imageBase64,
  });

  Future<void> _requestPermission() async {
    if (await Permission.storage.isGranted ||
        await Permission.photos.isGranted ||
        await Permission.mediaLibrary.isGranted ||
        await Permission.manageExternalStorage.isGranted) {
      return;
    }

    if (await Permission.storage.request().isGranted ||
        await Permission.photos.request().isGranted ||
        await Permission.mediaLibrary.request().isGranted ||
        await Permission.manageExternalStorage.request().isGranted) {
      return;
    }

    throw Exception('Storage permission not granted');
  }

  @override
  Widget build(BuildContext context) {
    void _downloadImage(String base64Image) async {
      try {
        await _requestPermission();

        final bytes = base64Decode(base64Image);
        final result = await ImageGallerySaverPlus.saveImage(
          Uint8List.fromList(bytes),
          quality: 100,
          name: "chat_image_${DateTime.now().millisecondsSinceEpoch}",
        );

        if (result['isSuccess']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image saved to gallery')),
          );
        } else {
          throw Exception('Failed to save image');
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }

    Uint8List? imageBytes = imageBase64 != null
        ? base64Decode(imageBase64!)
        : null;
    bool isSingleEmoji(String input) {
      final emojiRegex = RegExp(
        r'^(?:[\u2190-\u21FF\u2300-\u27BF\u2B00-\u2BFF\u1F000-\u1F9FF\u1FA70-\u1FAFF\u2600-\u26FF\u2700-\u27BF]|[\uD83C-\uDBFF\uDC00-\uDFFF])+$',
      );
      return emojiRegex.hasMatch(input.trim()) &&
          input.trim().runes.length == 1;
    }

    Future<void> shareLocalImage(String assetPath, String fileName) async {
      try {
        // Load image bytes from assets
        final byteData = await rootBundle.load(assetPath);

        // Save to temp directory
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(byteData.buffer.asUint8List());

        // Share the image
        await Share.shareXFiles([XFile(file.path)], text: 'Check this out!');
      } catch (e) {
        print('Error sharing image: $e');
      }
    }

    final isEmoji = isSingleEmoji(message.trim());
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isMe
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.primary.withOpacity(0.5),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: Radius.circular(isMe ? 12 : 0),
              bottomRight: Radius.circular(isMe ? 0 : 12),
            ),
          ),
          // width: MediaQuery
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              // Text(
              //   userEmail,
              //   style: TextStyle(
              //     fontWeight: FontWeight.bold,
              //     color: isMe
              //         ? Colors.white
              //         : Theme.of(context).textTheme.titleMedium?.color,
              //   ),
              // ),
              if (imageBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      Image.memory(
                        imageBytes,
                        width: MediaQuery.of(context).size.width * 0.5,
                        height: MediaQuery.of(context).size.height * 0.3,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          icon: const Icon(
                            Icons.file_download_outlined,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            _downloadImage(imageBase64!);
                          },
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        child: IconButton(
                          icon: const Icon(
                            Icons.share_outlined,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            shareLocalImage(
                              'assets/images/sample.png',
                              'shared_image.png',
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              if (message.isNotEmpty)
                Container(
                  // width: MediaQuery.of(context).size.width * 0.3,
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  child: Text(
                    maxLines: 50,
                    overflow: TextOverflow.ellipsis,
                    message,
                    style: TextStyle(
                      fontSize: isEmoji ? 60 : 16,
                      color: isMe
                          ? Colors.white
                          : Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    textAlign: isMe ? TextAlign.end : TextAlign.start,
                  ),
                ),
              Text(
                DateFormat.jm().format(time),
                style: TextStyle(
                  color: isMe
                      ? Colors.white70
                      : Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
