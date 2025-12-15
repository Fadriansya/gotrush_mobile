// chat_message_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String orderId;
  final String senderId;
  final String senderRole; // 'user' | 'driver'
  final String message;

  final Timestamp createdAt;
  final Timestamp? readAt; // null = belum dibaca

  final String type; // 'text' | 'image' | 'system'

  ChatMessage({
    required this.id,
    required this.orderId,
    required this.senderId,
    required this.senderRole,
    required this.message,
    required this.createdAt,
    this.readAt,
    this.type = 'text',
  });

  factory ChatMessage.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      orderId: d['order_id'],
      senderId: d['sender_id'],
      senderRole: d['sender_role'],
      message: d['message'],
      createdAt: d['created_at'],
      readAt: d['read_at'],
      type: d['type'] ?? 'text',
    );
  }

  Map<String, dynamic> toMap() => {
    'order_id': orderId,
    'sender_id': senderId,
    'sender_role': senderRole,
    'message': message,
    'created_at': createdAt,
    'read_at': readAt,
    'type': type,
  };
}
