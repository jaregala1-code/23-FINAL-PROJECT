// lib/providers/chat_provider.dart

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_notification.dart';
import '../models/chat_model.dart';
import '../services/notification_service.dart';

class ChatProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _chats = 'chats';
  static const String _messages = 'messages';

  Stream<List<Chat>> getChatsStream(String uid) => _db
      .collection(_chats)
      .where('participants', arrayContains: uid)
      .where('isArchived', isEqualTo: false)
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Chat.fromFirestore).toList());

  Stream<List<ChatMessage>> getMessagesStream(String chatId) => _db
      .collection(_chats)
      .doc(chatId)
      .collection(_messages)
      .orderBy('timestamp')
      .snapshots()
      .map((s) => s.docs.map(ChatMessage.fromFirestore).toList());

  Future<String> getOrCreateChat({
    required String myUid,
    required String myName,
    required String otherUid,
    required String otherName,
    String? relatedItemId,
    String? relatedItemTitle,
  }) async {
    final chatId = Chat.generateId(myUid, otherUid);
    final ref = _db.collection(_chats).doc(chatId);

    final snap = await ref.get();
    if (!snap.exists) {
      final chat = Chat(
        id: chatId,
        participants: [myUid, otherUid],
        participantNames: {myUid: myName, otherUid: otherName},
        relatedItemId: relatedItemId,
        relatedItemTitle: relatedItemTitle,
        updatedAt: DateTime.now(),
      );
      await ref.set(chat.toFirestore());
    }
    return chatId;
  }

  Future<bool> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String text,
    ChatMessageType type = ChatMessageType.text,
    String? qrToken,
    String? qrItemTitle,
    String? recipientUid,
  }) async {
    try {
      final msgRef = _db
          .collection(_chats)
          .doc(chatId)
          .collection(_messages)
          .doc();
      final msg = ChatMessage(
        id: msgRef.id,
        senderId: senderId,
        senderName: senderName,
        text: text,
        timestamp: DateTime.now(),
        type: type,
        qrToken: qrToken,
        qrItemTitle: qrItemTitle,
      );
      await msgRef.set(msg.toFirestore());
      if (type != ChatMessageType.system) {
        await _db.collection(_chats).doc(chatId).update({
          'lastMessage': text,
          'lastSenderId': senderId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await _db.collection(_chats).doc(chatId).update({
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (recipientUid != null &&
          recipientUid.isNotEmpty &&
          type != ChatMessageType.system) {
        await NotificationService.instance.create(
          userUid: recipientUid,
          skipIfRecipientIs: senderId,
          type: AppNotificationType.message,
          title: senderName.isNotEmpty ? senderName : 'New message',
          body: type == ChatMessageType.qr
              ? '📷 Sent you a pickup QR code'
              : text,
          payload: {'chatId': chatId},
        );
      }

      return true;
    } catch (e) {
      debugPrint('[ChatProvider] sendMessage error: $e');
      return false;
    }
  }

  Future<void> archiveChat(String chatId) async {
    try {
      await _db.collection(_chats).doc(chatId).update({'isArchived': true});
    } catch (e) {
      debugPrint('[ChatProvider] archiveChat error: $e');
    }
  }
}
