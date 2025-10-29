import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'package:intl/intl.dart';

class OrderHistoryWidget extends StatefulWidget {
  final String? role; // 'user' or 'driver' or null (auto)
  const OrderHistoryWidget({super.key, this.role});

  @override
  State<OrderHistoryWidget> createState() => _OrderHistoryWidgetState();
}

class _OrderHistoryWidgetState extends State<OrderHistoryWidget> {
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Silakan login untuk melihat riwayat'));
    }

    final isDriver = widget.role == 'driver';
    final field = isDriver ? 'driver_id' : 'user_id';

    final stream = FirebaseFirestore.instance
        .collection('order_history')
        .where(field, isEqualTo: uid)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
          snapshot.data!.docs,
        );
        // sort client-side by completed_at (preferred) then archived_at
        docs.sort((a, b) {
          final aData = a.data();
          final bData = b.data();
          final aTs =
              (aData['completed_at'] as Timestamp?) ??
              (aData['archived_at'] as Timestamp?);
          final bTs =
              (bData['completed_at'] as Timestamp?) ??
              (bData['archived_at'] as Timestamp?);
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return bTs.compareTo(aTs);
        });

        if (docs.isEmpty) {
          return const Center(child: Text('Belum ada riwayat'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, idx) {
            final doc = docs[idx];
            final d = doc.data();
            final completed =
                (d['completed_at'] as Timestamp?) ??
                (d['archived_at'] as Timestamp?);
            final time = completed != null
                ? DateFormat.yMMMd().add_Hm().format(completed.toDate())
                : '-';
            final address = d['address'] ?? '-';
            final price = d['price'] != null ? (d['price']).toString() : '-';
            final weight = d['weight'] != null ? (d['weight']).toString() : '-';

            // determine the other party id (if current is driver show user name, else show driver name)
            final otherId = isDriver
                ? (d['user_id'] as String?)
                : (d['driver_id'] as String?);

            // Prefer stored names in history (user_name/driver_name). This avoids
            // extra reads per list item. Fallback to otherId or generic label.
            final storedName = isDriver
                ? (d['user_name'] as String?)
                : (d['driver_name'] as String?);
            final displayName =
                storedName ??
                otherId ??
                (isDriver ? 'User tidak diketahui' : 'Driver tidak diketahui');

            return Card(
              child: ListTile(
                title: Text(displayName),
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
                            Text('Order ID: ${doc.id}'),
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
