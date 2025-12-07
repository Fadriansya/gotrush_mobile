// user_home.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:sampah_online/screens/user/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/order_service.dart';
import '../../services/notification_service.dart';
import '../../utils/alerts.dart';
import '../../payment.dart';
import '../../midtrans_payment_webview.dart';
import '../order_history_widget.dart';
import '../map_selection_screen.dart';
import 'pickup_schedule_screen.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  final OrderService _orderService = OrderService();
  StreamSubscription<firestore.QuerySnapshot>? _orderSub;
  final Map<String, String> _orderStatuses = {}; // track per order
  bool _dialogOpen = false;
  DateTime? _lastNotifyAt;
  String? _lastNotifiedOrderId;

  // sample fixed point used for price/distance calc (Monas)
  final firestore.GeoPoint _monasLocation = const firestore.GeoPoint(
    -6.175392,
    106.827153,
  );

  static const double _pricePerKm = 2000; // example
  static const double _pricePerKg = 2000; // example

  @override
  void initState() {
    super.initState();
    _subscribeOrderStream();
  }

  @override
  void dispose() {
    _orderSub?.cancel();
    super.dispose();
  }

  void _subscribeOrderStream() {
    final auth = Provider.of<AuthService>(context, listen: false);
    final uid = auth.currentUser?.uid;
    if (uid == null) return;
    bool isInitialLoad = true;

    _orderSub = firestore.FirebaseFirestore.instance
        .collection('orders')
        .where(
          'status',
          whereIn: [
            'waiting',
            'accepted',
            'on_the_way',
            'arrived',
            'pickup_confirmed_by_driver',
            'paid', // include paid so user sees it if needed
            'completed',
          ],
        )
        .snapshots()
        .listen(
          (snap) {
            if (isInitialLoad) {
              for (var doc in snap.docs) {
                final id = doc.id;
                final data = doc.data();
                final status = (data['status'] as String?) ?? '';
                _orderStatuses[id] = status;
              }
              // next snapshots are "real" updates
              isInitialLoad = false;
              return;
            }
            for (var doc in snap.docs) {
              final id = doc.id;
              final data = doc.data();
              final status = (data['status'] as String?) ?? '';
              final userId = data['user_id'] as String?;
              if (userId != uid) continue; // only care about this user's orders

              final previousStatus = _orderStatuses[id];
              if (previousStatus != status) {
                _orderStatuses[id] = status;
                _handleStatusChange(
                  id,
                  status,
                  Map<String, dynamic>.from(data),
                );
              }
            }
          },
          onError: (e) {
            debugPrint('Order subscription error: $e');
          },
        );
  }

  double _calculateDistance(firestore.GeoPoint a, firestore.GeoPoint b) {
    // Haversine formula
    const R = 6371; // km
    final lat1 = a.latitude * (math.pi / 180);
    final lon1 = a.longitude * (math.pi / 180);
    final lat2 = b.latitude * (math.pi / 180);
    final lon2 = b.longitude * (math.pi / 180);
    final dlat = lat2 - lat1;
    final dlon = lon2 - lon1;
    final aa =
        math.sin(dlat / 2) * math.sin(dlat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dlon / 2) *
            math.sin(dlon / 2);
    final c = 2 * math.atan2(math.sqrt(aa), math.sqrt(1 - aa));
    return R * c; // km
  }

  Future<void> _handleStatusChange(
    String orderId,
    String status,
    Map<String, dynamic> data,
  ) async {
    if (!mounted) return;

    final now = DateTime.now();
    if (_lastNotifyAt != null && _lastNotifiedOrderId == orderId) {
      final diff = now.difference(_lastNotifyAt!);
      if (diff < const Duration(seconds: 3)) return; // debounce
    }
    _lastNotifyAt = now;
    _lastNotifiedOrderId = orderId;

    final notificationService = Provider.of<NotificationService>(
      context,
      listen: false,
    );

    switch (status) {
      case 'accepted':
        await notificationService.showLocal(
          id: orderId.hashCode,
          title: 'Driver Ditemukan',
          body: 'Driver telah menerima pesanan Anda.',
        );
        if (_dialogOpen) return;
        _dialogOpen = true;
        showAppDialog(
          context,
          title: 'Driver Ditemukan',
          message:
              'Driver ${data['driver_id'] ?? ''} telah menerima pesanan Anda.',
          type: AlertType.info,
        ).then((_) {
          if (mounted) setState(() => _dialogOpen = false);
        });
        break;

      case 'on_the_way':
        await notificationService.showLocal(
          id: orderId.hashCode + 1,
          title: 'Driver Menuju Lokasi',
          body: 'Driver sedang menuju lokasi Anda.',
        );
        showAppSnackBar(
          context,
          'Driver sedang menuju lokasi Anda',
          type: AlertType.info,
        );
        break;

      case 'arrived':
        await notificationService.showLocal(
          id: orderId.hashCode + 2,
          title: 'Driver Telah Sampai',
          body: 'Driver telah sampai di lokasi. Silakan siapkan sampah.',
        );
        if (_dialogOpen) return;
        _dialogOpen = true;
        showAppDialog(
          context,
          title: 'Driver Sampai',
          message: 'Driver telah sampai di lokasi. Silakan siapkan sampah.',
          type: AlertType.info,
        ).then((_) {
          if (mounted) setState(() => _dialogOpen = false);
        });
        break;

      case 'pickup_confirmed_by_driver':
        await notificationService.showLocal(
          id: orderId.hashCode + 3,
          title: 'Konfirmasi Pengambilan',
          body:
              'Driver telah mengkonfirmasi pengambilan sampah. Harap konfirmasi.',
        );
        if (_dialogOpen) return;
        _dialogOpen = true;
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Konfirmasi Pengambilan'),
            content: const Text(
              'Driver telah mengkonfirmasi pengambilan sampah. Apakah Anda setuju?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  if (mounted) setState(() => _dialogOpen = false);
                },
                child: const Text('Tolak'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  if (!mounted) return;
                  setState(() => _dialogOpen = false);
                  await firestore.FirebaseFirestore.instance
                      .collection('orders')
                      .doc(orderId)
                      .update({'status': 'completed'});
                  showAppSnackBar(
                    context,
                    'Pengambilan sampah berhasil dikonfirmasi!',
                    type: AlertType.success,
                  );
                },
                child: const Text('Setuju'),
              ),
            ],
          ),
        );
        break;

      case 'paid':
      case 'settlement':
        // server webhook sets order to paid/settlement → beri info ke user
        await notificationService.showLocal(
          id: orderId.hashCode + 10,
          title: 'Pembayaran Berhasil',
          body: 'Pembayaran telah sukses. Order akan diproses.',
        );
        showAppSnackBar(
          context,
          'Pembayaran sukses. Menunggu driver mengambil order.',
          type: AlertType.success,
        );
        break;

      case 'completed':
        await notificationService.showLocal(
          id: orderId.hashCode + 4,
          title: 'Pesanan Selesai',
          body: 'Terima kasih! Sampah telah diambil.',
        );
        if (_dialogOpen) return;
        _dialogOpen = true;
        showAppDialog(
          context,
          title: 'Selesai',
          message: 'Terima kasih! Sampah telah diambil.',
          type: AlertType.success,
        ).then((_) {
          if (mounted) setState(() => _dialogOpen = false);
        });
        break;

      case 'payment_failed':
        showAppSnackBar(
          context,
          'Pembayaran gagal. Silakan coba lagi.',
          type: AlertType.error,
        );
        break;

      default:
        // ignore unknown statuses
        break;
    }
  }

  // ===================== CREATE ORDER FLOW (final) =====================
  Future<void> _startCreateOrderFlow() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const MapSelectionScreen()),
    );

    if (result == null) return; // user canceled

    final firestore.GeoPoint selectedLocation =
        result['location'] as firestore.GeoPoint;
    final String selectedAddress = result['address'] as String;

    final distanceKm = _calculateDistance(_monasLocation, selectedLocation);
    final addressCtl = TextEditingController(text: selectedAddress);
    final distanceCtl = TextEditingController(
      text: distanceKm.toStringAsFixed(2),
    );
    final weightCtl = TextEditingController();
    final priceCtl = TextEditingController();
    DateTime? selectedDate;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setStateDialog) {
          void _updatePrice() {
            final distance = double.tryParse(distanceCtl.text) ?? 0;
            final weight = double.tryParse(weightCtl.text) ?? 0;
            final price = (distance * _pricePerKm) + (weight * _pricePerKg);
            priceCtl.text = price.toStringAsFixed(0);
          }

          return AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.add_location_alt, color: Colors.green),
                SizedBox(width: 8),
                Expanded(child: Text('Buat Order Penjemputan')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: addressCtl,
                    decoration: const InputDecoration(labelText: 'Alamat'),
                  ),
                  TextField(
                    controller: distanceCtl,
                    decoration: const InputDecoration(labelText: 'Jarak (km)'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _updatePrice(),
                  ),
                  TextField(
                    controller: weightCtl,
                    decoration: const InputDecoration(labelText: 'Berat (kg)'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _updatePrice(),
                  ),
                  TextField(
                    controller: priceCtl,
                    decoration: const InputDecoration(labelText: 'Harga (Rp)'),
                    keyboardType: TextInputType.number,
                    readOnly: true,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now().add(
                          const Duration(days: 1),
                        ),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked != null) {
                        setStateDialog(() => selectedDate = picked);
                      }
                    },
                    child: Text(
                      selectedDate == null
                          ? 'Pilih Tanggal Penjemputan'
                          : 'Tanggal: ${selectedDate!.toLocal().toString().split(' ')[0]}',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final address = addressCtl.text.trim();
                  final distance = double.tryParse(distanceCtl.text) ?? 0;
                  final weight = double.tryParse(weightCtl.text) ?? 0;
                  final price = double.tryParse(priceCtl.text) ?? 0;

                  if (address.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Alamat harus diisi'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  // ambil user info
                  final auth = Provider.of<AuthService>(context, listen: false);
                  final uid = auth.currentUser?.uid ?? '';
                  final name = auth.currentUser?.displayName ?? 'User';
                  final email = auth.currentUser?.email ?? 'user@example.com';

                  // 1) generate orderId unik (dipakai untuk Firestore & Midtrans)
                  final orderId =
                      'ORDER_${DateTime.now().millisecondsSinceEpoch}_$uid';

                  // 2) simpan order awal ke Firestore dengan status pending_payment
                  try {
                    await _orderService.createOrder(
                      orderId: orderId,
                      userId: uid,
                      weight: weight,
                      distance: distance,
                      price: price,
                      address: address,
                      location: selectedLocation,
                      photoUrls: [],
                      status: 'waiting',
                      pickupDate: selectedDate,
                    );
                  } catch (e) {
                    if (!mounted) return;
                    showAppSnackBar(
                      context,
                      'Gagal menyimpan order: $e',
                      type: AlertType.error,
                    );
                    return;
                  }

                  // 3) minta Snap URL dari backend
                  final snapUrl = await getMidtransSnapUrl(
                    orderId: orderId,
                    grossAmount: price.toInt(),
                    name: name,
                    email: email,
                  );

                  if (snapUrl == null) {
                    // tandai order gagal diproses pembayaran
                    try {
                      await _orderService.updateStatus(
                        orderId,
                        'payment_failed',
                      );
                    } catch (_) {}
                    if (!mounted) return;
                    showAppSnackBar(
                      context,
                      'Gagal mendapatkan link pembayaran. Silakan coba lagi',
                      type: AlertType.error,
                    );
                    return;
                  }

                  // 4) buka WebView Midtrans
                  Navigator.of(ctx).pop(); // tutup dialog sebelum ke webview
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MidtransPaymentWebView(
                        snapUrl: snapUrl,
                        orderId: orderId,
                        onPaymentSuccess: () async {
                          await firestore.FirebaseFirestore.instance
                              .collection('orders')
                              .doc(orderId)
                              .update({'status': 'payment_success'});
                          if (!mounted) return;
                          showAppSnackBar(
                            context,
                            'PEMBAYARAN BERHASIL! Silakan tunggu driver mengambil order.',
                            type: AlertType.success,
                          );
                        },
                      ),
                    ),
                  );
                },
                child: const Text('Bayar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveOrderToFirestore({
    required String address,
    required double distance,
    required double weight,
    required double price,
    required firestore.GeoPoint location,
    String status = 'waiting',
  }) async {
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final uid = auth.currentUser?.uid;
      if (uid == null) throw Exception('User belum login');
      final String orderId = DateTime.now().millisecondsSinceEpoch.toString();
      await _orderService.createOrder(
        orderId: orderId,
        userId: uid,
        weight: weight,
        distance: distance,
        price: price,
        address: address,
        location: location,
        photoUrls: [],
        status: status,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pesanan berhasil disimpan ke riwayat!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan pesanan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ===================== UI =====================
  final List<Map<String, Object>> menuItems = [
    {
      'title': 'Jadwal Penjemputan',
      'subtitle': 'Lihat jadwal penjemputan sampah Anda',
      'icon': Icons.recycling,
      'color1': const Color(0xFFD9F2D9),
      'color2': const Color(0xFFC1EAC1),
    },
    {
      'title': 'Poin & Reward',
      'subtitle': 'Lihat jumlah poin yang telah kamu kumpulkan',
      'icon': Icons.star_rate,
      'color1': const Color(0xFFFFE3B3),
      'color2': const Color(0xFFFFD580),
    },
    {
      'title': 'Edukasi Daur Ulang',
      'subtitle': 'Pelajari cara mengelola sampah dengan benar',
      'icon': Icons.book_rounded,
      'color1': const Color(0xFFCCE1FF),
      'color2': const Color(0xFFB3D4FF),
    },
  ];

  int _selectedIndex = 0;
  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final pages = [_buildBeranda(), _buildRiwayat(), const UserProfile()];

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F4),
      appBar: AppBar(
        title: Text(
          _selectedIndex == 0
              ? 'Beranda Pengguna'
              : _selectedIndex == 1
              ? 'Riwayat Penjemputan'
              : 'Profil Saya',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.green[700],
      ),
      body: pages[_selectedIndex],
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _startCreateOrderFlow,
              label: const Text(
                'Buat Order',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                  fontSize: 20,
                ),
              ),
              icon: const Icon(Icons.add_location_alt),
              backgroundColor: const Color.fromARGB(255, 13, 214, 23),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green[700],
        unselectedItemColor: Colors.grey[500],
        selectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.poppins(),
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            label: 'Riwayat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _buildBeranda() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hai, Selamat Datang! 👋',
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.green[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Kelola aktivitas penjemputan sampahmu dengan mudah.',
            style: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 14),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final item = menuItems[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: _MenuCard(
                    title: item['title'] as String,
                    subtitle: item['subtitle'] as String,
                    icon: item['icon'] as IconData,
                    color1: item['color1'] as Color,
                    color2: item['color2'] as Color,
                    onTap: () {
                      if (item['title'] == 'Jadwal Penjemputan') {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PickupScheduleScreen(),
                          ),
                        );
                      } else {
                        showAppSnackBar(
                          context,
                          'Navigasi ke ${item['title']}',
                          type: AlertType.info,
                        );
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiwayat() {
    final auth = Provider.of<AuthService>(context, listen: false);
    final currentUserId = auth.currentUser?.uid ?? '';
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: OrderHistoryWidget(currentUserId: currentUserId, role: 'user'),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color1;
  final Color color2;
  final VoidCallback onTap;

  const _MenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color1,
    required this.color2,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color1, color2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withAlpha((0.25 * 255).round()),
              blurRadius: 6,
              offset: const Offset(2, 3),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white,
                child: Icon(icon, size: 28, color: Colors.green[800]),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
