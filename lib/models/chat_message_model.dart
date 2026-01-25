import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String orderId;
  final String senderId;
  final String senderRole;
  final String message;

  final Timestamp createdAt;
  final Timestamp? readAt;

  final String type;

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

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      orderId: map['orderId'],
      senderId: map['senderId'],
      senderRole: map['senderRole'],
      message: map['message'],
      createdAt: map['createdAt'],
      readAt: map['readAt'],
      type: map['type'] ?? 'text',
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'orderId': orderId,
    'senderId': senderId,
    'senderRole': senderRole,
    'message': message,
    'createdAt': createdAt,
    'readAt': readAt,
    'type': type,
  };
}
