import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sampah_online/welcome_screen.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../../services/order_service.dart';
import '../../services/auth_service.dart';
import '../../utils/alerts.dart';
import '../profile_screen.dart';
import '../order_history_widget.dart';
import '/screens/driver_map_tracking_screen.dart';

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
  Map<String, dynamic>? _activeOrderData;
  String? _activeOrderId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startListeningAndTracking();
    });
  }

  @override
  void dispose() {
    _orderSub?.cancel();
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _startListeningAndTracking() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final driverUid = auth.currentUser?.uid;
    if (driverUid == null) return;

    GeoPoint driverStartLocation = const GeoPoint(-6.1900, 106.7969);
    // Hentikan listener sebelumnya
    _orderSub?.cancel();

    _orderSub = FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'waiting')
        .snapshots()
        .listen((snapshot) {
          if (snapshot.docs.isEmpty) return;

          for (var doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final orderId = doc.id;

            // Jika ada order aktif → jangan munculkan popup
            if (_activeOrderId != null) continue;

            if (!_showingDialog) {
              _showingDialog = true;

              Future.microtask(() {
                _promptAcceptOrder(orderId, data);
              });

              break;
            }
          }
        });
    FirebaseFirestore.instance
        .collection('orders')
        .where('driver_id', isEqualTo: driverUid)
        .where('status', whereIn: ['accepted', 'on_the_way'])
        .snapshots()
        .listen((activeSnapshot) {
          if (activeSnapshot.docs.isNotEmpty) {
            final doc = activeSnapshot.docs.first;

            if (mounted) {
              setState(() {
                _activeOrderId = doc.id;
                _activeOrderData = doc.data();
              });
            }
          } else if (_activeOrderId != null) {
            if (mounted) {
              setState(() {
                _activeOrderId = null;
                _activeOrderData = null;
              });
            }
          }
        });

    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      final status = _activeOrderData?['status'];

      if (status == 'accepted' || status == 'on_the_way') {
        _updateDriverLocation(driverUid);
      }
    });
  }

  Future<void> _onDepartPressed() async {
    if (_activeOrderId == null || _activeOrderData == null) return;
    final GeoPoint defaultLocation = const GeoPoint(-6.1900, 106.7969);
    final GeoPoint pickupLocation =
        _activeOrderData!['pickup_location'] as GeoPoint? ?? defaultLocation;
    try {
      await _orderService.updateStatus(_activeOrderId!, 'on_the_way');
      if (!mounted) return;
      Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (context) => DriverMapTrackingScreen(
                orderId: _activeOrderId!,
                userLocation: pickupLocation, // Kirim lokasi tujuan
              ),
            ),
          )
          .then((_) {
            // Opsional: Lakukan sesuatu saat kembali dari halaman map
          });
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
                                      showAppSnackBar(
                                        context,
                                        'Gagal menerima: pesanan sudah diambil driver lain',
                                        type: AlertType.error,
                                      );
                                    }
                                  }
                                } catch (e) {
                                  if (!context.mounted) return;
                                  showAppSnackBar(
                                    context,
                                    'Gagal terima pesanan: $e',
                                    type: AlertType.error,
                                  );
                                } finally {
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (mounted) {
                                      setState(() => _showingDialog = false);
                                    }
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
            // Aktif Order Card
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
                      // Jangan panggil setState secara sinkron di dalam build.
                      if (_activeOrderId != null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          // Pastikan tidak menggandakan setState berkali-kali
                          if (_activeOrderId != null) {
                            setState(() {
                              _activeOrderId = null;
                              _activeOrderData = null;
                            });
                          }
                        });
                      }
                      return const SizedBox.shrink();
                    }
                    final doc = snapshot.data!.docs.first;
                    final data = doc.data() as Map<String, dynamic>;
                    final status = data['status'] as String? ?? '';
                    final orderId = doc.id;

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_activeOrderId != orderId ||
                          _activeOrderData?['status'] != status) {
                        setState(() {
                          _activeOrderId = orderId;
                          _activeOrderData = data;
                        });
                      }
                    });

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
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (status == 'accepted')
                                  ElevatedButton(
                                    onPressed: _onDepartPressed,
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
                                      if (context.mounted) {
                                        setState(() {
                                          _activeOrderId = null;
                                          _activeOrderData = null;
                                          _locationUpdateTimer?.cancel();
                                        });
                                      }
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
