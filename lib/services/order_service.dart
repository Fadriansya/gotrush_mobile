// order_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// Kelas utama, ibarat 'tukang pos' yang ngirim/ambil data order ke/dari Firestore
class OrderService {
  // Bikin instance (objek) koneksi ke database Firestore, biar gampang dipanggil
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ================================================================
  // 1. CREATE ORDER — status awal diserahkan caller, namun payment_status default 'pending'
  // ================================================================
  // Fungsi buat bikin order baru. Parameternya lumayan banyak, semuanya (required).
  Future<void> createOrder({
    required String orderId,
    required String userId,
    required double weight,
    required double distance,
    required double price,
    required String address,
    required GeoPoint location,
    required List<String> photoUrls,
    required String status,
    DateTime? pickupDate,
  }) async {
    // Ambil timestamp dari server Firestore, lebih akurat daripada dari device.
    final now = FieldValue.serverTimestamp();

    final data = {
      "order_id": orderId,
      "user_id": userId,
      "driver_id": null,
      // status utama (diberi dari caller)
      "status": status,
      // payment_status: gunakan 'pending' pada create; update jadi 'payment_success' saat webhook/Flutter men-set
      "payment_status": "pending",
      "weight": weight,
      "distance": distance,
      "price": price,
      "price_paid": price,
      "address": address,
      "location": location,
      "photo_urls": photoUrls,
      "pickup_date": pickupDate != null ? Timestamp.fromDate(pickupDate) : null,
      "created_at": now,
      "updated_at": now,
      "archived": false,
    };

    final batch = _db.batch();
    final orderRef = _db.collection('orders').doc(orderId);
    final historyRef = _db.collection('order_history').doc(orderId);

    batch.set(orderRef, data);
    batch.set(historyRef, {...data, "archived_at": null, "completed_at": null});

    await batch.commit();
  }

  // ================================================================
  // 2. DRIVER MENERIMA PESANAN (transaction-safe)
  //    Sekarang menerima order dengan status tertentu (mis. waiting, payment_success)
  // ================================================================
  Future<bool> acceptOrder(String orderId, String driverId) async {
    final orderRef = _db.collection('orders').doc(orderId);
    final historyRef = _db.collection('order_history').doc(orderId);

    // statuses yang diizinkan untuk diterima oleh driver
    final List<String> allowedAcceptStatuses = ['waiting', 'payment_success'];

    try {
      return await _db.runTransaction<bool>((tx) async {
        final snap = await tx.get(orderRef);
        if (!snap.exists) return false;

        final status = (snap.data()?['status'] ?? "").toString();
        // jika status bukan di daftar yang diizinkan, return false
        if (!allowedAcceptStatuses.contains(status)) {
          debugPrint(
            "acceptOrder: status '$status' not allowed for acceptance",
          );
          return false;
        }

        final update = {
          "driver_id": driverId,
          "status": "accepted",
          "accepted_at": FieldValue.serverTimestamp(),
          "updated_at": FieldValue.serverTimestamp(),
        };

        tx.update(orderRef, update);
        tx.set(historyRef, update, SetOptions(merge: true));

        return true;
      });
    } catch (e) {
      debugPrint("🔥 acceptOrder error: $e");
      return false;
    }
  }

  // ================================================================
  // 3. UPDATE STATUS ORDER
  // ================================================================
  Future<void> updateStatus(String orderId, String newStatus) async {
    final orderRef = _db.collection('orders').doc(orderId);
    final historyRef = _db.collection('order_history').doc(orderId);

    final now = FieldValue.serverTimestamp();
    final fullData = await _getFullOrderData(orderId);

    final update = {"status": newStatus, "updated_at": now};

    if (newStatus == "completed") {
      update["completed_at"] = now;
    }

    final merged = {...fullData, ...update};

    final batch = _db.batch();
    batch.update(orderRef, update);
    batch.set(historyRef, merged, SetOptions(merge: true));
    await batch.commit();

    if (newStatus == "completed") {
      await _archiveOrder(orderId);
    }
  }

  // ================================================================
  // 4. DRIVER TAMBAH FOTO SELESAI
  // ================================================================
  Future<void> addCompletionPhoto(String orderId, String photoUrl) async {
    final fullData = await _getFullOrderData(orderId);

    final update = {
      "photo_urls": FieldValue.arrayUnion([photoUrl]),
      "status": "completed",
      "completed_at": FieldValue.serverTimestamp(),
      "updated_at": FieldValue.serverTimestamp(),
    };

    final merged = {...fullData, ...update};

    final batch = _db.batch();
    batch.update(_db.collection('orders').doc(orderId), update);
    batch.set(
      _db.collection('order_history').doc(orderId),
      merged,
      SetOptions(merge: true),
    );
    await batch.commit();

    await _archiveOrder(orderId);
  }

  // ================================================================
  // 5. ARSIP (AUTO)
  // ================================================================
  Future<void> _archiveOrder(String orderId) async {
    final orderRef = _db.collection('orders').doc(orderId);
    final historyRef = _db.collection('order_history').doc(orderId);

    final snap = await orderRef.get();
    if (!snap.exists) return;

    final update = {
      "archived": true,
      "archived_at": FieldValue.serverTimestamp(),
      "updated_at": FieldValue.serverTimestamp(),
    };

    final batch = _db.batch();
    batch.update(orderRef, update);
    batch.set(historyRef, update, SetOptions(merge: true));
    await batch.commit();
  }

  // ================================================================
  // 6. STREAM UNTUK DRIVER — bisa listen multiple statuses (whereIn)
  //    Default: driver melihat order yang sudah dibayar atau waiting
  // ================================================================
  Stream<QuerySnapshot> driverOrders({List<String>? statuses}) {
    final List<String> visible = statuses ?? ['payment_success', 'waiting'];
    // Firestore whereIn supports up to 10 elements
    return _db
        .collection('orders')
        .where("status", whereIn: visible)
        .snapshots();
  }

  // ================================================================
  // 7. HELPER — AMBIL DATA ORDER
  // ================================================================
  Future<Map<String, dynamic>> _getFullOrderData(String orderId) async {
    final doc = await _db.collection("orders").doc(orderId).get();
    return Map<String, dynamic>.from(doc.data() ?? {});
  }
}
