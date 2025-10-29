import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class DriverLocationService {
  final String driverId;
  StreamSubscription<Position>? _sub;

  DriverLocationService(this.driverId);

  Future<void> start() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw Exception('Location services disabled');

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw Exception('Location permission denied');
      }
    }

    _sub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 10,
          ),
        ).listen((pos) async {
          final data = {
            'location': GeoPoint(pos.latitude, pos.longitude),
            'heading': pos.heading,
            'speed': pos.speed,
            'updatedAt': FieldValue.serverTimestamp(),
          };
          await FirebaseFirestore.instance
              .collection('drivers')
              .doc(driverId)
              .set(data, SetOptions(merge: true));
        });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }
}
