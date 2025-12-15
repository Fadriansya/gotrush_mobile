// order_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    case 'on_the_way':
      return Colors.blue;
    case 'cancelled':
      return Colors.red;
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

class OrderDetailScreen extends StatelessWidget {
  final Map<String, dynamic> order;
  final String orderId;

  const OrderDetailScreen({
    super.key,
    required this.order,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context) {
    final String status = order["status"]?.toString() ?? "N/A";
    final Color statusColor = _getStatusColor(status);

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
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

          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildSummaryCard(),
                    const SizedBox(height: 24),
                    _buildInfoSection(),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  /// ================================
  /// STATUS BADGE
  /// ================================
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

  /// ================================
  /// SUMMARY CARD (Harga, Berat, Jarak)
  /// ================================
  Widget _buildSummaryCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _summaryItem(
              icon: Icons.monetization_on_outlined,
              title: "Harga",
              value: "Rp ${order["price"] ?? 0}",
              iconColor: Colors.blueAccent,
            ),
            Container(width: 1, height: 50, color: Colors.grey[200]),
            _summaryItem(
              icon: Icons.fitness_center,
              title: "Berat",
              value: "${order["weight"] ?? 0} kg",
              iconColor: Colors.orangeAccent,
            ),
            Container(width: 1, height: 50, color: Colors.grey[200]),
            _summaryItem(
              icon: Icons.route,
              title: "Jarak",
              value: "${order["distance"] ?? 'N/A'} km",
              iconColor: Colors.redAccent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem({
    required IconData icon,
    required String title,
    required String value,
    required Color iconColor,
  }) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 28),
        const SizedBox(height: 4),
        Text(
          title,
          style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// ================================
  /// DETAIL ITEM LIST
  /// ================================
  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Judul Bagian
        Text(
          "Detail Informasi",
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Column(
              children: [
                _infoItem(
                  Icons.receipt_long,
                  "ID Pesanan",
                  orderId,
                  showDivider: true,
                ),
                _infoItem(Icons.location_on, "Alamat", order["address"]),
                _infoItem(
                  Icons.person_outline,
                  "Nama Pelanggan",
                  order["name"],
                  showDivider: true,
                ),
                _infoItem(
                  Icons.call_outlined,
                  "Telepon",
                  order["phone_number"],
                  showDivider: true,
                ),
                _infoItem(
                  Icons.calendar_today,
                  "Tanggal Pickup",
                  _formatDate(order["pickup_date"]),
                  showDivider: true,
                ),
                _infoItem(
                  Icons.access_time_outlined,
                  "Dibuat Pada",
                  order["created_at"] != null
                      ? _formatDate(order["created_at"])
                      : "-",
                  showDivider: true,
                ),
                _infoItem(
                  Icons.tag_outlined,
                  "Pemesan",
                  order["name"],
                  showDivider: true,
                ),
                _infoItem(
                  Icons.motorcycle_outlined,
                  "Driver ID",
                  order["driver_id"],
                  showDivider: false,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoItem(
    IconData icon,
    String label,
    dynamic rawValue, {
    bool showDivider = true,
  }) {
    final value = rawValue?.toString() ?? "Belum tersedia";

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 24,
                color: label == "ID Pesanan"
                    ? Colors.blueGrey.shade700
                    : Colors.blueGrey,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: label == "ID Pesanan"
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1, thickness: 0.8, indent: 40),
      ],
    );
  }

  List<Widget> _buildAppBarActions(BuildContext context, String status) {
    // Show chat button for accepted, on_the_way, arrived, completed statuses
    final chatStatuses = ['accepted', 'on_the_way', 'arrived', 'completed'];
    if (!chatStatuses.contains(status.toLowerCase())) {
      return [];
    }

    return [
      IconButton(
        icon: const Icon(Icons.chat, color: Colors.white),
        onPressed: () => _openChat(context),
        tooltip: 'Chat',
      ),
    ];
  }

  void _openChat(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    final currentUserRole = order['user_id'] == currentUser.uid
        ? 'user'
        : 'driver';
    final otherUserName = currentUserRole == 'user'
        ? 'Driver'
        : (order['name'] as String?) ?? 'Pelanggan';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          orderId: orderId,
          otherUserName: otherUserName,
          currentUserRole: currentUserRole,
        ),
      ),
    );
  }

  String _formatDate(dynamic value) {
    if (value == null) return "-";

    if (value is Timestamp) {
      final date = value.toDate();
      final year = date.year;
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return "$day/$month/$year $hour:$minute";
    }

    if (value is String) return value;

    return "-";
  }
}
