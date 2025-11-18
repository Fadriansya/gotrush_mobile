import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final String userId;
  final String? driverId;
  final String status;
  final double weight;
  final double distance;
  final double price;
  final String address;
  final GeoPoint location;
  final List<String> photoUrls;
  final Timestamp createdAt;

  OrderModel({
    required this.id,
    required this.userId,
    this.driverId,
    required this.status,
    required this.weight,
    required this.distance,
    required this.price,
    required this.address,
    required this.location,
    required this.photoUrls,
    required this.createdAt,
  });

  factory OrderModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return OrderModel(
      id: doc.id,
      userId: d['user_id'],
      driverId: d['driver_id'],
      status: d['status'],
      weight: (d['weight'] ?? 0).toDouble(),
      distance: (d['distance'] ?? 0).toDouble(),
      price: (d['price'] ?? 0).toDouble(),
      address: d['address'] ?? '',
      location: d['location'],
      photoUrls: List<String>.from(d['photo_urls'] ?? []),
      createdAt: d['created_at'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'driver_id': driverId,
    'status': status,
    'weight': weight,
    'distance': distance,
    'price': price,
    'address': address,
    'location': location,
    'photo_urls': photoUrls,
    'created_at': createdAt,
  };
}
