import 'package:flutter/material.dart';

import '../../screens/individual_chat_screen.dart';

class AppNavigator {
  static final navigatorKey = GlobalKey<NavigatorState>();
  static String? _pendingChatRoomId;

  static void openChatRoom(String chatRoomId) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      _pendingChatRoomId = chatRoomId;
      return;
    }

    _pendingChatRoomId = null;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => IndividualChatScreen(chatRoomId: chatRoomId),
      ),
    );
  }

  static void flushPendingNavigation() {
    final chatRoomId = _pendingChatRoomId;
    if (chatRoomId == null) return;
    openChatRoom(chatRoomId);
  }
}
