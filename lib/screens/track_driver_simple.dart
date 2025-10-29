import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/notification_service.dart';

class TrackDriverSimple extends StatefulWidget {
  final String driverId;
  final double userLat;
  final double userLng;

  const TrackDriverSimple({
    super.key,
    required this.driverId,
    required this.userLat,
    required this.userLng,
  });

  @override
  State<TrackDriverSimple> createState() => _TrackDriverSimpleState();
}

class _TrackDriverSimpleState extends State<TrackDriverSimple> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  double? _driverLat;
  double? _driverLng;
  double? _distanceMeters;
  bool _notified = false;

  @override
  void initState() {
    super.initState();
    _sub = FirebaseFirestore.instance
        .collection('drivers')
        .doc(widget.driverId)
        .snapshots()
        .listen((snap) {
          final data = snap.data();
          if (data == null) return;
          final GeoPoint gp = data['location'] as GeoPoint;
          setState(() {
            _driverLat = gp.latitude;
            _driverLng = gp.longitude;
            _distanceMeters = Geolocator.distanceBetween(
              widget.userLat,
              widget.userLng,
              _driverLat!,
              _driverLng!,
            );
          });

          // client-side notification when near (200m)
          if (_distanceMeters != null &&
              _distanceMeters! <= 200 &&
              !_notified) {
            _notified = true;
            NotificationService().showLocal(
              id: 1001,
              title: 'Driver hampir tiba',
              body:
                  'Driver ${widget.driverId} mendekat (${_distanceMeters!.round()} m)',
            );
          }
        });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lacak Driver (Simple)')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Driver ID: ${widget.driverId}'),
            const SizedBox(height: 12),
            if (_driverLat != null && _driverLng != null) ...[
              Text(
                'Posisi driver: ${_driverLat!.toStringAsFixed(6)}, ${_driverLng!.toStringAsFixed(6)}',
              ),
              const SizedBox(height: 8),
              Text(
                'Jarak: ${(_distanceMeters! / 1000).toStringAsFixed(2)} km (${_distanceMeters!.round()} m)',
              ),
            ] else ...[
              const Text('Menunggu posisi driver...'),
            ],
            const Spacer(),
            ElevatedButton(
              onPressed: () async {
                // reset notification flag for testing
                setState(() => _notified = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reset notifikasi')),
                );
              },
              child: const Text('Reset notifikasi'),
            ),
          ],
        ),
      ),
    );
  }
}
