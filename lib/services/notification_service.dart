// notification_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class NotificationService {
  NotificationService._private();
  static final NotificationService _instance = NotificationService._private();
  factory NotificationService() => _instance;

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  Future<void> init({required AuthService authService}) async {
    // Request permission (iOS/macOS)
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      final token = await _fcm.getToken();
      if (token != null) {
        await authService.updateFcmToken(token);
      }
    }

    // Initialize local notifications for foreground messages
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // handle taps if needed
        debugPrint('Local notification tapped: ${response.payload}');
      },
    );

    // Show local notification when FCM message arrives in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final n = message.notification;
      if (n != null) {
        const androidDetails = AndroidNotificationDetails(
          'sampah_channel',
          'Sampah Notifications',
          channelDescription: 'Notifikasi aplikasi sampah_online',
          importance: Importance.max,
          priority: Priority.high,
        );
        final details = NotificationDetails(android: androidDetails);
        // Gunakan safeId agar tidak melebihi 32-bit
        final id = safeId(
          'fcm_${n.hashCode}_${DateTime.now().millisecondsSinceEpoch}',
        );
        await _local.show(
          id,
          n.title,
          n.body,
          details,
          payload: message.data.toString(),
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCM message opened app: ${message.data}');
    });
  }

  Future<void> showLocal({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'sampah_channel',
      'Sampah Notifications',
      channelDescription: 'Notifikasi aplikasi sampah_online',
      importance: Importance.max,
      priority: Priority.high,
    );
    final details = NotificationDetails(android: androidDetails);
    await _local.show(id, title, body, details);
  }

  // Helper untuk membuat ID notifikasi aman (32-bit)
  int safeId(Object seed) => (seed.hashCode & 0x7fffffff);

  // ========= Placeholder FCM per-peran =========
  // Catatan: untuk push lintas perangkat, perlu integrasi Cloud Functions/Server.
  // Sementara gunakan local notification sebagai fallback di perangkat aktif.

  Future<void> notifyDriverPaymentSuccess({
    required String orderId,
    required String driverId,
  }) async {
    await showLocal(
      id: safeId('driver_payment_$orderId'),
      title: 'Pembayaran Berhasil',
      body: 'Order $orderId telah dibayar. Silakan konfirmasi pengambilan.',
    );
    // TODO: kirim FCM ke driverId jika backend tersedia
  }

  Future<void> notifyUserPickupRequested({
    required String orderId,
    required String userId,
  }) async {
    await showLocal(
      id: safeId('user_pickup_$orderId'),
      title: 'Konfirmasi Pengambilan',
      body:
          'Driver mengonfirmasi pengambilan untuk order $orderId. Apakah sampah sudah diambil?',
    );
    // TODO: kirim FCM ke userId jika backend tersedia
  }

  Future<void> notifyBothCompleted({
    required String orderId,
    required String userId,
    required String driverId,
  }) async {
    await showLocal(
      id: safeId('completed_user_$orderId'),
      title: 'Terima kasih',
      body:
          'Order $orderId selesai. Terima kasih telah menggunakan layanan kami.',
    );
    await showLocal(
      id: safeId('completed_driver_$orderId'),
      title: 'Order Selesai',
      body: 'Order $orderId telah dikonfirmasi selesai oleh user.',
    );
    // TODO: kirim FCM ke kedua pihak jika backend tersedia
  }
}
