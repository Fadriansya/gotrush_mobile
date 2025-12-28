// order_room_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../payment.dart';
import '../midtrans_payment_webview.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import 'chat_screen.dart';
import 'driver/driver_map_tracking_screen.dart';

class OrderRoomScreen extends StatefulWidget {
  final String orderId;
  final String role; // 'user' atau 'driver'

  const OrderRoomScreen({super.key, required this.orderId, required this.role});

  @override
  State<OrderRoomScreen> createState() => _OrderRoomScreenState();
}

class _OrderRoomScreenState extends State<OrderRoomScreen> {
  final TextEditingController _weightCtrl = TextEditingController();

  @override
  void dispose() {
    _weightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green[800],
        title: Text(
          'Order Aktif',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Order tidak ditemukan'));
          }

          final data = snapshot.data!.data()!;
          final status = (data['status'] ?? '-') as String;
          final address = (data['address'] ?? '-') as String;
          final name = (data['name'] ?? '-') as String;
          final phone = (data['phone_number'] ?? '-') as String;
          final weight = ((data['weight'] ?? 0) as num).toDouble();
          final driverWeight = ((data['driver_weight'] ?? 0) as num).toDouble();
          final weightStatus =
              (data['weight_status'] ?? '')
                  as String; // proposed | approved | disputed
          final distance = ((data['distance'] ?? 0) as num).toDouble();
          final price = ((data['price'] ?? 0) as num).toDouble();
          final pickupTs = data['pickup_date'] as Timestamp?;
          final driverId = (data['driver_id'] ?? '') as String;
          final userId = (data['user_id'] ?? '') as String;
          // Alur baru tidak memakai pickup_confirmed; gunakan status
          final paymentStatus = (data['payment_status'] ?? '') as String;

          final pickupDateStr = pickupTs != null
              ? DateFormat(
                  'd MMM yyyy, HH:mm',
                  'id_ID',
                ).format(pickupTs.toDate())
              : '-';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(title: 'Status'),
                _InfoRow(label: 'Status', value: status.toUpperCase()),
                const SizedBox(height: 12),

                _SectionHeader(
                  title: widget.role == 'driver'
                      ? 'Data Pengguna'
                      : 'Data Driver',
                ),
                if (widget.role == 'driver') ...[
                  _InfoRow(label: 'Nama', value: name),
                  _InfoRow(label: 'Telepon', value: phone),
                  _InfoRow(
                    label: 'User ID',
                    value: userId.isEmpty ? '-' : userId,
                  ),
                ] else ...[
                  _InfoRow(
                    label: 'Driver ID',
                    value: driverId.isEmpty ? '-' : driverId,
                  ),
                ],
                const SizedBox(height: 12),

                _SectionHeader(title: 'Detail Order'),
                _InfoRow(label: 'Alamat', value: address),
                _InfoRow(
                  label: 'Berat',
                  value: '${weight.toStringAsFixed(1)} kg',
                ),
                _InfoRow(
                  label: 'Jarak',
                  value: '${distance.toStringAsFixed(1)} km',
                ),
                _InfoRow(
                  label: 'Harga',
                  value: 'Rp ${price.toStringAsFixed(0)}',
                ),
                _InfoRow(label: 'Jadwal', value: pickupDateStr),
                const SizedBox(height: 20),

                _SectionHeader(title: 'Komunikasi'),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          String otherName;
                          if (widget.role == 'user') {
                            otherName = driverId.isEmpty ? 'Driver' : driverId;
                          } else {
                            otherName = name.isEmpty ? 'User' : name;
                          }
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                orderId: widget.orderId,
                                otherUserName: otherName,
                                currentUserRole: widget.role,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat),
                        label: const Text('Chat'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (data['location'] != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final loc = data['location'] as GeoPoint;
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) {
                                  if (widget.role == 'driver') {
                                    return DriverMapTrackingScreen(
                                      orderId: widget.orderId,
                                      userLocation: loc,
                                    );
                                  }
                                  return DriverMapTrackingScreen(
                                    orderId: widget.orderId,
                                    userLocation: loc,
                                    watchDriverId: driverId.isEmpty
                                        ? null
                                        : driverId,
                                  );
                                },
                              ),
                            );
                          },
                          icon: const Icon(Icons.map),
                          label: const Text('Lihat Rute'),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 20),
                _SectionHeader(title: 'Penimbangan'),
                _buildWeighingSection(
                  context: context,
                  status: status,
                  driverWeight: driverWeight,
                  weightStatus: weightStatus,
                  orderId: widget.orderId,
                  driverId: driverId,
                  userId: userId,
                  price: price,
                  paymentStatus: paymentStatus,
                  pickupConfirmed: false,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWeighingSection({
    required BuildContext context,
    required String status,
    required double driverWeight,
    required String weightStatus,
    required String orderId,
    required String driverId,
    required String userId,
    required double price,
    required String paymentStatus,
    required bool pickupConfirmed,
  }) {
    // USER UI
    if (widget.role == 'user') {
      // 1. USER: Validasi Pengambilan
      if (status == 'waiting_user_validation') {
        return Card(
          color: Colors.orange.withOpacity(0.06),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Validasi Pengambilan',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text('Apakah driver sudah mengambil sampah?'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.close),
                        label: const Text('Tidak'),
                        onPressed: () async {
                          try {
                            final auth = Provider.of<AuthService>(
                              context,
                              listen: false,
                            );
                            final user = auth.currentUser;
                            if (user == null) return;
                            await OrderService().userRespondPickupValidation(
                              orderId: orderId,
                              userId: user.uid,
                              confirmed: false,
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Sanggahan terkirim. Menunggu driver konfirmasi ulang.',
                                ),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Gagal: $e')),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Ya'),
                        onPressed: () async {
                          try {
                            final auth = Provider.of<AuthService>(
                              context,
                              listen: false,
                            );
                            final user = auth.currentUser;
                            if (user == null) return;
                            await OrderService().userRespondPickupValidation(
                              orderId: orderId,
                              userId: user.uid,
                              confirmed: true,
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Pengambilan divalidasi. Menunggu driver menyelesaikan.',
                                ),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Gagal: $e')),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }

      // 2. USER: Verifikasi berat
      if (status == 'awaiting_confirmation') {
        if (weightStatus == 'proposed') {
          return Card(
            color: Colors.teal.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Verifikasi Berat',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Berat yang diajukan driver: ${driverWeight.toStringAsFixed(2)} kg',
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.check),
                          label: const Text('Setuju'),
                          onPressed: () async {
                            try {
                              final auth = Provider.of<AuthService>(
                                context,
                                listen: false,
                              );
                              final user = auth.currentUser;
                              if (user == null) return;
                              await OrderService().confirmWeightByUser(
                                orderId: orderId,
                                userId: user.uid,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Berat disetujui. Lanjut ke pembayaran.',
                                  ),
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Gagal: $e')),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.close),
                          label: const Text('Sanggah'),
                          onPressed: () async {
                            try {
                              final auth = Provider.of<AuthService>(
                                context,
                                listen: false,
                              );
                              final user = auth.currentUser;
                              if (user == null) return;
                              await OrderService().disputeWeightByUser(
                                orderId: orderId,
                                userId: user.uid,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Sanggahan terkirim. Menunggu koreksi driver.',
                                  ),
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Gagal: $e')),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
        if (weightStatus == 'disputed') {
          return const Text(
            'Anda telah menyanggah. Menunggu koreksi dari driver...',
          );
        }
      }

      // 3. USER: Tombol Bayar
      if (status == 'waiting_payment') {
        return Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.payment),
            label: const Text('Bayar'),
            onPressed: () async {
              // Trigger payment via midtrans
              final auth = Provider.of<AuthService>(context, listen: false);
              final user = auth.currentUser;
              if (user == null) return;
              final snapUrl = await getMidtransSnapUrl(
                orderId: orderId,
                grossAmount: price.round(),
                name: user.displayName ?? 'User',
                email: user.email ?? 'user@example.com',
              );
              if (snapUrl == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Gagal memulai pembayaran')),
                );
                return;
              }
              // Open webview
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MidtransPaymentWebView(
                    snapUrl: snapUrl,
                    orderId: orderId,
                  ),
                ),
              );
            },
          ),
        );
      }

      // 4. USER: Info setelah bayar
      if ((paymentStatus == 'success' || paymentStatus == 'paid') &&
          status != 'waiting_user_validation' &&
          status != 'picked_up' &&
          status != 'completed') {
        return const Text(
          'Pembayaran berhasil. Menunggu driver mengambil sampah.',
          style: TextStyle(color: Colors.green),
        );
      }

      // 5. USER: Status Selesai
      if (status == 'completed') {
        return const Text('Order selesai. Terima kasih!');
      }

      // 6. USER: Fallback
      return const SizedBox.shrink();
    }

    // DRIVER UI
    if (widget.role == 'driver') {
      // 1. DRIVER: Tombol Selesaikan Order
      if (status == 'picked_up') {
        return Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.done_all),
            label: const Text('Selesaikan Order'),
            onPressed: () async {
              try {
                await OrderService().driverCompleteOrder(
                  orderId: orderId,
                  driverId: driverId,
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Order berhasil diselesaikan')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Gagal menyelesaikan: $e')),
                );
              }
            },
          ),
        );
      }

      // 2. DRIVER: Tombol Konfirmasi Ambil Sampah (setelah user bayar)
      if ((paymentStatus == 'success' || paymentStatus == 'paid') &&
          status != 'waiting_user_validation' &&
          status != 'picked_up' &&
          status != 'completed') {
        return Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.shopping_bag),
            label: const Text('Konfirmasi Ambil Sampah'),
            onPressed: () async {
              try {
                await OrderService().driverConfirmPickup(
                  orderId: orderId,
                  driverId: driverId,
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Konfirmasi terkirim. Menunggu validasi pengguna.',
                    ),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Gagal konfirmasi: $e')));
              }
            },
          ),
        );
      }

      // 3. DRIVER: Menunggu validasi dari user
      if (status == 'waiting_user_validation') {
        return const Text(
          'Menunggu validasi pengambilan dari pengguna...',
          style: TextStyle(color: Colors.orange),
        );
      }

      // 4. DRIVER: Form ajukan berat
      if (status == 'active' ||
          status == 'arrived' ||
          (status == 'awaiting_confirmation' && weightStatus != 'approved')) {
        if (_weightCtrl.text.isEmpty && driverWeight > 0) {
          _weightCtrl.text = driverWeight.toStringAsFixed(2);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (status == 'awaiting_confirmation' && weightStatus == 'proposed')
              const Text(
                'Menunggu persetujuan pengguna...',
                style: TextStyle(color: Colors.orange),
              ),
            if (weightStatus == 'disputed')
              const Text(
                'Pengguna menyanggah. Mohon koreksi berat.',
                style: TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _weightCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Berat hasil timbangan (kg)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.scale),
                label: const Text('Kirim Berat'),
                onPressed: () async {
                  final val = double.tryParse(
                    _weightCtrl.text.replaceAll(',', '.'),
                  );
                  if (val == null || val <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Masukkan berat valid (> 0)'),
                      ),
                    );
                    return;
                  }
                  try {
                    await OrderService().proposeWeight(
                      orderId: orderId,
                      driverId: driverId,
                      weight: val,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Berat diajukan ke pengguna'),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal mengajukan berat: $e')),
                    );
                  }
                },
              ),
            ),
          ],
        );
      }

      // 5. DRIVER: Info setelah berat disetujui / menunggu pembayaran
      if (status == 'waiting_payment' ||
          (weightStatus == 'approved' &&
              paymentStatus != 'success' &&
              paymentStatus != 'paid')) {
        return Text(
          'Berat disetujui: ${driverWeight.toStringAsFixed(2)} kg. Menunggu pembayaran dari user.',
        );
      }

      // 6. DRIVER: Status Selesai
      if (status == 'completed') {
        return const Text('Order selesai. Terima kasih!');
      }

      // 7. DRIVER: Fallback
      return const Text('Menunggu proses timbangan dimulai.');
    }

    return const SizedBox.shrink();
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}
