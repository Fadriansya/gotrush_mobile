// order_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'chat_screen.dart';

// Helper untuk mendapatkan warna berdasarkan status
Color _getStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'completed':
      return const Color.fromARGB(255, 0, 172, 6);
    case 'pending':
      return Colors.amber;
    case 'active':
      return Colors.orange;
    case 'awaiting_confirmation':
      return Colors.purple;
    case 'waiting_payment':
      return Colors.blue;
    case 'pickup_validation':
      return Colors.teal;
    default:
      return Colors.grey;
  }
}

// Color Extension yang sudah diperbaiki
extension ColorExtension on Color {
  Color withValues({double? alpha, double? red, double? green, double? blue}) {
    final double finalAlphaDouble = (alpha ?? this.alpha / 255.0) * 255.0;

    return Color.fromARGB(
      finalAlphaDouble.round(),
      red != null ? (red * 255).round() : this.red,
      green != null ? (green * 255).round() : this.green,
      blue != null ? (blue * 255).round() : this.blue,
    );
  }
}

class OrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  final String orderId;
  final int? unreadCount;

  const OrderDetailScreen({
    super.key,
    required this.order,
    required this.orderId,
    this.unreadCount,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Map<String, dynamic> _orderData;
  late int _unreadCount;

  @override
  void initState() {
    super.initState();
    _orderData = widget.order;
    _unreadCount = widget.unreadCount ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.exists) {
            _orderData = snapshot.data!.data()!;
            // Juga update unread count jika ada di meta
            if (snapshot.data!.data()!.containsKey('chat_meta')) {
              final meta =
                  snapshot.data!.get('chat_meta') as Map<String, dynamic>?;
              if (meta != null) {
                final auth = Provider.of<AuthService>(context, listen: false);
                final role = _orderData['user_id'] == auth.currentUser?.uid
                    ? 'user'
                    : 'driver';
                _unreadCount = role == 'user'
                    ? (meta['unread_user'] ?? 0)
                    : (meta['unread_driver'] ?? 0);
              }
            }
          }

          final String status = _orderData["status"]?.toString() ?? "N/A";
          final Color statusColor = _getStatusColor(status);

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 140.0,
                floating: false,
                pinned: true,
                iconTheme: const IconThemeData(color: Colors.white),
                actions: _buildAppBarActions(context, status),
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  title: Text(
                    "Detail Pesanan",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 20,
                    ),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          statusColor.withValues(alpha: 0.8),
                          statusColor.withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [_buildStatusBadge(status)],
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle("Informasi Pengguna"),
                      _buildInfoCard([
                        _buildInfoRow(
                          "Nama",
                          _orderData["name"]?.toString() ?? "N/A",
                        ),
                        _buildInfoRow(
                          "Telepon",
                          _orderData["phone_number"]?.toString() ?? "N/A",
                        ),
                        _buildInfoRow(
                          "Alamat",
                          _orderData["address"]?.toString() ?? "N/A",
                        ),
                      ]),
                      const SizedBox(height: 20),
                      _buildSectionTitle("Detail Sampah"),
                      _buildInfoCard([
                        _buildInfoRow(
                          "Berat Awal",
                          "${_orderData["weight"]?.toStringAsFixed(1) ?? "0"} kg",
                        ),
                        _buildInfoRow(
                          "Berat Final",
                          "${_orderData["driver_weight"]?.toStringAsFixed(1) ?? "0"} kg",
                        ),
                      ]),
                      const SizedBox(height: 20),
                      _buildSectionTitle("Informasi Pembayaran"),
                      _buildInfoCard([
                        _buildInfoRow(
                          "Harga",
                          "Rp ${NumberFormat("#,##0", "id_ID").format(_orderData["price"] ?? 0)}",
                        ),
                        _buildInfoRow(
                          "Status Pembayaran",
                          _orderData["payment_status"]?.toString() ?? "N/A",
                        ),
                      ]),
                      const SizedBox(height: 20),
                      _buildSectionTitle("Informasi Waktu"),
                      _buildInfoCard([
                        _buildInfoRow(
                          "Dibuat",
                          _formatDate(_orderData["created_at"] as Timestamp?),
                        ),
                        _buildInfoRow(
                          "Penjemputan",
                          _formatDate(_orderData["pickup_date"] as Timestamp?),
                        ),
                        _buildInfoRow(
                          "Selesai",
                          _formatDate(_orderData["completed_at"] as Timestamp?),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.poppins(color: Colors.black54, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final statusText = status.toUpperCase();
    final statusColor = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        statusText,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context, String status) {
    final chatStatuses = [
      'active',
      'awaiting_confirmation',
      'waiting_payment',
      'pickup_validation',
      'completed',
    ];
    if (!chatStatuses.contains(status.toLowerCase())) {
      return [];
    }

    Widget chatButton = IconButton(
      icon: const Icon(Icons.chat, color: Colors.white),
      onPressed: () => _openChat(context),
      tooltip: 'Chat',
    );

    if (_unreadCount > 0 && status.toLowerCase() != 'completed') {
      chatButton = Stack(
        clipBehavior: Clip.none,
        children: [
          chatButton,
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                _unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return [chatButton];
  }

  void _openChat(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    final currentUserRole = _orderData['user_id'] == currentUser.uid
        ? 'user'
        : 'driver';
    final otherUserName = currentUserRole == 'user'
        ? 'Driver'
        : (_orderData['name'] as String?) ?? 'Pelanggan';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          orderId: widget.orderId,
          otherUserName: otherUserName,
          currentUserRole: currentUserRole,
        ),
      ),
    );
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return "N/A";
    return DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(ts.toDate());
  }
}
