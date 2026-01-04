// user_home.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:sampah_online/screens/user/edukasi_screen.dart';
import 'package:sampah_online/screens/user/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/order_service.dart';
import '../../services/notification_service.dart';
import '../../utils/alerts.dart';
import '../../payment.dart';
import '../../midtrans_payment_webview.dart';
import '../order_history_widget.dart';
import '../map_selection_screen.dart';
import '../chat_screen.dart';
import '../order_room_screen.dart';
import 'pickup_schedule_screen.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  final OrderService _orderService = OrderService();
  StreamSubscription<firestore.QuerySnapshot>? _orderSub;
  bool _dialogOpen = false;
  DateTime? _lastNotifyAt;
  String? _lastNotifiedOrderId;
  Map<String, dynamic>? _activeOrderData;
  String? _activeOrderId;
  final Map<String, String?> _orderStatuses = {};
  final Map<String, String?> _paymentStatuses = {};

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
            'pending',
            'active',
            'awaiting_confirmation',
            'waiting_payment',
            'arrived',
            'waiting_user_validation',
            'picked_up',
            'completed',
          ],
        )
        .snapshots()
        .listen(
          (snap) {
            // 🔹 Initial snapshot: cache only
            if (isInitialLoad) {
              for (var doc in snap.docs) {
                final data = doc.data();
                if (data['user_id'] != uid) continue;

                _orderStatuses[doc.id] = data['status'] as String?;
                _paymentStatuses[doc.id] = data['payment_status'] as String?;
              }
              isInitialLoad = false;
              return;
            }

            for (var doc in snap.docs) {
              final data = doc.data();
              if (data['user_id'] != uid) continue;

              final orderId = doc.id;
              final status = data['status'] as String?;
              final payment = data['payment_status'] as String?;

              final prevStatus = _orderStatuses[orderId];
              final prevPayment = _paymentStatuses[orderId];

              // 🛑 Tidak ada transisi → abaikan
              if (prevStatus == status && prevPayment == payment) continue;

              // update cache
              _orderStatuses[orderId] = status;
              _paymentStatuses[orderId] = payment;

              // ✅ TRANSISI KE COMPLETED (SATU KALI SAJA)
              if (status == 'completed' && prevStatus != 'completed') {
                NotificationService().showLocal(
                  id: orderId.hashCode & 0x7fffffff,
                  title: 'Pesanan Selesai',
                  body: 'Pesanan kamu telah diselesaikan driver',
                );

                setState(() {
                  _activeOrderId = null;
                  _activeOrderData = null;
                });
              }

              // 🔁 Biarkan handler lain bekerja
              _handleStatusChange(
                orderId,
                status ?? '',
                Map<String, dynamic>.from(data),
              );
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
      if (diff < const Duration(seconds: 3)) return;
    }
    _lastNotifyAt = now;
    _lastNotifiedOrderId = orderId;

    final notificationService = Provider.of<NotificationService>(
      context,
      listen: false,
    );
    final paymentStatus = data['payment_status'];

    switch (status) {
      case 'active':
        // Alihkan ke halaman Order Room khusus
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OrderRoomScreen(orderId: orderId, role: 'user'),
            ),
          );
        }
        break;
      // case 'accepted': handled above by navigation

      case 'pickup_validation':
        await notificationService.showLocal(
          id: orderId.hashCode + 4,
          title: 'Validasi Pengambilan',
          body: 'Silakan lakukan validasi akhir setelah driver konfirmasi.',
        );
        setState(() {
          _activeOrderId = orderId;
          _activeOrderData = data;
        });
        break;

      case 'waiting_user_validation':
        await notificationService.showLocal(
          id: orderId.hashCode + 7,
          title: 'Konfirmasi Pengambilan',
          body:
              'Driver mengonfirmasi pengambilan. Apakah sampah sudah diambil?',
        );
        setState(() {
          _activeOrderId = orderId;
          _activeOrderData = data;
        });
        break;

      case 'arrived':
        await notificationService.showLocal(
          id: orderId.hashCode + 8,
          title: 'Driver Tiba di Lokasi',
          body: 'Driver telah tiba. Siapkan sampah anda.',
        );
        setState(() {
          _activeOrderId = orderId;
          _activeOrderData = data;
        });
        break;

      case 'completed':
        _orderStatuses.remove(orderId); // 👈 penting
        await notificationService.showLocal(
          id: orderId.hashCode + 6,
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
        setState(() {
          _activeOrderId = null;
          _activeOrderData = null;
        });
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
    final nameCtl = TextEditingController();
    final phoneCtl = TextEditingController();
    DateTime? selectedDate;

    // Pre-fill name and phone from user profile if available
    final auth = Provider.of<AuthService>(context, listen: false);
    final currentUser = auth.currentUser;
    if (currentUser != null) {
      nameCtl.text = currentUser.displayName ?? '';
    }

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
                  TextField(
                    controller: nameCtl,
                    decoration: const InputDecoration(labelText: 'Nama'),
                  ),
                  TextField(
                    controller: phoneCtl,
                    decoration: const InputDecoration(
                      labelText: 'Nomor Telepon',
                    ),
                    keyboardType: TextInputType.phone,
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
                  final name = nameCtl.text.trim();
                  final phoneNumber = phoneCtl.text.trim();

                  if (address.isEmpty || name.isEmpty || phoneNumber.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Alamat, nama, dan nomor telepon harus diisi',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  // ambil user info
                  final auth = Provider.of<AuthService>(context, listen: false);
                  final uid = auth.currentUser?.uid ?? '';
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
                      status: 'pending',
                      pickupDate: selectedDate,
                      name: name,
                      phoneNumber: phoneNumber,
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

                  // 3) untuk alur baru: tanpa pembayaran di awal
                  //    cukup simpan dan tampilkan jadwal penjemputan
                  Navigator.of(ctx).pop();
                  if (!mounted) return;
                  showAppSnackBar(
                    context,
                    'Pesanan disimpan. Menunggu driver menerima.',
                    type: AlertType.success,
                  );
                },
                child: const Text('Simpan'),
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
    required String name,
    required String phoneNumber,
    String status = 'pending',
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
        name: name,
        phoneNumber: phoneNumber,
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

  Future<void> _handlePayment() async {
    if (_activeOrderId == null || _activeOrderData == null) return;

    final orderId = _activeOrderId!;
    final price = (_activeOrderData!['price'] ?? 0).toDouble();
    final name = _activeOrderData!['name'] as String? ?? '';
    final auth = Provider.of<AuthService>(context, listen: false);
    final email = auth.currentUser?.email ?? 'user@example.com';

    try {
      final snapUrl = await getMidtransSnapUrl(
        orderId: orderId,
        grossAmount: price.toInt(),
        name: name,
        email: email,
      );

      if (snapUrl != null) {
        final result = await Navigator.of(context).push<Map<String, dynamic>>(
          MaterialPageRoute(
            builder: (_) =>
                MidtransPaymentWebView(snapUrl: snapUrl, orderId: orderId),
          ),
        );

        if (result?['status'] == 'success') {
          // Update to pickup_validation (safe duplicate of WebView change)
          await firestore.FirebaseFirestore.instance
              .collection('orders')
              .doc(orderId)
              .update({
                'payment_status': 'success',
                'status': 'pickup_validation',
              });

          showAppSnackBar(
            context,
            'Pembayaran berhasil!',
            type: AlertType.success,
          );
        } else {
          showAppSnackBar(
            context,
            'Pembayaran dibatalkan.',
            type: AlertType.info,
          );
        }
      } else {
        showAppSnackBar(
          context,
          'Gagal memulai pembayaran.',
          type: AlertType.error,
        );
      }
    } catch (e) {
      showAppSnackBar(context, 'Error: $e', type: AlertType.error);
    }
  }

  Future<void> _handleConfirmation() async {
    if (_activeOrderId == null) return;

    final orderId = _activeOrderId!;

    try {
      await firestore.FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({'status': 'user_confirmed_pickup'});

      showAppSnackBar(
        context,
        'Order dikonfirmasi selesai!',
        type: AlertType.success,
      );

      setState(() {
        _activeOrderId = null;
        _activeOrderData = null;
      });
    } catch (e) {
      showAppSnackBar(
        context,
        'Gagal mengkonfirmasi: $e',
        type: AlertType.error,
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
        automaticallyImplyLeading: false,
        centerTitle: true,
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
      floatingActionButton: _selectedIndex == 0 ? _buildDynamicFab() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
    final List<Widget> children = [
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
    ];

    // Add menu items
    for (final item in menuItems) {
      children.add(
        Padding(
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
              } else if (item['title'] == 'Edukasi Daur Ulang') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EdukasiScreen()),
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
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Expanded(child: ListView(children: children))],
      ),
    );
  }

  // Floating/Dynamic Button: selalu tampil 'Buat Order', tambah 'Orderan Aktif' jika ada order aktif
  Widget _buildDynamicFab() {
    final auth = Provider.of<AuthService>(context, listen: false);
    final uid = auth.currentUser?.uid;
    final createBtn = Expanded(
      child: ElevatedButton.icon(
        onPressed: _startCreateOrderFlow,
        icon: const Icon(Icons.add_location_alt, color: Colors.white),
        label: const Text(
          'Buat Order',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontFamily: 'Poppins',
            fontSize: 16,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 13, 214, 23),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
    if (uid == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(children: [createBtn]),
      );
    }

    // Status yang dianggap aktif/processing di sisi user
    const activeStatuses = [
      'active',
      'awaiting_confirmation',
      'waiting_payment',
      'pickup_validation',
      'arrived',
      'waiting_user_validation',
      'picked_up',
    ];

    return StreamBuilder<firestore.QuerySnapshot<Map<String, dynamic>>>(
      stream: firestore.FirebaseFirestore.instance
          .collection('orders')
          .where('user_id', isEqualTo: uid)
          .where('archived', isEqualTo: false)
          .where('status', whereIn: activeStatuses)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        final hasActive = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
        Widget? activeBtn;
        if (hasActive) {
          final orderId = snapshot.data!.docs.first.id;
          activeBtn = Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        OrderRoomScreen(orderId: orderId, role: 'user'),
                  ),
                );
              },
              icon: const Icon(Icons.assignment, color: Colors.white),
              label: const Text(
                'Orderan Aktif',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              createBtn,
              if (activeBtn != null) const SizedBox(width: 12),
              if (activeBtn != null) activeBtn,
            ],
          ),
        );
      },
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

