// order_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class OrderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
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
    required String name,
    required String phoneNumber,
  }) async {
    // Ambil timestamp dari server Firestore, lebih akurat daripada dari device.
    final now = FieldValue.serverTimestamp();

    final data = {
      "order_id": orderId,
      "user_id": userId,
      "driver_id": null,
      // status utama (diberi dari caller)
      "status": status,
      // payment_status: gunakan 'pending' saat create; setelah pembayaran berhasil,
      // set ke 'success' dan ubah status order ke 'pickup_validation'
      // (lihat method markPaymentSuccessToPickupValidation)
      "payment_status": "pending",
      "weight": weight,
      "distance": distance,
      "price": price,
      "price_paid": price,
      "address": address,
      "location": location,
      "photo_urls": photoUrls,
      "pickup_date": pickupDate != null
          ? Timestamp.fromDate(pickupDate)
          : FieldValue.serverTimestamp(),
      "created_at": now,
      "updated_at": now,
      "archived": false,
      "name": name,
      "phone_number": phoneNumber,
      "hidden_by_user": false,
      "hidden_by_driver": false,
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
  //    Driver hanya dapat menerima order dengan status 'pending'
  // ================================================================
  Future<bool> acceptOrder(String orderId, String driverId) async {
    final orderRef = _db.collection('orders').doc(orderId);
    final historyRef = _db.collection('order_history').doc(orderId);

    // statuses yang diizinkan untuk diterima oleh driver
    final List<String> allowedAcceptStatuses = ['pending'];

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
          "status": "active",
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
      update["timestamp_end"] = now; // tambahan untuk konsistensi mapping
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
  //    Default: driver melihat status yang diberikan (default ['pending'])
  // ================================================================
  Stream<QuerySnapshot> driverOrders({List<String>? statuses}) {
    final List<String> visible = statuses ?? ['pending'];
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

  // ================================================================
  // 8. DRIVER MENGAJUKAN BERAT (Weight Verification)
  //    - Set status -> 'awaiting_confirmation'
  //    - Simpan driver_weight & tandai konfirmasi pending
  // ================================================================
  Future<void> proposeWeight({
    required String orderId,
    required String driverId,
    required double weight,
  }) async {
    final ref = _db.collection('orders').doc(orderId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      if ((data['driver_id'] ?? '') != driverId) {
        throw Exception('Driver tidak berhak mengubah order ini');
      }
      tx.update(ref, {
        'driver_weight': weight,
        'weight_status': 'proposed', // 'proposed' | 'approved' | 'disputed'
        'weight_proposed_at': FieldValue.serverTimestamp(),
        'status': 'awaiting_confirmation',
        'updated_at': FieldValue.serverTimestamp(),
      });
    });
  }

  // ================================================================
  // 9. USER SETUJU BERAT
  //    - Set status -> 'waiting_payment'
  //    - Finalize final_weight
  // ================================================================
  Future<void> confirmWeightByUser({
    required String orderId,
    required String userId,
  }) async {
    final ref = _db.collection('orders').doc(orderId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      if ((data['user_id'] ?? '') != userId) {
        throw Exception('User tidak berhak pada order ini');
      }
      final driverWeight = (data['driver_weight'] ?? 0).toDouble();
      // Recalculate price dynamically using simple constants
      const double pricePerKm = 2000;
      const double pricePerKg = 2000;
      final distance = (data['distance'] ?? 0).toDouble();
      final newPrice = (distance * pricePerKm) + (driverWeight * pricePerKg);
      tx.update(ref, {
        'final_weight': driverWeight,
        'price': newPrice,
        'price_paid': newPrice,
        'weight_status': 'approved',
        'status': 'waiting_payment',
        'updated_at': FieldValue.serverTimestamp(),
      });
    });
  }

  // ================================================================
  // 10. USER SANGGAH BERAT
  //     - Kembali ke status 'active' dan tandai 'disputed'
  // ================================================================
  Future<void> disputeWeightByUser({
    required String orderId,
    required String userId,
    String? note,
  }) async {
    final ref = _db.collection('orders').doc(orderId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      if ((data['user_id'] ?? '') != userId) {
        throw Exception('User tidak berhak pada order ini');
      }
      final update = {
        'weight_status': 'disputed',
        'status': 'active',
        'updated_at': FieldValue.serverTimestamp(),
      };
      if (note != null && note.isNotEmpty) {
        update['weight_note'] = note;
      }
      tx.update(ref, update);
    });
  }

  // ================================================================
  // 11. PAYMENT SUCCESS -> PICKUP VALIDATION
  //     - Set payment_status -> 'success'
  //     - Set status -> 'pickup_validation'
  // ================================================================
  Future<void> markPaymentSuccessToPickupValidation({
    required String orderId,
  }) async {
    final ref = _db.collection('orders').doc(orderId);
    await ref.update({
      'payment_status': 'success',
      'status': 'pickup_validation',
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  // ================================================================
  // 12. DRIVER CONFIRM PICKUP
  //     - Only the assigned driver can set pickup_confirmed = true
  // ================================================================
  Future<void> driverConfirmPickup({
    required String orderId,
    required String driverId,
  }) async {
    final ref = _db.collection('orders').doc(orderId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      if ((data['driver_id'] ?? '') != driverId) {
        throw Exception('Driver tidak berhak mengubah order ini');
      }
      // Alur baru: setelah driver konfirmasi ambil, minta validasi user
      tx.update(ref, {
        'status': 'waiting_user_validation',
        'pickup_requested_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    });
  }

  // ================================================================
  // 13. DRIVER RESET PICKUP CONFIRMATION
  // ================================================================
  Future<void> driverResetPickupConfirmation({
    required String orderId,
    required String driverId,
  }) async {
    final ref = _db.collection('orders').doc(orderId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      if ((data['driver_id'] ?? '') != driverId) {
        throw Exception('Driver tidak berhak mengubah order ini');
      }
      // Alur baru: kembali ke status 'arrived' agar driver dapat ulang konfirmasi
      tx.update(ref, {
        'status': 'arrived',
        'updated_at': FieldValue.serverTimestamp(),
      });
    });
  }

  // ================================================================
  // 14. USER FINAL VALIDATION
  //     - If confirmed: status -> 'completed' with server timestamp
  //     - If not: reset pickup_confirmed -> false
  // ================================================================
  // Alur baru: validasi user terhadap pengambilan
  // - Jika confirmed==true -> status 'picked_up'
  // - Jika confirmed==false -> kembali ke 'arrived'
  Future<void> userRespondPickupValidation({
    required String orderId,
    required String userId,
    required bool confirmed,
  }) async {
    final ref = _db.collection('orders').doc(orderId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      if ((data['user_id'] ?? '') != userId) {
        throw Exception('User tidak berhak pada order ini');
      }
      if (confirmed) {
        tx.update(ref, {
          'status': 'picked_up',
          'picked_up_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      } else {
        tx.update(ref, {
          'status': 'arrived',
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // Tambahan: driver menandai telah tiba di lokasi
  Future<void> driverArrived({
    required String orderId,
    required String driverId,
  }) async {
    final ref = _db.collection('orders').doc(orderId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      if ((data['driver_id'] ?? '') != driverId) {
        throw Exception('Driver tidak berhak mengubah order ini');
      }
      tx.update(ref, {
        'status': 'arrived',
        'arrived_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    });
  }

  // Tambahan: driver menyelesaikan order setelah user menyatakan 'Ya/picked_up'
  Future<void> driverCompleteOrder({
    required String orderId,
    required String driverId,
  }) async {
    final ref = _db.collection('orders').doc(orderId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      if ((data['driver_id'] ?? '') != driverId) {
        throw Exception('Driver tidak berhak mengubah order ini');
      }
      tx.update(ref, {
        'status': 'completed',
        'completed_at': FieldValue.serverTimestamp(),
        'timestamp_end': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'hidden_by_user': false,
        'hidden_by_driver': false,
      });
    });
    await _archiveOrder(orderId);
  }

  // ================================================================
  // 8. STREAM — ORDER DRIVER HARI INI (SOURCE OF TRUTH)
  // ================================================================
  Stream<QuerySnapshot> driverTodayOrders({List<String>? statuses}) {
    // Show only new, unassigned orders for today.
    final List<String> visible = statuses ?? ['pending'];

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _db
        .collection('orders')
        .where('status', whereIn: visible)
        .where('driver_id', isNull: true)
        .where(
          'pickup_date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('pickup_date', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots();
  }
}
