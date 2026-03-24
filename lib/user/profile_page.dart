import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:cloudinary_public/cloudinary_public.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // State Management (Dari kode kamu)
  bool _isEditing = false;
  bool _isUploading = false;
  bool _isUpdatingInfo = false;
  double _progress = 0.0;

  // Konfigurasi API
  final cloudinary = CloudinaryPublic('dubjinrem', 'Profile', cache: false);
  final TextEditingController _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _currentFaceUrl = "";

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // --- FUNGSI AMBIL & CROP FOTO (Sesuai ketentuan file upload) ---
  Future<void> _pickAndCrop() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image == null) return;

    CroppedFile? cropped = await ImageCropper().cropImage(
      sourcePath: image.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Sesuaikan Foto',
          toolbarColor: Colors.blueAccent,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
      ],
    );

    if (cropped != null) {
      setState(() {
        _isUploading = true;
        _progress = 0;
      });
      try {
        CloudinaryResponse res = await cloudinary.uploadFile(
          CloudinaryFile.fromFile(cropped.path, resourceType: CloudinaryResourceType.Image),
          onProgress: (c, t) => setState(() => _progress = c / t),
        );
        setState(() => _currentFaceUrl = res.secureUrl);

        // Langsung update di Firestore jika sedang tidak dalam mode edit penuh
        if (!_isEditing) {
          await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).update({
            'faceUrl': _currentFaceUrl,
          });
        }
      } catch (e) {
        debugPrint("Upload Error: $e");
      } finally {
        setState(() => _isUploading = false);
      }
    }
  }

  // --- FUNGSI SIMPAN PERUBAHAN NAMA ---
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUpdatingInfo = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).update({
        'nama': _nameController.text.trim(),
        'faceUrl': _currentFaceUrl,
      });
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil diperbarui!")));
    } catch (e) {
      debugPrint("Save Error: $e");
    } finally {
      setState(() => _isUpdatingInfo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        title: const Text("Profil", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          if (_isUpdatingInfo)
            const Padding(padding: EdgeInsets.all(15), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
          else
            IconButton(
              icon: Icon(_isEditing ? Icons.save_rounded : Icons.edit_note_rounded,
                  color: _isEditing ? Colors.green : Colors.blueAccent, size: 28),
              onPressed: () => _isEditing ? _save() : setState(() => _isEditing = true),
            )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          var data = snap.data!.data() as Map<String, dynamic>;

          // Sinkronisasi data awal ke controller jika tidak sedang mengetik
          if (!_isEditing) {
            _nameController.text = data['nama'] ?? "";
            _currentFaceUrl = data['faceUrl'] ?? "";
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // --- AVATAR DENGAN DESAIN DARI FILE UPLOAD ---
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.blueAccent.withOpacity(0.2), width: 4),
                          ),
                          child: CircleAvatar(
                            radius: 70,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: _currentFaceUrl.isNotEmpty ? NetworkImage(_currentFaceUrl) : null,
                            child: _currentFaceUrl.isEmpty ? const Icon(Icons.person, size: 70, color: Colors.grey) : null,
                          ),
                        ),
                        if (_isUploading)
                          SizedBox(
                            width: 140, height: 140,
                            child: CircularProgressIndicator(value: _progress, strokeWidth: 8, color: Colors.blueAccent),
                          ),
                        Positioned(
                          bottom: 0, right: 5,
                          child: CircleAvatar(
                            backgroundColor: Colors.blueAccent,
                            radius: 22,
                            child: IconButton(
                              icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                              onPressed: _isUploading ? null : _pickAndCrop,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // --- INPUT FIELD (Gaya Desain file upload) ---
                  _buildProfileInput(
                    label: "Nama Lengkap",
                    controller: _nameController,
                    icon: Icons.person_outline,
                    isEnabled: _isEditing,
                  ),
                  const SizedBox(height: 20),

                  _buildProfileInput(
                    label: "Email Terdaftar",
                    controller: TextEditingController(text: user?.email),
                    icon: Icons.email_outlined,
                    isEnabled: false, // Email tidak bisa diubah
                  ),

                  const SizedBox(height: 40),

                  // --- BUTTON KELUAR (Desain khusus) ---
                  if (!_isEditing)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _handleLogout(context),
                        icon: const Icon(Icons.logout_rounded, color: Colors.red),
                        label: const Text("Keluar dari Akun", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          side: const BorderSide(color: Colors.redAccent, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- KOMPONEN INPUT SESUAI FILE UPLOAD ---
  Widget _buildProfileInput({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool isEnabled,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: isEnabled,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: isEnabled ? Colors.black : Colors.black45),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: isEnabled ? Colors.blueAccent : Colors.grey),
            filled: true,
            fillColor: isEnabled ? Colors.white : Colors.grey[100],
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.withOpacity(0.3))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5)),
            disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.withOpacity(0.1))),
          ),
          validator: (v) => v == null || v.isEmpty ? "Bidang ini wajib diisi" : null,
        ),
      ],
    );
  }

  void _handleLogout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pushReplacementNamed(context, '/');
  }
}