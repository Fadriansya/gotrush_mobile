// order_history_widget.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'order_detail_screen.dart';

class OrderHistoryWidget extends StatelessWidget {
  final String currentUserId;
  final String role; // 'user' | 'driver'

  const OrderHistoryWidget({
    super.key,
    required this.currentUserId,
    required this.role,
  });

  // ================= UTIL =================

  Color _statusColor(String status) {
    switch (status) {
      case 'waiting':
        return Colors.amber;
      case 'accepted':
        return Colors.orange;
      case 'on_the_way':
        return Colors.blue;
      case 'arrived':
        return Colors.purple;
      case 'arrived_weight_confirmed':
        return Colors.teal;
      case 'pickup_confirmed_by_driver':
        return Colors.yellow[700] ?? Colors.yellow;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'waiting':
        return Icons.hourglass_bottom;
      case 'accepted':
        return Icons.directions_run;
      case 'on_the_way':
        return Icons.local_shipping;
      case 'arrived':
        return Icons.location_on;
      case 'arrived_weight_confirmed':
        return Icons.balance;
      case 'pickup_confirmed_by_driver':
        return Icons.assignment_turned_in;
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
    }
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final ordersStream = FirebaseFirestore.instance
        .collection('order_history')
        .where(
          role == 'user' ? 'user_id' : 'driver_id',
          isEqualTo: currentUserId,
        )
        .orderBy('created_at', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: ordersStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('Belum ada riwayat pesanan'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final orderId = doc.id;

            final address = data['address'] ?? '-';
            final status = data['status'] ?? '-';
            final createdAt = data['created_at'] as Timestamp?;

            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .doc(orderId)
                  .collection('chat_meta')
                  .doc('meta')
                  .snapshots(),
              builder: (context, chatSnap) {
                int unread = 0;

                if (chatSnap.hasData && chatSnap.data!.exists) {
                  final meta = chatSnap.data!.data() as Map<String, dynamic>;
                  unread = role == 'user'
                      ? (meta['unread_user'] ?? 0)
                      : (meta['unread_driver'] ?? 0);
                }

                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              OrderDetailScreen(order: data, orderId: orderId),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          // ========== CHAT ICON + BADGE ==========
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.green[700],
                                child: const Icon(
                                  Icons.chat,
                                  color: Colors.white,
                                ),
                              ),
                              if (unread > 0)
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      unread.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
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
                                  _formatDate(createdAt),
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
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => _deleteOrder(context, orderId),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
