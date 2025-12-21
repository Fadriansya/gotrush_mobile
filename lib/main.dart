// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:sampah_online/firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:sampah_online/screens/admin/admin_dashboard.dart';
import 'package:sampah_online/screens/driver/driver_home.dart';
import 'package:sampah_online/screens/login_screen.dart';
import 'package:sampah_online/screens/user/user_home.dart';
import 'package:sampah_online/welcome_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'screens/register_screen.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init Intl locale early
  try {
    await initializeDateFormatting('id_ID', null);
    Intl.defaultLocale = 'id_ID';
  } catch (e) {
    print("Error initializing locale: $e");
  }

  // Init Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // =====================================================
  // APP CHECK — MODE PALING STABIL
  // =====================================================
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.playIntegrity,
    appleProvider: AppleProvider.deviceCheck,
  );

  final authService = AuthService();
  final notificationService = NotificationService();
  await notificationService.init(authService: authService);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authService),
        Provider.value(value: notificationService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GotRush',
      debugShowCheckedModeBanner: false,
      home: const WelcomeScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/driver': (context) => const DriverHomeScreen(),
        '/user': (context) => const UserHomeScreen(),
        '/admin': (context) => const AdminDashboard(),
      },
    );
  }
}
