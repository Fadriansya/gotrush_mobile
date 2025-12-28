// driver_home.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sampah_online/screens/driver/driver_profile.dart';
import 'package:sampah_online/screens/driver/new_orders_screen.dart';
import 'package:sampah_online/welcome_screen.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../services/order_service.dart';
import '../../services/auth_service.dart';
import '../../utils/alerts.dart';
import '../../services/notification_service.dart';
import '../order_history_widget.dart';
import '../chat_screen.dart';
import '../order_room_screen.dart';
import 'driver_map_tracking_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final OrderService _orderService = OrderService();
  StreamSubscription<QuerySnapshot>? _orderSub;
  Timer? _locationUpdateTimer;
  bool _showingDialog = false;
  bool _notificationShown = false;
  Map<String, dynamic>? _activeOrderData;
  String? _activeOrderId;
  String? _previousStatus;
  Timestamp? _lastLoginAt;
  bool _checkedInitialOrders = false;
  Map<String, String> _previousStatusPerOrder = {};
  String? _lastNavigatedOrderId; // Tambahkan ini di bagian atas state

  DateTime _startOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _endOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadLastLogin();
      _startListeningAndTracking();
    });
  }

  @override
  void dispose() {
    _orderSub?.cancel();
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  Widget _buildTodayOrderBadge() {
    final startToday = Timestamp.fromDate(_startOfToday());
    final endToday = Timestamp.fromDate(_endOfToday());

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('status', whereIn: ['pending'])
          .where('driver_id', isNull: true)
          .where('pickup_date', isGreaterThanOrEqualTo: startToday)
          .where('pickup_date', isLessThan: endToday)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        // Semua dokumen di snapshot sudah pasti order hari ini
        final orderCount = snapshot.data!.docs.length;
        // Tampilkan badge hanya jika ada order hari ini
        if (orderCount == 0) return const SizedBox.shrink();

        return Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            child: Text(
              orderCount.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadLastLogin() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    _lastLoginAt = doc.data()?['last_login_at'] as Timestamp?;
  }

  Future<void> _startListeningAndTracking() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final driverUid = auth.currentUser?.uid;
    if (driverUid == null) return;

    _orderSub?.cancel();
    final startToday = Timestamp.fromDate(_startOfToday());
    final endToday = Timestamp.fromDate(_endOfToday());
    final Set<String> notifiedOrderIds = {};

    // 🔹 Stream untuk order baru hari ini yang belum diambil driver
    _orderSub = FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'pending')
        .where('driver_id', isNull: true)
        .where('pickup_date', isGreaterThanOrEqualTo: startToday)
        .where('pickup_date', isLessThan: endToday)
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;

          final hasOrders = snapshot.docs.isNotEmpty;

          if (hasOrders && !_notificationShown) {
            _notificationShown = true;
            _showNewOrdersNotification();
          }

          if (!hasOrders) {
            _notificationShown = false;
          }
        });

    // 🔹 Stream untuk order aktif driver
    FirebaseFirestore.instance
        .collection('orders')
        .where('driver_id', isEqualTo: driverUid)
        .where('archived', isEqualTo: false)
        .where(
          'status',
          whereIn: [
            'active',
            'awaiting_confirmation',
            'waiting_payment',
            'pickup_validation',
            'arrived',
            'waiting_user_validation',
            'picked_up',
            'completed',
          ],
        )
        .snapshots()
        .listen((activeSnapshot) {
          if (!mounted) return;

          if (activeSnapshot.docs.isNotEmpty) {
            final doc = activeSnapshot.docs.first;
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] as String;
            final orderId = doc.id;
            final paymentStatus = data['payment_status'];
            setState(() {
              _activeOrderId = orderId;
              _activeOrderData = data;
            });
            if (status == 'active' && _lastNavigatedOrderId != orderId) {
              _lastNavigatedOrderId = orderId; // Tandai sudah navigasi

              Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (_) =>
                          OrderRoomScreen(orderId: orderId, role: 'driver'),
                    ),
                  )
                  .then((_) {
                    // Reset saat kembali ke home jika diperlukan
                    _lastNavigatedOrderId = null;
                  });
            }

            // Push Notification Global
            if (_previousStatusPerOrder[orderId] != '$status|$paymentStatus') {
              _previousStatusPerOrder[orderId] = '$status|$paymentStatus';
              // Saat order masuk status active, alihkan ke halaman Order Room
              if (status == 'active') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        OrderRoomScreen(orderId: orderId, role: 'driver'),
                  ),
                );
              }
              if (paymentStatus == 'success') {
                NotificationService().showLocal(
                  id: orderId.hashCode & 0x7fffffff,
                  title: 'Pesanan Dibayar',
                  body: 'Silakan tekan Konfirmasi Ambil',
                );
              }

              switch (status) {
                case 'pickup_validation':
                  NotificationService().showLocal(
                    id: orderId.hashCode & 0x7fffffff,
                    title: 'Validasi Pengambilan',
                    body: 'Silakan konfirmasi ambil sampah di order.',
                  );
                  break;
                case 'waiting_user_validation':
                  NotificationService().showLocal(
                    id: orderId.hashCode & 0x7fffffff,
                    title: 'Menunggu Validasi User',
                    body: 'User akan memvalidasi pengambilan Anda.',
                  );
                  break;
                case 'completed':
                  NotificationService().showLocal(
                    id: orderId.hashCode & 0x7fffffff,
                    title: 'Order Selesai',
                    body: 'Order telah selesai',
                  );
                  break;
              }
            }
          } else if (_activeOrderId != null) {
            setState(() {
              _activeOrderId = null;
              _activeOrderData = null;
            });
          }
        });

    // 🔹 Timer update lokasi driver setiap 10 detik
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final status = _activeOrderData?['status'];
      if (status == 'active') {
        _updateDriverLocation(driverUid);
      }
    });
  }

  Future<void> _onDepartPressed() async {
    if (_activeOrderId == null || _activeOrderData == null) return;
    final GeoPoint defaultLocation = const GeoPoint(-6.1900, 106.7969);
    final GeoPoint pickupLocation =
        _activeOrderData!['location'] as GeoPoint? ?? defaultLocation;
    try {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => DriverMapTrackingScreen(
            orderId: _activeOrderId!,
            userLocation: pickupLocation,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        'Gagal memulai perjalanan: $e',
        type: AlertType.error,
      );
    }
  }

  Future<void> _updateDriverLocation(String driverUid) async {
    try {
      // Dapatkan lokasi driver saat ini
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final driverLocation = {
        'location': GeoPoint(position.latitude, position.longitude),
        'timestamp': Timestamp.now(),
        // Anda juga bisa menambahkan bearing/kecepatan jika diperlukan
      };

      await FirebaseFirestore.instance
          .collection('drivers_location')
          .doc(driverUid)
          .set(driverLocation, SetOptions(merge: true));
    } catch (e) {
      // Handle error jika driver menolak izin lokasi atau gagal
      print('Gagal update lokasi driver: $e');
    }
  }

  Future<void> _showNewOrdersNotification() async {
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 24), // Spacer for center alignment
                    IconButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        if (mounted) {
                          setState(() => _notificationShown = false);
                        }
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Ada orderan baru hari ini',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    if (mounted) {
                      setState(() => _notificationShown = false);
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NewOrdersScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Center(
                    child: Text('Lihat', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _promptAcceptOrder(
    String orderId,
    Map<String, dynamic> data,
  ) async {
    if (!context.mounted) return;
    final auth = Provider.of<AuthService>(context, listen: false);
    final driverId = auth.currentUser?.uid ?? '';
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
                                Navigator.of(ctx2).pop();
                                if (mounted) {
                                  setState(() => _showingDialog = false);
                                }
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
                              onPressed: () async {
                                if (processing) return;
                                setStateDialog(() => processing = true);
                                try {
                                  final accepted = await _orderService
                                      .acceptOrder(orderId, driverId);
                                  if (!mounted) return;
                                  if (accepted) {
                                    _orderSub?.cancel();
                                    // Reset _showingDialog immediately after success to prevent re-showing dialog
                                    setState(() => _showingDialog = false);
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (!mounted) return;
                                          setState(() {
                                            _activeOrderId = orderId;
                                            _activeOrderData = data;
                                            _activeOrderData!['status'] =
                                                'accepted';
                                          });
                                        });
                                    await _updateDriverLocation(driverId);
                                    if (!mounted) return;
                                    showAppSnackBar(
                                      context,
                                      'Pesanan berhasil diterima',
                                      type: AlertType.success,
                                    );
                                  } else {
                                    if (!accepted) {
                                      // Also ensure dialog flag is reset on failure
                                      setState(() => _showingDialog = false);
                                      showAppSnackBar(
                                        context,
                                        'Gagal menerima: pesanan sudah diambil driver lain',
                                        type: AlertType.error,
                                      );
                                    }
                                  }
                                } catch (e) {
                                  if (!context.mounted) return;
                                  setState(() => _showingDialog = false);
                                  showAppSnackBar(
                                    context,
                                    'Gagal terima pesanan: $e',
                                    type: AlertType.error,
                                  );
                                } finally {
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (ctx2.mounted) {
                                      Navigator.of(ctx2).pop();
                                    }
                                  });
                                  try {
                                    setStateDialog(() => processing = false);
                                  } catch (_) {}
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
    final auth = Provider.of<AuthService>(context, listen: false);
    final currentUserId = auth.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF2F8F3),
      appBar: AppBar(
        backgroundColor: Colors.green[800],
        elevation: 0,
        title: const Text(
          "Dashboard Driver",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
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
                Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildMenuCard(
                      context,
                      title: "Pesanan Baru",
                      subtitle: "Order hari ini",
                      icon: FontAwesomeIcons.clipboardList,
                      color: Colors.green,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const NewOrdersScreen(),
                          ),
                        );
                      },
                    ),
                    _buildTodayOrderBadge(),
                  ],
                ),

                _buildMenuCard(
                  context,
                  title: "Riwayat",
                  subtitle: "Lihat daftar riwayat",
                  icon: FontAwesomeIcons.clockRotateLeft,
                  color: Colors.blue,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(
                            backgroundColor: Colors.green[800],
                            title: Text(
                              'Riwayat',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          body: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: OrderHistoryWidget(
                              currentUserId: currentUserId,
                              role: 'driver',
                            ),
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
                  subtitle: "Edit profil ",
                  icon: FontAwesomeIcons.userGear,
                  color: Colors.purple,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DriverProfile()),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),
            // Tidak lagi menampilkan Card Order Aktif.
            // Jika ada order aktif, tampilkan tombol sederhana untuk membuka halaman Order Room.
            Builder(
              builder: (ctx) {
                final auth = Provider.of<AuthService>(context, listen: false);
                final driverUid = auth.currentUser?.uid;
                if (driverUid == null) return const SizedBox.shrink();

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('orders')
                      .where('driver_id', isEqualTo: driverUid)
                      .where('archived', isEqualTo: false)
                      .where(
                        'status',
                        whereIn: [
                          'active',
                          'awaiting_confirmation',
                          'waiting_payment',
                          'pickup_validation',
                          'arrived',
                          'waiting_user_validation',
                          'picked_up',
                        ],
                      )
                      .limit(1)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final orderId = snapshot.data!.docs.first.id;
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.assignment),
                        label: const Text('Buka Order Aktif'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => OrderRoomScreen(
                                orderId: orderId,
                                role: 'driver',
                              ),
                            ),
                          );
                        },
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  );
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

  // Widget untuk menu card
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
