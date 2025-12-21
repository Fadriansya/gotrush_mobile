// chat_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
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

  // Recording state (record v5)
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  Duration _recordElapsed = Duration.zero;
  Timer? _recordTimer;

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
    _recordTimer?.cancel();
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

                        return msg.type == 'audio'
                            ? _audioMessageBubble(msg, isMe, isRead)
                            : _messageBubble(msg, isMe, isRead);
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
    if (_isRecording) {
      return Container(
        color: Colors.red.withOpacity(0.08),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.mic, color: Colors.red),
            const SizedBox(width: 8),
            Text(
              _formatDuration(_recordElapsed),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Batalkan',
              icon: const Icon(Icons.close),
              onPressed: _cancelRecording,
            ),
            const SizedBox(width: 4),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: _stopAndSendRecording,
              icon: const Icon(Icons.stop),
              label: const Text('Kirim'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Rekam VN',
            icon: const Icon(Icons.mic),
            onPressed: _toggleRecording,
          ),
          const SizedBox(width: 4),
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

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopAndSendRecording();
      return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Izin mikrofon ditolak')));
      return;
    }

    final dir = await getTemporaryDirectory();
    final filePath =
        '${dir.path}/vn_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: filePath,
    );

    setState(() {
      _isRecording = true;
      _recordElapsed = Duration.zero;
    });

    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _recordElapsed = _recordElapsed + const Duration(seconds: 1);
      });
    });
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    try {
      if (await _recorder.isRecording()) {
        // Cancel discards recording file when supported
        await _recorder.cancel();
      }
    } catch (_) {}
    setState(() {
      _isRecording = false;
      _recordElapsed = Duration.zero;
    });
  }

  Future<void> _stopAndSendRecording() async {
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    setState(() {
      _isRecording = false;
    });

    if (path == null) {
      return;
    }

    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    try {
      await _chatService.sendAudioMessage(
        orderId: widget.orderId,
        senderId: user.uid,
        senderRole: widget.currentUserRole,
        localFilePath: path,
        durationMs: _recordElapsed.inMilliseconds,
      );
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal mengirim VN: $e')));
    } finally {
      setState(() {
        _recordElapsed = Duration.zero;
      });
    }
  }

  Widget _audioMessageBubble(ChatMessage msg, bool isMe, bool isRead) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: _AudioBubble(
        url: msg.message,
        isMe: isMe,
        createdAt: msg.createdAt,
        isRead: isRead,
        durationMs: msg.durationMs,
      ),
    );
  }
}

class _AudioBubble extends StatefulWidget {
  final String url;
  final bool isMe;
  final Timestamp createdAt;
  final bool isRead;
  final int? durationMs;
  const _AudioBubble({
    required this.url,
    required this.isMe,
    required this.createdAt,
    required this.isRead,
    this.durationMs,
  });

  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      setState(() {
        _playing = state == PlayerState.playing;
      });
    });
    _player.onDurationChanged.listen((d) {
      setState(() {
        _duration = d;
      });
    });
    _player.onPositionChanged.listen((p) {
      setState(() {
        _position = p;
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isMe ? Colors.green[700] : Colors.grey[200];
    final fg = widget.isMe ? Colors.white : Colors.black87;

    final total = widget.durationMs != null && widget.durationMs! > 0
        ? Duration(milliseconds: widget.durationMs!)
        : (_duration.inMilliseconds > 0 ? _duration : null);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  _playing ? Icons.pause_circle_filled : Icons.play_circle,
                  color: fg,
                ),
                onPressed: () async {
                  if (_playing) {
                    await _player.pause();
                  } else {
                    await _player.play(UrlSource(widget.url));
                  }
                },
              ),
              if (total != null) ...[
                Text(
                  '${_fmt(_position)} / ${_fmt(total)}',
                  style: TextStyle(color: fg),
                ),
              ] else ...[
                Text(
                  _playing ? 'Memutar...' : 'VN',
                  style: TextStyle(color: fg),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${widget.createdAt.toDate().hour.toString().padLeft(2, '0')}:${widget.createdAt.toDate().minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 11,
                  color: widget.isMe ? Colors.white70 : Colors.black54,
                ),
              ),
              if (widget.isMe) ...[
                const SizedBox(width: 4),
                Icon(
                  widget.isRead ? Icons.done_all : Icons.check,
                  size: 14,
                  color: widget.isRead
                      ? Colors.lightBlueAccent
                      : Colors.white70,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
