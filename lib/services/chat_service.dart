// chat_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> sendMessage({
    required String orderId,
    required String senderId,
    required String senderRole,
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
      tx.set(messageRef, chatMessage.toMap());

      tx.set(orderRef, {
        'last_message': {
          'text': message,
          'sender_role': senderRole,
          'created_at': now,
          'type': 'text',
        },
      }, SetOptions(merge: true));

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

  Stream<QuerySnapshot> getMessages(String orderId) {
    return _firestore
        .collection('orders')
        .doc(orderId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> markAsRead(String orderId, String messageId) async {
    final messageRef = _firestore
        .collection('orders')
        .doc(orderId)
        .collection('messages')
        .doc(messageId);
    await messageRef.update({'readAt': Timestamp.now()});
  }

  Future<void> resetUnreadCounter(String orderId, String role) async {
    final metaRef = _firestore
        .collection('orders')
        .doc(orderId)
        .collection('chat_meta')
        .doc('meta');

    if (role == 'user') {
      await metaRef.set({'unread_user': 0}, SetOptions(merge: true));
    } else {
      await metaRef.set({'unread_driver': 0}, SetOptions(merge: true));
    }
  }
}
