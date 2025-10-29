import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sampah_online/firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:sampah_online/screens/driver/driver_home.dart';
import 'package:sampah_online/screens/login_screen.dart';
import 'package:sampah_online/screens/user/user_home.dart';
import 'package:sampah_online/welcome_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'screens/register_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // create AuthService instance so we can initialize notification service with it
  final authService = AuthService();
  await NotificationService().init(authService: authService);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
          value: authService,
        ), // provide the same instance
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
      // Keep the welcome screen as the initial screen but register
      // named routes used across the app (login -> /driver or /user).
      home: const WelcomeScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/driver': (context) => const DriverHomeScreen(),
        '/user': (context) => const UserHomeScreen(),
      },
    );
  }
}
