import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../profile_screen.dart';
import '../../services/order_service.dart';
import '../order_history_widget.dart';
import '../../utils/alerts.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  int _selectedIndex = 0;
  StreamSubscription<QuerySnapshot>? _orderSub;
  String? _lastOrderId;
  String? _lastOrderStatus;
  bool _dialogOpen = false; // guard untuk mencegah dialog tumpuk
  DateTime? _lastNotifyAt;
  String? _lastNotifiedOrderId;

  final List<Widget> _pages = [
    const _BerandaPage(),
    const _RiwayatPage(),
    const _ProfilPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    // Subscribe langsung di initState tanpa postFrameCallback. Menggunakan
    // Provider.of(context, listen: false) aman di initState.
    final auth = Provider.of<AuthService>(context, listen: false);
    final uid = auth.currentUser?.uid;
    if (uid != null) {
      _orderSub = FirebaseFirestore.instance
          .collection('orders')
          .where('user_id', isEqualTo: uid)
          .orderBy('created_at', descending: true)
          .limit(1)
          .snapshots()
          .listen(
            (snap) {
              if (snap.docs.isEmpty) return;
              final doc = snap.docs.first;
              final id = doc.id;
              final data = doc.data();
              final status = (data['status'] as String?) ?? '';
              if (_lastOrderId != id || _lastOrderStatus != status) {
                _lastOrderId = id;
                _lastOrderStatus = status;
                _handleStatusChange(
                  id,
                  status,
                  Map<String, dynamic>.from(data),
                );
              }
            },
            onError: (e) {
              debugPrint('Order subscription error: $e');
            },
          );
    }
  }

  @override
  void dispose() {
    _orderSub?.cancel();
    super.dispose();
  }

  void _handleStatusChange(
    String orderId,
    String status,
    Map<String, dynamic> data,
  ) {
    if (!mounted) return;

    // Debounce: jangan tampilkan notifikasi/dialog lebih sering dari 3 detik
    final now = DateTime.now();
    if (_lastNotifyAt != null && _lastNotifiedOrderId == orderId) {
      final diff = now.difference(_lastNotifyAt!);
      if (diff < const Duration(seconds: 3)) {
        // terlalu cepat, abaikan
        return;
      }
    }
    _lastNotifyAt = now;
    _lastNotifiedOrderId = orderId;

    // Jika sudah ada dialog terbuka, jangan buka dialog baru (mencegah freeze karena
    // dialog menumpuk). Untuk snackbars tidak perlu guard karena mereka tidak
    // mem-block UI seperti dialog.
    if (status == 'accepted') {
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
    } else if (status == 'on_the_way') {
      showAppSnackBar(
        context,
        'Driver sedang menuju lokasi Anda',
        type: AlertType.info,
      );
    } else if (status == 'arrived') {
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
    } else if (status == 'completed') {
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
    }
  }

  @override
  Widget build(BuildContext context) {
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
        elevation: 2,
      ),
      body: _pages[_selectedIndex],
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateOrderDialog(context),
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

  void _showCreateOrderDialog(BuildContext context) {
    final addressCtl = TextEditingController();
    final weightCtl = TextEditingController();
    final priceCtl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setStateDialog) {
          return AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.add_location_alt, color: Colors.green),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Buat Order Penjemputan',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
                    controller: weightCtl,
                    decoration: const InputDecoration(labelText: 'Berat (kg)'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: priceCtl,
                    decoration: const InputDecoration(labelText: 'Harga (IDR)'),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final auth = Provider.of<AuthService>(context, listen: false);
                  final uid = auth.currentUser?.uid;
                  if (uid == null) return;

                  final address = addressCtl.text.trim();
                  if (address.isEmpty) {
                    showAppSnackBar(
                      context,
                      'Alamat harus diisi',
                      type: AlertType.error,
                    );
                    return;
                  }
                  final weight = double.tryParse(weightCtl.text) ?? 0.0;
                  final price = double.tryParse(priceCtl.text) ?? 0.0;

                  // capture messenger & theme and close dialog before awaiting
                  // to avoid using BuildContext across async gaps
                  final messenger = ScaffoldMessenger.of(context);
                  final theme = Theme.of(context);
                  Navigator.of(ctx).pop();
                  try {
                    // for demo: use a dummy location
                    final location = GeoPoint(0, 0);
                    final orderSvc = OrderService();
                    final id = await orderSvc.createOrder(
                      userId: uid,
                      weight: weight,
                      distance: 0.0,
                      price: price,
                      address: address,
                      location: location,
                      photoUrls: [],
                    );
                    if (mounted) {
                      messenger.showSnackBar(
                        buildAppSnackBarFromTheme(
                          theme,
                          'Order dibuat: $id',
                          type: AlertType.success,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      messenger.showSnackBar(
                        buildAppSnackBarFromTheme(
                          theme,
                          'Gagal membuat order: $e',
                          type: AlertType.error,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Buat'),
              ),
            ],
          );
        },
      ),
    );
  }
}

//
// ─── BERANDA ──────────────────────────────────────────────────────
//
class _BerandaPage extends StatelessWidget {
  const _BerandaPage();

  @override
  Widget build(BuildContext context) {
    final menuItems = [
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
                      showAppSnackBar(
                        context,
                        'Navigasi ke ${item['title']}',
                        type: AlertType.info,
                      );
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
}

//
// ─── RIWAYAT ─────────────────────────────────────────────────────
//
class _RiwayatPage extends StatelessWidget {
  const _RiwayatPage();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(8.0),
      child: OrderHistoryWidget(),
    );
  }
}

//
// ─── PROFIL ──────────────────────────────────────────────────────
//
class _ProfilPage extends StatelessWidget {
  const _ProfilPage();

  @override
  Widget build(BuildContext context) {
    return const ProfileScreen(role: 'user');
  }
}

//
// ─── MENU CARD ───────────────────────────────────────────────────
//
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
