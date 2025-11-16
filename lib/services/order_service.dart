// =============================
// order_service.dart (FINAL)
// =============================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class OrderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final uuid = Uuid();

  // ================================================================
  // 1. Create Order (User membuat pesanan)
  // ================================================================
  Future<String> createOrder({
    required String userId,
    required double weight,
    required double distance,
    required double price,
    required String address,
    required GeoPoint location,
    required List<String> photoUrls,
  }) async {
    final orderId = uuid.v4();
    final now = FieldValue.serverTimestamp();

    final data = {
      "order_id": orderId,
      "user_id": userId,
      "driver_id": null,
      "status": "waiting",
      "weight": weight,
      "distance": distance,
      "price": price,
      'price_paid': price,
      "address": address,
      "location": location,
      "photo_urls": photoUrls,
      "created_at": now,
      "updated_at": now,
      "archived": false,
    };

    // Gunakan batch agar atomic dan konsisten
    final batch = _db.batch();
    final orderRef = _db.collection('orders').doc(orderId);
    final historyRef = _db.collection('order_history').doc(orderId);

    batch.set(orderRef, data);
    batch.set(historyRef, {...data, "archived_at": null, "completed_at": null});

    await batch.commit();
    return orderId;
  }

  // ================================================================
  // 2. Driver menerima pesanan (atomic)
  // ================================================================
  Future<bool> acceptOrder(String orderId, String driverId) async {
    final orderRef = _db.collection('orders').doc(orderId);
    final historyRef = _db.collection('order_history').doc(orderId);

    try {
      return await _db.runTransaction<bool>((tx) async {
        final snap = await tx.get(orderRef);

        if (!snap.exists) return false;

        final status = snap.data()?['status'] ?? "";
        if (status != "waiting") return false; // Sudah diambil orang lain

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
  // 3. Update status order (on_the_way, arrived, completed, dll)
  // ================================================================
  Future<void> updateStatus(String orderId, String newStatus) async {
    final orderRef = _db.collection('orders').doc(orderId);
    final historyRef = _db.collection('order_history').doc(orderId);

    final now = FieldValue.serverTimestamp();

    // Ambil data order lengkap
    final fullData = await _getFullOrderData(orderId);

    final update = {"status": newStatus, "updated_at": now};

    if (newStatus == "completed") {
      update["completed_at"] = now;
    }

    final mergedData = {...fullData, ...update};

    final batch = _db.batch();
    batch.update(orderRef, update);
    batch.set(historyRef, mergedData, SetOptions(merge: true));
    await batch.commit();

    if (newStatus == "completed") {
      await _archiveOrder(orderId);
    }
  }

  // ================================================================
  // 4. Tambah foto penyelesaian (driver)
  // ================================================================
  Future<void> addCompletionPhoto(String orderId, String photoUrl) async {
    final fullData = await _getFullOrderData(orderId);

    final update = {
      "photo_urls": FieldValue.arrayUnion([photoUrl]),
      "status": "completed",
      "completed_at": FieldValue.serverTimestamp(),
      "updated_at": FieldValue.serverTimestamp(),
    };

    final mergedData = {...fullData, ...update};

    final batch = _db.batch();
    batch.update(_db.collection('orders').doc(orderId), update);
    batch.set(
      _db.collection('order_history').doc(orderId),
      mergedData,
      SetOptions(merge: true),
    );
    await batch.commit();

    await _archiveOrder(orderId);
  }

  // ================================================================
  // 5. Arsip otomatis (dipanggil setelah completed)
  // ================================================================
  Future<void> _archiveOrder(String orderId) async {
    final orderRef = _db.collection('orders').doc(orderId);
    final historyRef = _db.collection('order_history').doc(orderId);

    final snap = await orderRef.get();
    if (!snap.exists) return;

    final data = Map<String, dynamic>.from(snap.data() ?? {});

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
  // 6. Stream khusus untuk driver (order waiting terdekat)
  // ================================================================
  Stream<QuerySnapshot> driverOrders() {
    return _db
        .collection('orders')
        .where("status", isEqualTo: "waiting")
        .snapshots();
  }

  Future<Map<String, dynamic>> _getFullOrderData(String orderId) async {
    final doc = await _db.collection("orders").doc(orderId).get();
    return Map<String, dynamic>.from(doc.data() ?? {});
  }
}
