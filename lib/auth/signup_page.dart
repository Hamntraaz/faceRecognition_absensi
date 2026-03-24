import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';

class SignupPage extends StatefulWidget {
  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passCtrl = TextEditingController();
  final AuthService _auth = AuthService();

  void _handleSignup() async {
    if (emailCtrl.text.isEmpty || passCtrl.text.isEmpty || nameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Semua field harus diisi")),
      );
      return;
    }

    String? result = await _auth.signUp(
      emailCtrl.text.trim(),
      passCtrl.text.trim(),
      nameCtrl.text.trim(),
    );

    if (result == "Success") {
      if (mounted) {
        // Langsung pindah ke halaman scan wajah
        Navigator.pushReplacementNamed(context, '/scan');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result ?? "Pendaftaran Gagal")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Daftar Akun Baru")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            CustomTextField(label: "Nama Lengkap", controller: nameCtrl),
            CustomTextField(label: "Email", controller: emailCtrl),
            CustomTextField(label: "Password", isPassword: true, controller: passCtrl),
            const SizedBox(height: 30),
            CustomButton(text: "Daftar & Absen Sekarang", onPressed: _handleSignup),
          ],
        ),
      ),
    );
  }
}