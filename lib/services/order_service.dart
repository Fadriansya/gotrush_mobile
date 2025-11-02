import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final uuid = Uuid();

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
    await _firestore.collection('orders').doc(id).set({
      'user_id': userId,
      'driver_id': null,
      'status': 'waiting',
      'weight': weight,
      'distance': distance,
      'price': price,
      'address': address,
      'location': location,
      'photo_urls': photoUrls,
      'created_at': FieldValue.serverTimestamp(),
    });
    return id;
  }

  Stream<QuerySnapshot> listenNearbyOrdersForDriver(
    String driverUid,
    double radiusKm,
    GeoPoint driverLocation,
  ) {
    // For simplicity: listen all waiting orders
    // For production: use geoflutterfire to query by distance
    return _firestore
        .collection('orders')
        .where('status', isEqualTo: 'waiting')
        .snapshots();
  }

  /// Try to accept an order safely using a transaction.
  /// Returns true if accepted successfully, false if the order was not in 'waiting' state.
  Future<bool> acceptOrder(String orderId, String driverId) async {
    final ref = _firestore.collection('orders').doc(orderId);
    try {
      final result = await _firestore.runTransaction<bool>((tx) async {
        final snapshot = await tx.get(ref);
        if (!snapshot.exists) return false;
        final currentStatus = (snapshot.data()?['status'] as String?) ?? '';
        if (currentStatus != 'waiting') {
          // somebody else already accepted or changed the order
          return false;
        }
        tx.update(ref, {
          'driver_id': driverId,
          'status': 'accepted',
          'accepted_at': FieldValue.serverTimestamp(),
        });
        return true;
      });
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

    // If the order is completed, archive it into order_history
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
    // After completing, archive the order to history
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
    final data = snap.data() as Map<String, dynamic>;

    // Prepare history document payload. Include timestamps and all useful fields.

    final history = Map<String, dynamic>.from(data);
    history['archived_at'] = FieldValue.serverTimestamp();
    // Ensure history has a completed_at field so queries ordering by completed_at work
    history['completed_at'] =
        data['completed_at'] ?? FieldValue.serverTimestamp();

    // Try to include readable names to avoid extra reads on the client.
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
      // continue without names
    }

    // write to order_history collection using same id
    await _firestore.collection('order_history').doc(orderId).set(history);

    // mark original order as archived to avoid duplication
    await ref.update({'archived': true});
  }
}
