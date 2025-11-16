import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart' as osm;
import 'package:geolocator/geolocator.dart';

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

  @override
  void initState() {
    super.initState();
    _mapController = osm.MapController(
      initPosition: osm.GeoPoint(
        latitude: widget.userLocation.latitude,
        longitude: widget.userLocation.longitude,
      ),
    );
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
      desiredAccuracy: LocationAccuracy.high,
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
      print("✅ Rute berhasil digambar.");
    } on Exception catch (e) {
      // Menggunakan Exception yang umum untuk menghindari error
      print("❌ Gagal menggambar rute (Network/API Error): $e");
      // Jika gagal, set zoom agar user melihat lokasinya saja
      await _mapController.setZoom(zoomLevel: 16);
    } catch (e) {
      print("❌ Terjadi error tak terduga saat menggambar rute: $e");
    }
  }

  @override
  void dispose() {
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
