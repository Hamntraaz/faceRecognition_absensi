import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Pastikan PATH ini sesuai dengan struktur folder project Anda
import 'user/home_user_page.dart';
import 'admin/home_admin_page.dart';
import 'auth/login_page.dart';
import 'auth/signup_page.dart';
import 'shared/scan_wajah_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Timer? _sessionTimer;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  void _resetTimer() {
    _sessionTimer?.cancel();
    if (FirebaseAuth.instance.currentUser != null) {
      _sessionTimer = Timer(const Duration(minutes: 10), _handleAutoLogout);
    }
  }

  void _handleAutoLogout() async {
    await FirebaseAuth.instance.signOut();
    _navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
    debugPrint("Sesi habis, pengguna otomatis logout.");
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _resetTimer(),
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Face Absensi',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const LoginPage(),
          '/signup': (context) => SignupPage(), // PERBAIKAN: Hapus 'const' di sini
          '/home_user': (context) => const HomeUserPage(),
          '/home_admin': (context) => const HomeAdminPage(),
          '/scan': (context) => const ScanWajahPage(),
        },
      ),
    );
  }
}