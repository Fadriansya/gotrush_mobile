// lib/screens/map_tracking_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart' as osm;
import 'package:geolocator/geolocator.dart';
import '/utils/alerts.dart';

class MapTrackingScreen extends StatefulWidget {
  final String orderId;
  final String driverId;
  final String userId;

  const MapTrackingScreen({
    super.key,
    required this.orderId,
    required this.driverId,
    required this.userId,
  });

  @override
  State<MapTrackingScreen> createState() => _MapTrackingScreenState();
}

class _MapTrackingScreenState extends State<MapTrackingScreen> {
  late osm.MapController _mapController;

  // gunakan tipe osm.GeoPoint untuk peta
  osm.GeoPoint? _driverLocation;
  osm.GeoPoint? _userLocation;

  double _distanceToUser = 0.0;
  bool _isNearNotified = false;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _driverSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;

  @override
  void initState() {
    super.initState();
    // Inisialisasi MapController (pakai osm.GeoPoint)
    _mapController = osm.MapController(
      initMapWithUserPosition: const osm.UserTrackingOption(
        enableTracking: true,
        unFollowUser: false,
      ),
      initPosition: osm.GeoPoint(latitude: -6.200000, longitude: 106.816666),
    );
    _listenToLocations();
  }

  void _listenToLocations() {
    // Sesuaikan nama koleksi sesuai yang kamu pakai: 'drivers_location' / 'users_location'
    final driverStream = FirebaseFirestore.instance
        .collection('drivers_location')
        .doc(widget.driverId)
        .snapshots();

    final userStream = FirebaseFirestore.instance
        .collection('users_location')
        .doc(widget.userId)
        .snapshots();

    _driverSub = driverStream.listen(
      (snap) async {
        if (!mounted) return;
        if (snap.exists && snap.data() != null) {
          final d = snap.data()!;
          final rawLat = d['lat'] ?? d['latitude'] ?? 0;
          final rawLng = d['lng'] ?? d['longitude'] ?? 0;
          final lat = (rawLat is num)
              ? rawLat.toDouble()
              : double.tryParse(rawLat.toString()) ?? 0.0;
          final lng = (rawLng is num)
              ? rawLng.toDouble()
              : double.tryParse(rawLng.toString()) ?? 0.0;
          if (lat != 0.0 && lng != 0.0) {
            setState(() {
              _driverLocation = osm.GeoPoint(latitude: lat, longitude: lng);
            });
          }
          await _checkDistanceAndNotify();
          await _updateMapMarkers();
        }
      },
      onError: (e) {
        debugPrint('driver location stream error: $e');
      },
    );

    _userSub = userStream.listen(
      (snap) async {
        if (!mounted) return;
        if (snap.exists && snap.data() != null) {
          final d = snap.data()!;
          final rawLat = d['lat'] ?? d['latitude'] ?? 0;
          final rawLng = d['lng'] ?? d['longitude'] ?? 0;
          final lat = (rawLat is num)
              ? rawLat.toDouble()
              : double.tryParse(rawLat.toString()) ?? 0.0;
          final lng = (rawLng is num)
              ? rawLng.toDouble()
              : double.tryParse(rawLng.toString()) ?? 0.0;
          if (lat != 0.0 && lng != 0.0) {
            setState(() {
              _userLocation = osm.GeoPoint(latitude: lat, longitude: lng);
            });
          }
          await _checkDistanceAndNotify();
          await _updateMapMarkers();
        }
      },
      onError: (e) {
        debugPrint('user location stream error: $e');
      },
    );
  }

