import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import '../../services/order_service.dart';
import '../../services/auth_service.dart';
import '../../utils/alerts.dart';
import '../profile_screen.dart';
import '../order_history_widget.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final OrderService _orderService = OrderService();
  StreamSubscription<QuerySnapshot>? _sub;
  bool _showingDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthService>(context, listen: false);
      final driverUid = auth.currentUser?.uid;
      _sub = _orderService
          .listenNearbyOrdersForDriver(driverUid ?? '', 10, GeoPoint(0, 0))
          .listen((snapshot) {
            for (var doc in snapshot.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final status = data['status'] as String? ?? '';
              if (status == 'waiting' && !_showingDialog) {
                _showingDialog = true;
                _promptAcceptOrder(doc.id, data);
                break;
              }
            }
          });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _promptAcceptOrder(
    String orderId,
    Map<String, dynamic> data,
  ) async {
    if (!context.mounted) return;
    final auth = Provider.of<AuthService>(context, listen: false);
    final driverId = auth.currentUser?.uid ?? '';
    // do not capture BuildContext-derived objects before async gaps; obtain messenger after async work

    // show a modal bottom sheet with a small entrance animation for the icon
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: MediaQuery.of(ctx).viewInsets,
          child: StatefulBuilder(
            builder: (ctx2, setStateDialog) {
              bool processing = false;
              return SafeArea(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 48,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // animated icon
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 450),
                            builder: (context, val, child) {
                              return Transform.scale(
                                scale: 0.8 + 0.2 * val,
                                child: child,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                // avoid deprecated withOpacity by using withAlpha
                                color: Colors.green.withAlpha(
                                  (0.12 * 255).round(),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.local_shipping,
                                color: Colors.green[700],
                                size: 32,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Pesanan Baru',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${data['address'] ?? '-'}',
                                  style: const TextStyle(color: Colors.black87),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Jarak: ${data['distance'] ?? '-'} km',
                                style: const TextStyle(color: Colors.black54),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Harga: ${data['price'] ?? '-'}',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          // small badge for estimated time or priority (if available)
                          if (data['eta'] != null)
                            Chip(label: Text('${data['eta']}')),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                // close sheet then update parent state if still mounted
                                Navigator.of(ctx2).pop();
                                if (!mounted) return;
                                setState(() => _showingDialog = false);
                              },
                              child: const Text('Tolak'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[700],
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              // ignore: use_build_context_synchronously
                              onPressed: () async {
                                if (processing) return;
                                setStateDialog(() => processing = true);
                                // close sheet then perform async work
                                Navigator.of(ctx2).pop();
                                try {
                                  final accepted = await _orderService
                                      .acceptOrder(orderId, driverId);
                                  if (!mounted) return;
                                  if (accepted) {
                                    showAppSnackBar(
                                      context,
                                      'Pesanan berhasil diterima',
                                      type: AlertType.success,
                                    );
                                  } else {
                                    showAppSnackBar(
                                      context,
                                      'Gagal menerima: pesanan sudah diambil driver lain',
                                      type: AlertType.error,
                                    );
                                  }
                                } catch (e) {
                                  if (!context.mounted) return;
                                  showAppSnackBar(
                                    context,
                                    'Gagal terima pesanan: $e',
                                    type: AlertType.error,
                                  );
                                } finally {
                                  if (context.mounted) {
                                    setState(() => _showingDialog = false);
                                  }
                                  // try to update dialog local state if still available
                                  try {
                                    setStateDialog(() => processing = false);
                                  } catch (_) {
                                    // sheet already closed; nothing to do
                                  }
                                }
                              },
                              child: Builder(
                                builder: (_) {
                                  if (processing) {
                                    return const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    );
                                  }
                                  return const Text(
                                    'Terima',
                                    style: TextStyle(color: Colors.white),
                                  );
                                },
                              ),
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String driverName = "Driver";

    return Scaffold(
      backgroundColor: const Color(0xFFF2F8F3),
      appBar: AppBar(
        backgroundColor: Colors.green[700],
        elevation: 0,
        title: const Text(
          "Dashboard Driver",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green[700],
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withAlpha((0.3 * 255).round()),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.local_shipping,
                      size: 36,
                      color: Colors.green[700],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      "Hai, $driverName 👋\nSiap menjalankan tugas hari ini?",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text(
              "Menu Utama",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 12),

            // Grid Menu
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildMenuCard(
                  context,
                  title: "Pesanan Baru",
                  subtitle: "Lihat pesanan masuk",
                  icon: FontAwesomeIcons.clipboardList,
                  color: Colors.green,
                  onTap: () {
                    // TODO: Navigasi ke halaman pesanan baru
                  },
                ),
                _buildMenuCard(
                  context,
                  title: "Riwayat",
                  subtitle: "Lihat pengambilan sebelumnya",
                  icon: FontAwesomeIcons.clockRotateLeft,
                  color: Colors.blue,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('Riwayat')),
                          body: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: OrderHistoryWidget(role: 'driver'),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                _buildMenuCard(
                  context,
                  title: "Status Online",
                  subtitle: "Ubah status kerja",
                  icon: FontAwesomeIcons.wifi,
                  color: Colors.orange,
                  onTap: () {
                    // TODO: Navigasi ke status online/offline
                  },
                ),
                _buildMenuCard(
                  context,
                  title: "Profil",
                  subtitle: "Edit profil dan info akun",
                  icon: FontAwesomeIcons.userGear,
                  color: Colors.purple,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ProfileScreen(role: 'driver'),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Bagian: order aktif (jika ada) -> kontrol status
            Builder(
              builder: (ctx) {
                final auth = Provider.of<AuthService>(context, listen: false);
                final driverUid = auth.currentUser?.uid;
                if (driverUid == null) return const SizedBox.shrink();

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('orders')
                      .where('driver_id', isEqualTo: driverUid)
                      .where(
                        'status',
                        whereIn: ['accepted', 'on_the_way', 'arrived'],
                      )
                      .limit(1)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final doc = snapshot.data!.docs.first;
                    final data = doc.data() as Map<String, dynamic>;
                    final status = data['status'] as String? ?? '';
                    final orderId = doc.id;

                    return Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    // avoid deprecated withOpacity
                                    color: Colors.green.withAlpha(
                                      (0.12 * 255).round(),
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.assignment_turned_in,
                                    color: Colors.green[700],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Order Aktif',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 350),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: status == 'accepted'
                                        ? Colors.orange[100]
                                        : status == 'on_the_way'
                                        ? Colors.blue[100]
                                        : status == 'arrived'
                                        ? Colors.green[100]
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    status.replaceAll('_', ' ').toUpperCase(),
                                    style: TextStyle(
                                      color: status == 'accepted'
                                          ? Colors.orange[800]
                                          : status == 'on_the_way'
                                          ? Colors.blue[800]
                                          : status == 'arrived'
                                          ? Colors.green[800]
                                          : Colors.grey[700],
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Alamat: ${data['address'] ?? '-'}'),
                            const SizedBox(height: 6),
                            // status line removed (status shown as badge)
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (status == 'accepted')
                                  ElevatedButton(
                                    onPressed: () async {
                                      await _orderService.updateStatus(
                                        orderId,
                                        'on_the_way',
                                      );
                                    },
                                    child: const Text('Berangkat'),
                                  ),
                                const SizedBox(width: 8),
                                if (status == 'on_the_way')
                                  ElevatedButton(
                                    onPressed: () async {
                                      await _orderService.updateStatus(
                                        orderId,
                                        'arrived',
                                      );
                                    },
                                    child: const Text('Tiba'),
                                  ),
                                const SizedBox(width: 8),
                                if (status == 'arrived')
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green[700],
                                    ),
                                    onPressed: () async {
                                      // Selesaikan order (tanpa foto)
                                      await _orderService.updateStatus(
                                        orderId,
                                        'completed',
                                      );
                                    },
                                    child: const Text('Konfirmasi Ambil'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 24),
            // Footer
            Center(
              child: TextButton.icon(
                onPressed: () {
                  // TODO: Logout logic
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text(
                  "Keluar Akun",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 Widget untuk menu card
  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      // use withAlpha instead of withOpacity to avoid deprecation
      splashColor: color.withAlpha((0.2 * 255).round()),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha((0.15 * 255).round()),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: color.withAlpha((0.15 * 255).round()),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.grey[900],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
