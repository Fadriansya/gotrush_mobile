// order_history_widget.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'order_detail_screen.dart';

class OrderHistoryWidget extends StatefulWidget {
  final String currentUserId;
  final String role; // 'user' | 'driver'

  const OrderHistoryWidget({
    super.key,
    required this.currentUserId,
    required this.role,
  });

  @override
  State<OrderHistoryWidget> createState() => _OrderHistoryWidgetState();
}

class _OrderHistoryWidgetState extends State<OrderHistoryWidget> {
  static const int _pageSize = 20;
  List<QueryDocumentSnapshot> _docs = [];
  DocumentSnapshot? _lastDoc;
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  late final ScrollController _scrollController;

  // ================= UTIL =================

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.amber;
      case 'active':
        return Colors.orange;
      case 'awaiting_confirmation':
        return Colors.purple;
      case 'waiting_payment':
        return Colors.blue;
      case 'pickup_validation':
        return Colors.teal;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_bottom;
      case 'active':
        return Icons.directions_run;
      case 'awaiting_confirmation':
        return Icons.balance;
      case 'waiting_payment':
        return Icons.payment;
      case 'pickup_validation':
        return Icons.fact_check;
      case 'completed':
        return Icons.check_circle;
      default:
        return Icons.info_outline;
    }
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '-';
    return DateFormat('d MMM yyyy • HH:mm').format(ts.toDate());
  }

  Query _buildQuery() {
    return FirebaseFirestore.instance
        .collection('order_history')
        .where(
          widget.role == 'user' ? 'user_id' : 'driver_id',
          isEqualTo: widget.currentUserId,
        )
        .where('status', isEqualTo: 'completed')
        .orderBy('completed_at', descending: true);
  }

  Future<void> _fetchInitial() async {
    setState(() {
      _initialLoading = true;
      _error = null;
    });
    try {
      final qs = await _buildQuery().limit(_pageSize).get();
      _docs = qs.docs;
      _lastDoc = _docs.isNotEmpty ? _docs.last : null;
      _hasMore = _docs.length == _pageSize;
    } catch (e) {
      _error = 'Gagal memuat riwayat: $e';
    } finally {
      if (mounted) {
        setState(() {
          _initialLoading = false;
        });
      }
    }
  }

  Future<void> _fetchMore() async {
    if (_loadingMore || !_hasMore || _lastDoc == null) return;
    setState(() => _loadingMore = true);
    try {
      final qs = await _buildQuery()
          .startAfterDocument(_lastDoc!)
          .limit(_pageSize)
          .get();
      _docs.addAll(qs.docs);
      _lastDoc = qs.docs.isNotEmpty ? qs.docs.last : _lastDoc;
      _hasMore = qs.docs.length == _pageSize;
    } catch (e) {
      _error = 'Gagal memuat tambahan riwayat: $e';
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _fetchInitial();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore) return;
    // Trigger when near bottom (within ~200px)
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _fetchMore();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // ================= DELETE =================

  Future<void> _deleteOrder(BuildContext context, String orderId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Riwayat'),
        content: const Text('Pesanan ini akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await FirebaseFirestore.instance
          .collection('order_history')
          .doc(orderId)
          .delete();
      if (mounted) {
        setState(() {
          _docs.removeWhere((d) => d.id == orderId);
        });
      }
    }
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      );
    }

    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_docs.isEmpty) {
      return const Center(child: Text('Belum ada riwayat pesanan'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      controller: _scrollController,
      itemCount: _docs.length + (_loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (_loadingMore && index == _docs.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final doc = _docs[index];
        final data = doc.data() as Map<String, dynamic>;
        final orderId = doc.id;

        final address = data['address'] ?? '-';
        final status = data['status'] ?? '-';
        final completedAt = data['completed_at'] as Timestamp?;
        final createdAt = data['created_at'] as Timestamp?;
        final displayTs = completedAt ?? createdAt;

        return Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              // Lazy unread fetch on tap (single get), then navigate
              int unread = 0;
              try {
                final metaDoc = await FirebaseFirestore.instance
                    .collection('orders')
                    .doc(orderId)
                    .collection('chat_meta')
                    .doc('meta')
                    .get();
                if (metaDoc.exists) {
                  final meta = metaDoc.data() as Map<String, dynamic>;
                  unread = widget.role == 'user'
                      ? (meta['unread_user'] ?? 0)
                      : (meta['unread_driver'] ?? 0);
                }
                if (mounted && unread > 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Pesan belum dibaca: $unread')),
                  );
                }
              } catch (_) {}
              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderDetailScreen(
                    order: data,
                    orderId: orderId,
                    unreadCount: unread,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // ========== CHAT ICON (no unread badge fallback) ==========
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.green[700],
                    child: const Icon(Icons.chat, color: Colors.white),
                  ),

                  const SizedBox(width: 12),

                  // ========== INFO ==========
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          address,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              _statusIcon(status),
                              size: 16,
                              color: _statusColor(status),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                color: _statusColor(status),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatDate(displayTs),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ========== DELETE ==========
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () => _deleteOrder(context, orderId),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
