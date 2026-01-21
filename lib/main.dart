import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Try auto-login from secure storage before showing LoginPage
  await AuthService.tryAutoLogin();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final home = AuthService.currentUser() == null ? const LoginPage() : const HomePage();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: vvv,
    );
  }
}
