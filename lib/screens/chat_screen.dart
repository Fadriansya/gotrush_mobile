// chat_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../models/chat_message_model.dart';

class ChatScreen extends StatefulWidget {
  final String orderId;
  final String otherUserName;
  final String currentUserRole; // 'user' | 'driver'

  const ChatScreen({
    super.key,
    required this.orderId,
    required this.otherUserName,
    required this.currentUserRole,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markChatAsRead();
    });
  }

  void _markChatAsRead() async {
    await _chatService.markChatAsRead(
      orderId: widget.orderId,
      readerRole: widget.currentUserRole,
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    _messageController.clear();

    await _chatService.sendMessage(
      orderId: widget.orderId,
      senderId: user.uid,
      senderRole: widget.currentUserRole,
      message: text,
    );

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final metaStream = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .collection('chat_meta')
        .doc('meta')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Chat dengan ${widget.otherUserName}',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green[700],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: metaStream,
        builder: (context, metaSnapshot) {
          final Map<String, dynamic>? meta =
              metaSnapshot.data?.data() as Map<String, dynamic>?;

          Timestamp? lastReadOpponent;

          if (widget.currentUserRole == 'user') {
            lastReadOpponent = meta?['last_read_driver_at'] as Timestamp?;
          } else {
            lastReadOpponent = meta?['last_read_user_at'] as Timestamp?;
          }

          return Column(
            children: [
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: _chatService.getMessages(widget.orderId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final messages = snapshot.data!;

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final bool isMe =
                            msg.senderRole == widget.currentUserRole;

                        final isRead =
                            lastReadOpponent != null &&
                            msg.createdAt.toDate().isBefore(
                              lastReadOpponent.toDate(),
                            );

                        return _messageBubble(msg, isMe, isRead);
                      },
                    );
                  },
                ),
              ),
              _buildInput(),
            ],
          );
        },
      ),
    );
  }

  Widget _messageBubble(ChatMessage msg, bool isMe, bool isRead) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? Colors.green[700] : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              msg.message,
              style: TextStyle(color: isMe ? Colors.white : Colors.black),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(msg.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: isMe ? Colors.white70 : Colors.black54,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isRead ? Icons.done_all : Icons.check,
                    size: 14,
                    color: isRead ? Colors.lightBlueAccent : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              onSubmitted: (_) => _sendMessage(),
              decoration: const InputDecoration(
                hintText: 'Ketik pesan...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage),
        ],
      ),
    );
  }

  String _formatTime(Timestamp ts) {
    final d = ts.toDate();
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
