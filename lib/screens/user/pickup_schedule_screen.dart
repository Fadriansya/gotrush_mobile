import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../models/order_model.dart';
import '../../payment.dart';
import '../../midtrans_payment_webview.dart';
import '../../services/notification_service.dart';
import '../../services/order_service.dart';

class PickupScheduleScreen extends StatelessWidget {
  const PickupScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final currentUserId = auth.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Jadwal Penjemputan',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.green[700],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('user_id', isEqualTo: currentUserId)
            .where(
              'status',
              whereIn: [
                'pending',
                'active',
                'awaiting_confirmation',
                'waiting_payment',
                'completed',
              ],
            )
            .orderBy('pickup_date', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Belum ada jadwal penjemputan.'));
          }

          final orders = snapshot.data!.docs
              .map((doc) => OrderModel.fromDoc(doc))
              .where(
                (order) =>
                    order.pickupDate != null &&
                    order.pickupDate!.isAfter(
                      DateTime.now().subtract(Duration(days: 1)),
                    ),
              )
              .toList();

          if (orders.isEmpty) {
            return const Center(
              child: Text('Tidak ada jadwal penjemputan mendatang.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
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
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              order.address,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Berat: ${order.weight.toStringAsFixed(1)} kg",
                        style: const TextStyle(color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Tanggal: ${order.pickupDate != null ? DateFormat('d MMM yyyy, HH:mm').format(order.pickupDate!) : 'Belum dijadwalkan'}",
                        style: const TextStyle(color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Harga: Rp ${order.price.toStringAsFixed(0)}",
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                order.status,
                              ).withAlpha(25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              order.status.toUpperCase(),
                              style: TextStyle(
                                color: _getStatusColor(order.status),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Text(
                            DateFormat('d MMM yyyy').format(order.pickupDate!),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (order.status == 'waiting_payment' &&
                          (order.paymentStatus == null ||
                              order.paymentStatus != 'success'))
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () async {
                              final price = (order.price).toInt();
                              final auth = Provider.of<AuthService>(
                                context,
                                listen: false,
                              );
                              final email =
                                  auth.currentUser?.email ?? 'user@example.com';

                              final snapUrl = await getMidtransSnapUrl(
                                orderId: order.id,
                                grossAmount: price,
                                name: order.name ?? 'User',
                                email: email,
                              );
                              if (snapUrl == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Gagal memulai pembayaran Midtrans',
                                    ),
                                  ),
                                );
                                return;
                              }

                              final result = await Navigator.of(context)
                                  .push<Map<String, dynamic>>(
                                    MaterialPageRoute(
                                      builder: (_) => MidtransPaymentWebView(
                                        snapUrl: snapUrl,
                                        orderId: order.id,
                                      ),
                                    ),
                                  );

                              if (result?['status'] == 'success') {
                                await FirebaseFirestore.instance
                                    .collection('orders')
                                    .doc(order.id)
                                    .set({
                                      'payment_status': 'success',
                                    }, SetOptions(merge: true));

                                final snap = await FirebaseFirestore.instance
                                    .collection('orders')
                                    .doc(order.id)
                                    .get();
                                final d = snap.data() as Map<String, dynamic>?;
                                final driverId =
                                    d?['driver_id'] as String? ?? '';
                                if (driverId.isNotEmpty) {
                                  await NotificationService()
                                      .notifyDriverPaymentSuccess(
                                        orderId: order.id,
                                        driverId: driverId,
                                      );
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Pembayaran berhasil'),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.payment),
                            label: const Text('Bayar'),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.amber;
      case 'active':
        return Colors.orange;
      case 'awaiting_confirmation':
        return Colors.blueAccent;
      case 'waiting_payment':
        return Colors.purple;
      case 'pickup_validation':
        return Colors.teal;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
