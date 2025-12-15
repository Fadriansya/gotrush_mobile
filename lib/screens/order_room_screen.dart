// order_room_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'chat_screen.dart';
import 'driver/driver_map_tracking_screen.dart';

class OrderRoomScreen extends StatelessWidget {
  final String orderId;
  final String role; // 'user' atau 'driver'

  const OrderRoomScreen({super.key, required this.orderId, required this.role});

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
            .doc(orderId)
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
          final distance = ((data['distance'] ?? 0) as num).toDouble();
          final price = ((data['price'] ?? 0) as num).toDouble();
          final pickupTs = data['pickup_date'] as Timestamp?;
          final driverId = (data['driver_id'] ?? '') as String;
          final userId = (data['user_id'] ?? '') as String;

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
                  title: role == 'driver' ? 'Data Pengguna' : 'Data Driver',
                ),
                if (role == 'driver') ...[
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
                          if (role == 'user') {
                            otherName = driverId.isEmpty ? 'Driver' : driverId;
                          } else {
                            otherName = name.isEmpty ? 'User' : name;
                          }
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                orderId: orderId,
                                otherUserName: otherName,
                                currentUserRole: role,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat),
                        label: const Text('Chat'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (role == 'driver' && data['location'] != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final loc = data['location'] as GeoPoint;
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => DriverMapTrackingScreen(
                                  orderId: orderId,
                                  userLocation: loc,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.map),
                          label: const Text('Lihat Rute'),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
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
