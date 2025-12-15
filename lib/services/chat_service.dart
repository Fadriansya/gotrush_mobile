// chat_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ==============================
  /// SEND MESSAGE
  /// ==============================
  Future<void> sendMessage({
    required String orderId,
    required String senderId,
    required String senderRole, // 'user' | 'driver'
    required String message,
  }) async {
    final orderRef = _firestore.collection('orders').doc(orderId);
    final messageRef = orderRef.collection('messages').doc();

    final now = Timestamp.now();

    final chatMessage = ChatMessage(
      id: messageRef.id,
      orderId: orderId,
      senderId: senderId,
      senderRole: senderRole,
      message: message,
      createdAt: now,
      readAt: null,
    );

    await _firestore.runTransaction((tx) async {
      /// 1️⃣ simpan pesan
      tx.set(messageRef, chatMessage.toMap());

      /// 2️⃣ update last_message (UNTUK HISTORI)
      tx.set(orderRef, {
        'last_message': {
          'text': message,
          'sender_role': senderRole,
          'created_at': now,
          'type': 'text',
        },
      }, SetOptions(merge: true));

      /// 3️⃣ update unread counter
      final metaRef = orderRef.collection('chat_meta').doc('meta');

      if (senderRole == 'user') {
        tx.set(metaRef, {
          'unread_driver': FieldValue.increment(1),
        }, SetOptions(merge: true));
      } else {
        tx.set(metaRef, {
          'unread_user': FieldValue.increment(1),
        }, SetOptions(merge: true));
      }
    });
  }

  /// ==============================
  /// GET MESSAGES STREAM
  /// ==============================
  Stream<List<ChatMessage>> getMessages(String orderId) {
    return _firestore
        .collection('orders')
        .doc(orderId)
        .collection('messages')
        .orderBy('created_at', descending: false) // ✅ FIX
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((d) => ChatMessage.fromDoc(d)).toList(),
        );
  }

  /// ==============================
  /// MARK CHAT AS READ (✓✓)
  /// ==============================
  Future<void> markChatAsRead({
    required String orderId,
    required String readerRole, // 'user' | 'driver'
  }) async {
    final metaRef = _firestore
        .collection('orders')
        .doc(orderId)
        .collection('chat_meta')
        .doc('meta');

    final now = Timestamp.now();

    if (readerRole == 'user') {
      await metaRef.set({
        'last_read_user_at': now,
        'unread_user': 0,
      }, SetOptions(merge: true));
    } else {
      await metaRef.set({
        'last_read_driver_at': now,
        'unread_driver': 0,
      }, SetOptions(merge: true));
    }
  }
}
