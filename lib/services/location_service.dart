import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  final _firestore = FirebaseFirestore.instance;

  Future<void> updateDriverLocation(
    String driverId,
    Position position, {
    String? orderId,
  }) async {
    await _firestore.collection('drivers_location').doc(driverId).set({
      'lat': position.latitude,
      'lng': position.longitude,
      'last_update': FieldValue.serverTimestamp(),
      if (orderId != null) 'order_id': orderId,
    }, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot> getDriverLocationStream(String driverId) {
    return _firestore.collection('drivers_location').doc(driverId).snapshots();
  }
}
