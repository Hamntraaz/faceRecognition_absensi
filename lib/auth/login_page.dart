import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passCtrl = TextEditingController();
  final AuthService _auth = AuthService();
  bool _isLoading = false;
  bool _isPressed = false;

  void _handleLogin() async {
    if (emailCtrl.text.isEmpty || passCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email dan Password wajib diisi!")),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await _auth.login(
        emailCtrl.text.trim(),
        passCtrl.text.trim()
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result["status"] == "Success") {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Ambil data terbaru dari Firestore untuk mendapatkan embedding wajah
        var userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        var userData = userDoc.data();

        // Cek apakah data wajah sudah ada
        bool hasFace = userData != null &&
            userData['face_embedding'] != null &&
            (userData['face_embedding'] as List).isNotEmpty;

        if (!hasFace) {
          // Jika belum ada wajah, arahkan untuk pendaftaran pertama kali
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Anda belum mendaftarkan wajah. Silakan scan dulu.")),
          );
          Navigator.pushReplacementNamed(
              context,
              '/scan',
              arguments: {'isVerifikasi': false} // Mode Daftar
          );
        } else {
          // JIKA SUDAH ADA, WAJIB VERIFIKASI WAJAH DULU SEBELUM KE HOME
          Navigator.pushReplacementNamed(
              context,
              '/scan',
              arguments: {
                'isVerifikasi': true, // Mode Verifikasi Login
                'embeddingAsli': userData['face_embedding'],
                'role': userData['role'] ?? 'user'
              }
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result["message"] ?? "Login Gagal")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 100),
            const Text("Selamat Datang!", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Silakan login untuk memulai absensi", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 50),
            CustomTextField(label: "Email", controller: emailCtrl),
            CustomTextField(label: "Password", isPassword: true, controller: passCtrl),
            const SizedBox(height: 30),
            _isLoading
                ? const CircularProgressIndicator()
                : GestureDetector(
              onTap: _handleLogin,
              onTapDown: (_) => setState(() => _isPressed = true),
              onTapUp: (_) => setState(() => _isPressed = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                transform: Matrix4.identity()..scale(_isPressed ? 0.95 : 1.0),
                child: CustomButton(text: "Login", onPressed: _handleLogin),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/signup'),
              child: const Text("Belum punya akun? Daftar Sekarang", style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      ),
    );
  }
}