  Future<void> _checkDistanceAndNotify() async {
    if (_driverLocation == null || _userLocation == null) return;

    // 1. Hitung Jarak (menggunakan geolocator)
    final distance = Geolocator.distanceBetween(
      _driverLocation!.latitude,
      _driverLocation!.longitude,
      _userLocation!.latitude,
      _userLocation!.longitude,
    );

    // Perbarui state jarak (opsional, untuk ditampilkan di UI)
    if (mounted) {
      setState(() {
        _distanceToUser = distance; // Jarak dalam meter
      });
    }

    // 2. Logika Notifikasi (Driver Hampir Sampai: 200 meter)
    const threshold = 200.0; // Jarak dalam meter

    if (distance <= threshold && !_isNearNotified) {
      // Pemicu Notifikasi Lokal (Snackbar atau Dialog)
      showAppSnackBar(
        context,
        'Driver hampir sampai! Jarak: ${distance.toStringAsFixed(0)} meter.',
        type: AlertType.warning,
      );

      // Set flag agar notifikasi hanya muncul sekali (atau sampai order selesai)
      _isNearNotified = true;
    }

    // Reset flag jika jarak menjauh (opsional, tergantung logika yang diinginkan)
    if (distance > threshold * 2) {
      // Contoh: reset jika jarak > 400m
      _isNearNotified = false;
    }
  }

  Future<void> _updateMapMarkers() async {
    try {
      // Jika sebelumnya ada marker driver, hapus dulu
      if (_driverLocation != null) {
        await _mapController.removeMarker(
          osm.GeoPoint(
            latitude: _driverLocation!.latitude,
            longitude: _driverLocation!.longitude,
          ),
        );
      }

      if (_userLocation != null) {
        await _mapController.removeMarker(
          osm.GeoPoint(
            latitude: _userLocation!.latitude,
            longitude: _userLocation!.longitude,
          ),
        );
      }

      // Tambahkan marker driver
      if (_driverLocation != null) {
        await _mapController.addMarker(
          osm.GeoPoint(
            latitude: _driverLocation!.latitude,
            longitude: _driverLocation!.longitude,
          ),
          markerIcon: const osm.MarkerIcon(
            icon: Icon(Icons.local_shipping, color: Colors.red, size: 48),
          ),
        );
      }

      // Tambahkan marker user
      if (_userLocation != null) {
        await _mapController.addMarker(
          osm.GeoPoint(
            latitude: _userLocation!.latitude,
            longitude: _userLocation!.longitude,
          ),
          markerIcon: const osm.MarkerIcon(
            icon: Icon(Icons.person_pin_circle, color: Colors.blue, size: 48),
          ),
        );
      }

      // Zoom otomatis agar keduanya terlihat
      if (_driverLocation != null && _userLocation != null) {
        final box = osm.BoundingBox.fromGeoPoints([
          osm.GeoPoint(
            latitude: _driverLocation!.latitude,
            longitude: _driverLocation!.longitude,
          ),
          osm.GeoPoint(
            latitude: _userLocation!.latitude,
            longitude: _userLocation!.longitude,
          ),
        ]);
        await _mapController.zoomToBoundingBox(box);
      } else if (_driverLocation != null) {
        await _mapController.goToLocation(
          osm.GeoPoint(
            latitude: _driverLocation!.latitude,
            longitude: _driverLocation!.longitude,
          ),
        );
      } else if (_userLocation != null) {
        await _mapController.goToLocation(
          osm.GeoPoint(
            latitude: _userLocation!.latitude,
            longitude: _userLocation!.longitude,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error updating markers: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Live Tracking - Jarak: ${_distanceToUser.toStringAsFixed(0)} m',
        ),
      ),
      body: osm.OSMFlutter(
        controller: _mapController,
        // osmOption wajib pada beberapa versi; pakai osm.OSMOption
        osmOption: osm.OSMOption(
          zoomOption: osm.ZoomOption(
            initZoom: 14,
            minZoomLevel: 3,
            maxZoomLevel: 18,
          ),
          // userLocationMarker optional — kita set contoh
          userLocationMarker: osm.UserLocationMaker(
            personMarker: osm.MarkerIcon(
              icon: Icon(Icons.person_pin, color: Colors.blue),
            ),
            directionArrowMarker: osm.MarkerIcon(
              icon: Icon(Icons.navigation, color: Colors.black),
            ),
          ),
        ),
        mapIsLoading: const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  @override
  void dispose() {
    _driverSub?.cancel();
    _userSub?.cancel();
    _mapController.dispose();
    super.dispose();
  }
}
