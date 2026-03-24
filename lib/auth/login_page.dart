import 'package:flutter/material.dart';
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
      // 1. CEK STATUS PENDAFTARAN WAJAH
      if (result["isFaceRegistered"] == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Anda belum mendaftarkan wajah. Silakan scan dulu.")),
        );
        Navigator.pushReplacementNamed(context, '/scan');
      } else {
        // 2. CEK ROLE UNTUK MENENTUKAN DASHBOARD (FIXED)
        if (result["role"] == "admin") {
          Navigator.pushReplacementNamed(context, '/home_admin');
        } else {
          Navigator.pushReplacementNamed(context, '/home_user');
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result["status"] ?? "Login Gagal")),
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