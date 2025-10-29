import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'package:intl/intl.dart';

class OrderHistoryWidget extends StatelessWidget {
  final String? role; // 'user' or 'driver' or null (auto)
  const OrderHistoryWidget({super.key, this.role});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Silakan login untuk melihat riwayat'));
    }

    // decide which field to query
    final isDriver = role == 'driver';
    final field = isDriver ? 'driver_id' : 'user_id';

    final stream = FirebaseFirestore.instance
        .collection('order_history')
        .where(field, isEqualTo: uid)
        .orderBy('completed_at', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(child: Text('Error: ${snapshot.error}'));
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('Belum ada riwayat'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, idx) {
            final d = docs[idx].data();
            final completed =
                d['completed_at'] as Timestamp? ??
                d['archived_at'] as Timestamp?;
            final time = completed != null
                ? DateFormat.yMMMd().add_Hm().format(completed.toDate())
                : '-';
            final address = d['address'] ?? '-';
            final price = d['price'] != null ? (d['price']).toString() : '-';
            final weight = d['weight'] != null ? (d['weight']).toString() : '-';

            return Card(
              child: ListTile(
                title: Text('Order ${docs[idx].id}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Text('Alamat: $address'),
                    Text('Berat: $weight kg • Harga: $price'),
                    Text('Waktu: $time'),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // show details dialog
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Detail Riwayat'),
                      content: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Order ID: ${docs[idx].id}'),
                            const SizedBox(height: 8),
                            Text('Alamat: $address'),
                            Text('Berat: $weight kg'),
                            Text('Harga: $price'),
                            const SizedBox(height: 8),
                            Text('Detail lengkap:'),
                            Text(d.toString()),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Tutup'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
