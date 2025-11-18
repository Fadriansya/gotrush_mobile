import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart' as osm;
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:geocoding/geocoding.dart';

class MapSelectionScreen extends StatefulWidget {
  const MapSelectionScreen({super.key});
  @override
  State<MapSelectionScreen> createState() => _MapSelectionScreenState();
}

class _MapSelectionScreenState extends State<MapSelectionScreen> {
  late osm.MapController _mapController;
  osm.GeoPoint? _selectedLocation;
  String? _selectedAddress;
  bool _isLoadingAddress = false;
  Timer? _addressLookupTimer;

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

  // Fungsi untuk mendapatkan alamat dari koordinat dengan debouncing
  void _getAddressFromLocation(osm.GeoPoint point) {
    _addressLookupTimer?.cancel();
    _addressLookupTimer = Timer(const Duration(milliseconds: 1000), () async {
      if (!mounted) return;
      setState(() => _isLoadingAddress = true);
      try {
        final placemarks = await placemarkFromCoordinates(
          point.latitude,
          point.longitude,
        );
        if (!mounted) return;
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final address =
              [
                    place.street,
                    place.subLocality,
                    place.locality,
                    place.subAdministrativeArea,
                    place.administrativeArea,
                    place.country,
                  ]
                  .where((element) => element != null && element.isNotEmpty)
                  .join(', ');
          setState(() => _selectedAddress = address);
        } else {
          setState(() => _selectedAddress = 'Alamat tidak ditemukan');
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _selectedAddress = 'Gagal mendapatkan alamat');
        debugPrint('Error getting address: $e');
      } finally {
        if (mounted) {
          setState(() => _isLoadingAddress = false);
        }
      }
    });
  }

  // Fungsi yang dipanggil ketika user selesai memilih lokasi
  void _confirmLocation() {
    if (_selectedLocation != null) {
      final result = {
        'location': firestore.GeoPoint(
          _selectedLocation!.latitude,
          _selectedLocation!.longitude,
        ),
        'address': _selectedAddress ?? 'Alamat tidak tersedia',
      };
      Navigator.of(context).pop(result);
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
              _getAddressFromLocation(point);
              setState(() {});
            },
            // Saat user menggeser peta, ambil lokasi pusat baru
            onMapMoved: (newRegion) {
              _selectedLocation = newRegion.center;
              _getAddressFromLocation(newRegion.center);
              setState(() {});
            },
            mapIsLoading: const Center(child: CircularProgressIndicator()),
          ),

          // 2. Pin di Tengah Peta untuk Visualisasi
          const Center(
            child: Icon(Icons.location_pin, color: Colors.red, size: 50),
          ),

          // 3. Info Alamat dan Tombol Konfirmasi Lokasi
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              children: [
                if (_selectedAddress != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isLoadingAddress
                                ? 'Mencari alamat...'
                                : _selectedAddress!,
                            style: const TextStyle(fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ElevatedButton.icon(
                  onPressed: _selectedLocation != null
                      ? _confirmLocation
                      : null,
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
                    minimumSize: const Size(double.infinity, 50),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _addressLookupTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }
}
