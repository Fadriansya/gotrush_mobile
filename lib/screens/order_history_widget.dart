import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class OrderHistoryWidget extends StatelessWidget {
  final String currentUserId;
  final String role;
  const OrderHistoryWidget({
    Key? key,
    required this.currentUserId,
    required this.role,
  }) : super(key: key);

  // ======== Fungsi bantu warna & ikon status ========
  Color _getStatusColor(String status) {
    switch (status) {
      case 'waiting':
        return Colors.amber;
      case 'accepted':
        return Colors.orange;
      case 'on_the_way':
        return Colors.blueAccent;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'waiting':
        return Icons.hourglass_bottom;
      case 'accepted':
        return Icons.directions_run;
      case 'on_the_way':
        return Icons.local_shipping;
      case 'completed':
        return Icons.check_circle;
      default:
        return Icons.info_outline;
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    final date = timestamp.toDate();
    return DateFormat('d MMM yyyy, HH:mm').format(date);
  }

  // ======== Fungsi hapus satu pesanan ========
  Future<void> _deleteOrder(BuildContext context, String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Riwayat"),
        content: const Text("Apakah kamu yakin ingin menghapus pesanan ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Hapus"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('order_history')
            .doc(orderId)
            .delete();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Pesanan berhasil dihapus")),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal menghapus: $e")));
      }
    }
  }

  // ======== Fungsi hapus semua riwayat ========
  Future<void> _deleteAllOrders(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Semua Riwayat"),
        content: const Text(
          "Tindakan ini akan menghapus semua riwayat pesananmu secara permanen. "
          "Apakah kamu yakin ingin melanjutkan?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Hapus Semua"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        final query = await FirebaseFirestore.instance
            .collection('order_history')
            .where(
              role == 'user' ? 'user_id' : 'driver_id',
              isEqualTo: currentUserId,
            )
            .get();

        for (var doc in query.docs) {
          batch.delete(doc.reference);
        }

        await batch.commit();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Semua riwayat berhasil dihapus")),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal menghapus semua riwayat: $e")),
        );
      }
    }
  }

  // ======== Tampilan utama ========
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Belum ada riwayat pemesanan.'));
        }

        final orders = snapshot.data!.docs;

        return Column(
          children: [
            // ==== Tombol Hapus Semua ====
            Padding(
              padding: const EdgeInsets.only(right: 12, top: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.delete_sweep),
                  label: const Text("Hapus Semua"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    textStyle: const TextStyle(fontSize: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _deleteAllOrders(context),
                ),
              ),
            ),

            // ==== Daftar Riwayat ====
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final doc = orders[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final orderId = doc.id;
                  final address = data['address'] ?? '-';
                  final weight = (data['weight'] ?? 0).toDouble();
                  final distance = (data['distance'] ?? 0).toDouble();
                  final price = (data['price'] ?? 0).toDouble();
                  final status = data['status'] ?? '-';
                  final createdAt = data['created_at'] as Timestamp?;

                  return Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: Colors.green.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  address,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => _deleteOrder(context, orderId),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Berat: ${weight.toStringAsFixed(1)} kg   |   Jarak: ${distance.toStringAsFixed(1)} km",
                            style: const TextStyle(color: Colors.black87),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Harga: Rp ${price.toStringAsFixed(0)}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    status,
                                  ).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _getStatusIcon(status),
                                      size: 16,
                                      color: _getStatusColor(status),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      status.toUpperCase(),
                                      style: TextStyle(
                                        color: _getStatusColor(status),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                _formatDate(createdAt),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
