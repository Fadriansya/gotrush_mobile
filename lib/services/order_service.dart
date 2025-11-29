import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class OrderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ================================================================
  // 1. CREATE ORDER (untuk pending_payment sebelum Snap dibuka)
  // ================================================================
  Future<void> createOrder({
    required String orderId, // <-- DITAMBAHKAN
    required String userId,
    required double weight,
    required double distance,
    required double price,
    required String address,
    required GeoPoint location,
    required List<String> photoUrls,
    required String status, // pending_payment
  }) async {
    final now = FieldValue.serverTimestamp();

    final data = {
      "order_id": orderId,
      "user_id": userId,
      "driver_id": null,
      "status": status, // pending_payment
      "weight": weight,
      "distance": distance,
      "price": price,
      "price_paid": price,
      "address": address,
      "location": location,
      "photo_urls": photoUrls,
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
  // 2. DRIVER MENERIMA PESANAN
  // ================================================================
  Future<bool> acceptOrder(String orderId, String driverId) async {
    final orderRef = _db.collection('orders').doc(orderId);
    final historyRef = _db.collection('order_history').doc(orderId);

    try {
      return await _db.runTransaction<bool>((tx) async {
        final snap = await tx.get(orderRef);
        if (!snap.exists) return false;

        final status = snap.data()?['status'] ?? "";
        if (status != "waiting") return false; // sudah diambil orang lain

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
  // 4. TAMBAH FOTO SELESAI OLEH DRIVER
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
  // 5. ARSIP OTOMATIS
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
  // 6. STREAM UNTUK DRIVER (ORDER WAITING)
  // ================================================================
  Stream<QuerySnapshot> driverOrders() {
    return _db
        .collection('orders')
        .where("status", isEqualTo: "waiting")
        .snapshots();
  }

  // ================================================================
  // HELPER: AMBIL DATA ORDER LENGKAP
  // ================================================================
  Future<Map<String, dynamic>> _getFullOrderData(String orderId) async {
    final doc = await _db.collection("orders").doc(orderId).get();
    return Map<String, dynamic>.from(doc.data() ?? {});
  }
}