class _ActiveOrderCard extends StatelessWidget {
  final Map<String, dynamic> orderData;
  final String orderId;
  final VoidCallback onChatPressed;
  final VoidCallback? onPayPressed;
  final VoidCallback? onConfirmPressed;

  const _ActiveOrderCard({
    required this.orderData,
    required this.orderId,
    required this.onChatPressed,
    this.onPayPressed,
    this.onConfirmPressed,
  });

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Menunggu Driver';
      case 'active':
        return 'Driver Ditemukan';
      case 'awaiting_confirmation':
        return 'Menunggu Konfirmasi Berat';
      case 'waiting_payment':
        return 'Menunggu Pembayaran';
      case 'pickup_validation':
        return 'Validasi Penjemputan';
      case 'completed':
        return 'Selesai';
      default:
        return 'Status Tidak Dikenal';
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = orderData['status'] as String? ?? '';
    final weight = (orderData['weight'] ?? 0).toDouble();
    final price = (orderData['price'] ?? 0).toDouble();
    final address = orderData['address'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha((0.2 * 255).round()),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping, color: Colors.green[700]),
              const SizedBox(width: 8),
              Text(
                'Pesanan Aktif',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Status: ${_getStatusText(status)}',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            'Berat: ${weight.toStringAsFixed(1)} kg',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            'Harga: Rp ${price.toStringAsFixed(0)}',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            'Alamat: $address',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onChatPressed,
                  icon: const Icon(Icons.chat, color: Colors.white),
                  label: const Text('Chat dengan Driver'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              if (onPayPressed != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onPayPressed,
                    icon: const Icon(Icons.payment, color: Colors.white),
                    label: const Text('Bayar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ] else if (status == 'pickup_validation' &&
                  (orderData['pickup_confirmed'] ?? false) == true &&
                  onConfirmPressed != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onConfirmPressed,
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text('Konfirmasi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
