import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminRevenuePage extends StatefulWidget {
  const AdminRevenuePage({super.key});

  @override
  State<AdminRevenuePage> createState() => _AdminRevenuePageState();
}

class _AdminRevenuePageState extends State<AdminRevenuePage> {
  double total = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadRevenue();
  }

  Future<void> _loadRevenue() async {
    setState(() {
      loading = true;
      total = 0;
    });
    try {
      // Ambil order_history completed — jika volume besar, pertimbangkan
      // aggregate via Cloud Function untuk performa
      final snap = await FirebaseFirestore.instance
          .collection('order_history')
          .where('status', isEqualTo: 'completed')
          .get();

      double sum = 0;
      for (var doc in snap.docs) {
        final p = doc.data()['price_paid'] ?? doc.data()['price'] ?? 0;
        sum += (p is num) ? p.toDouble() : double.tryParse(p.toString()) ?? 0;
      }

      setState(() {
        total = sum;
      });
    } catch (e) {
      debugPrint('Gagal load revenue: $e');
      // optional: show snackbar
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Total Pemasukan',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
        ),
        backgroundColor: Colors.green.shade600,
        actions: [
          IconButton(onPressed: _loadRevenue, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Center(
        child: loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total pemasukan (order completed)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Rp ${total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      // juga sediakan export sederhana: hitung ulang dan tampilkan count
                      final countSnap = await FirebaseFirestore.instance
                          .collection('order_history')
                          .where('status', isEqualTo: 'completed')
                          .get();
                      final count = countSnap.size;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Total order completed: $count'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.file_download),
                    label: const Text('Statistik singkat'),
                  ),
                ],
              ),
      ),
    );
  }
}
