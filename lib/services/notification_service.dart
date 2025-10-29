import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

/// NotificationService handles FCM token registration and foreground local
/// notifications. For background/terminated notifications rely on FCM payloads.
class NotificationService {
  NotificationService._private();
  static final NotificationService _instance = NotificationService._private();
  factory NotificationService() => _instance;

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  /// Initialize notifications. Pass an AuthService instance so we can persist
  /// the FCM token to the user's profile (used by Cloud Functions to send
  /// targeted notifications).
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
        await _local.show(
          n.hashCode,
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
}
