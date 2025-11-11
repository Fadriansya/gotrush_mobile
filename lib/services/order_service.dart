import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final uuid = Uuid();

  Stream<QuerySnapshot> listenNearbyOrdersForDriver(
    String driverId,
    double radius,
    GeoPoint driverLocation,
  ) {
    return _firestore
        .collection('orders')
        .where('status', isEqualTo: 'waiting')
        .snapshots();
  }

  Future<String> createOrder({
    required String userId,
    required double weight,
    required double distance,
    required double price,
    required String address,
    required GeoPoint location,
    required List<String> photoUrls,
  }) async {
    final id = uuid.v4();
    final now = FieldValue.serverTimestamp();

    final data = {
      'user_id': userId,
      'driver_id': null,
      'status': 'waiting',
      'weight': weight,
      'distance': distance,
      'price': price,
      'address': address,
      'location': location,
      'photo_urls': photoUrls,
      'created_at': now,
    };

    // Simpan ke koleksi utama
    await _firestore.collection('orders').doc(id).set(data);

    // Simpan juga ke order_history agar langsung muncul di riwayat user
    try {
      await _firestore.collection('order_history').doc(id).set({
        ...data,
        'archived_at': now,
        'completed_at': null,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ gagal menyalin order ke order_history: $e');
    }

    return id;
  }

  Future<bool> acceptOrder(String orderId, String driverId) async {
    final ref = _firestore.collection('orders').doc(orderId);

    try {
      final result = await _firestore.runTransaction<bool>((tx) async {
        final snapshot = await tx.get(ref);
        if (!snapshot.exists) return false;
        final currentStatus = (snapshot.data()?['status'] as String?) ?? '';
        if (currentStatus != 'waiting') return false;
        tx.update(ref, {
          'driver_id': driverId,
          'status': 'accepted',
          'accepted_at': FieldValue.serverTimestamp(),
        });
        return true;
      });

      if (result) {
        // Gunakan set(merge:true) agar tidak overwrite data user_id
        await _firestore.collection('order_history').doc(orderId).set({
          'driver_id': driverId,
          'status': 'accepted',
          'accepted_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      return result;
    } catch (e) {
      debugPrint('🔥 acceptOrder transaction error: $e');
      return false;
    }
  }

  Future<void> updateStatus(String orderId, String newStatus) async {
    final Map<String, dynamic> update = {'status': newStatus};
    if (newStatus == 'completed') {
      update['completed_at'] = FieldValue.serverTimestamp();
    }

    await _firestore.collection('orders').doc(orderId).update(update);

    try {
      await _firestore
          .collection('order_history')
          .doc(orderId)
          .set(update, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ gagal update status di order_history: $e');
    }

    if (newStatus == 'completed') {
      try {
        await _archiveOrder(orderId);
      } catch (e) {
        debugPrint('🔥 archiveOrder error: $e');
      }
    }
  }

  Future<void> addCompletionPhoto(String orderId, String photoUrl) async {
    final ref = _firestore.collection('orders').doc(orderId);
    await ref.update({
      'photo_urls': FieldValue.arrayUnion([photoUrl]),
      'status': 'completed',
      'completed_at': FieldValue.serverTimestamp(),
    });

    try {
      await _firestore.collection('order_history').doc(orderId).set({
        'photo_urls': FieldValue.arrayUnion([photoUrl]),
        'status': 'completed',
        'completed_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ gagal sinkron foto ke order_history: $e');
    }

    try {
      await _archiveOrder(orderId);
    } catch (e) {
      debugPrint('🔥 archiveOrder error: $e');
    }
  }

  Future<void> _archiveOrder(String orderId) async {
    final ref = _firestore.collection('orders').doc(orderId);
    final snap = await ref.get();
    if (!snap.exists) return;

    final data = Map<String, dynamic>.from(snap.data() ?? {});
    final history = Map<String, dynamic>.from(data);

    history['archived_at'] = FieldValue.serverTimestamp();
    history['completed_at'] =
        data['completed_at'] ?? FieldValue.serverTimestamp();

    try {
      final userId = data['user_id'] as String?;
      final driverId = data['driver_id'] as String?;
      if (userId != null) {
        final u = await _firestore.collection('users').doc(userId).get();
        history['user_name'] = (u.data()?['name'] as String?) ?? '';
      }
      if (driverId != null) {
        final d = await _firestore.collection('users').doc(driverId).get();
        history['driver_name'] = (d.data()?['name'] as String?) ?? '';
      }
    } catch (e) {
      debugPrint('🔥 failed to fetch user/driver name for history: $e');
    }

    // Aman: merge true agar field penting tidak hilang
    await _firestore
        .collection('order_history')
        .doc(orderId)
        .set(history, SetOptions(merge: true));

    await ref.update({'archived': true});
  }
}
