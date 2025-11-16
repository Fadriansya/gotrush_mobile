import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart' as osm;
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;

class MapSelectionScreen extends StatefulWidget {
  const MapSelectionScreen({super.key});
  @override
  State<MapSelectionScreen> createState() => _MapSelectionScreenState();
}

class _MapSelectionScreenState extends State<MapSelectionScreen> {
  late osm.MapController _mapController;
  osm.GeoPoint? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _mapController = osm.MapController(
      // initPosition: _initialPosition,
      initMapWithUserPosition: const osm.UserTrackingOption(
        enableTracking: true,
        unFollowUser: false,
      ),
    );
  }

  // Fungsi yang dipanggil ketika user selesai memilih lokasi
  void _confirmLocation() {
    if (_selectedLocation != null) {
      final firestoreGeoPoint = firestore.GeoPoint(
        _selectedLocation!.latitude,
        _selectedLocation!.longitude,
      );
      Navigator.of(context).pop(firestoreGeoPoint);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan tentukan lokasi penjemputan')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tentukan Lokasi Penjemputan')),
      body: Stack(
        children: [
          // 1. Peta OSMFlutter
          osm.OSMFlutter(
            controller: _mapController,
            osmOption: osm.OSMOption(
              zoomOption: const osm.ZoomOption(initZoom: 15),
            ),
            // Mengambil lokasi ketika peta selesai dimuat
            onMapIsReady: (isReady) async {
              if (isReady) {
                final centerPoint = await _mapController.centerMap;
                // Saat peta siap, akan mendapatkan lokasi pusat peta saat ini
                _selectedLocation = centerPoint;
                setState(() {});
              }
            },
            // Mengambil lokasi baru ketika user menggeser peta
            onGeoPointClicked: (osm.GeoPoint point) {
              // Ketika user klik suatu titik, titik itu menjadi GeoPoint yang dipilih
              _selectedLocation = point;
              setState(() {});
            },
            // Saat user menggeser peta, ambil lokasi pusat baru
            onMapMoved: (newRegion) {
              _selectedLocation = newRegion.center;
              setState(() {});
            },
            mapIsLoading: const Center(child: CircularProgressIndicator()),
          ),

          // 2. Pin di Tengah Peta untuk Visualisasi
          const Center(
            child: Icon(Icons.location_pin, color: Colors.red, size: 50),
          ),

          // 3. Tombol Konfirmasi Lokasi
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              onPressed: _selectedLocation != null ? _confirmLocation : null,
              icon: const Icon(Icons.check_circle),
              label: Text(
                _selectedLocation == null
                    ? 'Memuat Peta...'
                    : 'Konfirmasi Lokasi Ini',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}
