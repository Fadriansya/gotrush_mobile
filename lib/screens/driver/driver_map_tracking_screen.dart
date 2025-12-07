import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart' as osm;
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
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

            // Update marker jika posisi berubah
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
    // Menambahkan marker di lokasi tujuan (user)
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

    // 2. Tambahkan Marker Driver
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
          zoomInto: true, // Zoom otomatis ke rute yang digambar
        ),
      );
      debugPrint("✅ Rute berhasil digambar.");
    } on Exception catch (e) {
      // Menggunakan Exception yang umum untuk menghindari error
      debugPrint("❌ Gagal menggambar rute (Network/API Error): $e");
      // Jika gagal, set zoom agar user melihat lokasinya saja
      await _mapController.setZoom(zoomLevel: 16);
    } catch (e) {
      debugPrint("❌ Terjadi error tak terduga saat menggambar rute: $e");
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
      // Tombol Sudah Tiba...
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // ... (kode untuk update status 'arrived')
          await firestore.FirebaseFirestore.instance
              .collection('orders')
              .doc(widget.orderId)
              .update({'status': 'arrived'});
          if (context.mounted) {
            Navigator.of(context).pop(); // Kembali ke DriverHomeScreen
          }
        },
        label: const Text('Sudah Tiba'),
        icon: const Icon(Icons.check_circle_outline),
        backgroundColor: Colors.green[700],
      ),
    );
  }
}
