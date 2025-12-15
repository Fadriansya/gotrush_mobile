// driver_map_tracking_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart' as osm;
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../services/notification_service.dart';
import '../../../services/auth_service.dart';

class DriverMapTrackingScreen extends StatefulWidget {
  final String orderId;
  final firestore.GeoPoint userLocation;

  const DriverMapTrackingScreen({
    super.key,
    required this.orderId,
    required this.userLocation,
  });

  @override
  State<DriverMapTrackingScreen> createState() =>
      _DriverMapTrackingScreenState();
}

class _DriverMapTrackingScreenState extends State<DriverMapTrackingScreen> {
  late osm.MapController _mapController;
  StreamSubscription<firestore.DocumentSnapshot<Map<String, dynamic>>>?
  _locationSub;
  osm.GeoPoint? _driverLocation;

  @override
  void initState() {
    super.initState();
    _mapController = osm.MapController(
      initPosition: osm.GeoPoint(
        latitude: widget.userLocation.latitude,
        longitude: widget.userLocation.longitude,
      ),
    );
    _listenToDriverLocation();
  }

  void _listenToDriverLocation() {
    final auth = Provider.of<AuthService>(context, listen: false);
    final driverId = auth.currentUser?.uid;
    if (driverId == null) return;

    _locationSub = firestore.FirebaseFirestore.instance
        .collection('drivers_location')
        .doc(driverId)
        .snapshots()
        .listen((snap) {
          if (!mounted || !snap.exists) return;
          final data = snap.data()!;
          final lat = data['lat'] as double?;
          final lng = data['lng'] as double?;
          if (lat != null && lng != null) {
            final newDriverLocation = osm.GeoPoint(
              latitude: lat,
              longitude: lng,
            );

            if (_driverLocation != null) {
              _mapController.removeMarker(_driverLocation!);
            }
            _mapController.addMarker(
              newDriverLocation,
              markerIcon: const osm.MarkerIcon(
                icon: Icon(Icons.two_wheeler, color: Colors.blue, size: 48),
              ),
            );
            setState(() => _driverLocation = newDriverLocation);
          }
        });
  }

  Future<void> _addInitialMarker() async {
    await _mapController.addMarker(
      osm.GeoPoint(
        latitude: widget.userLocation.latitude,
        longitude: widget.userLocation.longitude,
      ),
      markerIcon: const osm.MarkerIcon(
        icon: Icon(Icons.person_pin_circle, color: Colors.red, size: 48),
      ),
    );
  }

  Future<void> _startTrackingAndDrawRoute() async {
    Position currentPosition = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    final driverLocation = osm.GeoPoint(
      latitude: currentPosition.latitude,
      longitude: currentPosition.longitude,
    );
    final userDestination = osm.GeoPoint(
      latitude: widget.userLocation.latitude,
      longitude: widget.userLocation.longitude,
    );

    await _mapController.addMarker(
      driverLocation,
      markerIcon: const osm.MarkerIcon(
        icon: Icon(Icons.two_wheeler, color: Colors.blue, size: 48),
      ),
    );

    try {
      await _mapController.drawRoad(
        driverLocation,
        userDestination,
        roadType: osm.RoadType.car,
        roadOption: osm.RoadOption(
          roadColor: const Color.fromARGB(255, 43, 255, 0),
          roadWidth: 10,
          zoomInto: true,
        ),
      );
    } catch (e) {
      debugPrint("❌ Error menggambar rute: $e");
      await _mapController.setZoom(zoomLevel: 16);
    }
  }

  Future<void> _showWeightConfirmationDialog(String orderId) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Berat'),
        content: const Text(
          'Apakah berat sampah sesuai dengan data yang diisi di orderan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Sesuai'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await firestore.FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
            'status': 'arrived_weight_confirmed',
            'payment_ready': true,
          });

      await NotificationService().showLocal(
        id: (widget.orderId.hashCode & 0x7fffffff),
        title: 'Driver telah tiba',
        body:
            'Berat sampah dikonfirmasi. beritahu user untuk melakukan pembayaran.',
      );
    }
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rute ke Lokasi User'),
        backgroundColor: Colors.green[800],
      ),
      body: osm.OSMFlutter(
        controller: _mapController,
        osmOption: osm.OSMOption(
          zoomOption: const osm.ZoomOption(initZoom: 15),
          staticPoints: [
            osm.StaticPositionGeoPoint(
              'user_location',
              const osm.MarkerIcon(
                icon: Icon(
                  Icons.person_pin_circle,
                  color: Colors.red,
                  size: 48,
                ),
              ),
              [
                osm.GeoPoint(
                  latitude: widget.userLocation.latitude,
                  longitude: widget.userLocation.longitude,
                ),
              ],
            ),
          ],
        ),
        onMapIsReady: (isReady) async {
          if (isReady) {
            await _addInitialMarker();
            await _startTrackingAndDrawRoute();
          }
        },
      ),
      floatingActionButton:
          StreamBuilder<firestore.DocumentSnapshot<Map<String, dynamic>>>(
            stream: firestore.FirebaseFirestore.instance
                .collection('orders')
                .doc(widget.orderId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final order = snapshot.data!.data();
              if (order == null) return const SizedBox.shrink();
              final status = order['status'] as String? ?? '';

              // Tampilkan tombol 'Sudah Tiba' saat driver dalam proses menuju lokasi
              if (status == 'accepted' || status == 'on_the_way') {
                return FloatingActionButton.extended(
                  onPressed: () async {
                    await firestore.FirebaseFirestore.instance
                        .collection('orders')
                        .doc(widget.orderId)
                        .update({'status': 'arrived'});

                    if (!context.mounted) return;
                    Navigator.of(context).pop(); // Tutup Map

                    await _showWeightConfirmationDialog(widget.orderId);
                  },
                  label: const Text('Sudah Tiba'),
                  icon: const Icon(Icons.check_circle_outline),
                  backgroundColor: Colors.green[700],
                );
              } else if (status == 'payment_success') {
                return FloatingActionButton.extended(
                  onPressed: () async {
                    await firestore.FirebaseFirestore.instance
                        .collection('orders')
                        .doc(widget.orderId)
                        .update({'status': 'pickup_confirmed_by_driver'});

                    // Notifikasi ke user: minta konfirmasi ambil (ambil user_id dari order)
                    final snap = await firestore.FirebaseFirestore.instance
                        .collection('orders')
                        .doc(widget.orderId)
                        .get();
                    final d = snap.data() as Map<String, dynamic>?;
                    final userId = d?['user_id'] as String? ?? '';
                    if (userId.isNotEmpty) {
                      await NotificationService().notifyUserPickupRequested(
                        orderId: widget.orderId,
                        userId: userId,
                      );
                    }

                    if (context.mounted) Navigator.of(context).pop();
                  },
                  label: const Text('Konfirmasi Ambil'),
                  icon: const Icon(Icons.shopping_bag),
                  backgroundColor: Colors.orange[700],
                );
              }
              return const SizedBox.shrink();
            },
          ),
    );
  }
}
