import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // FUNGSI LOGIN (Mengecek apakah user sudah pernah scan wajah)
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      UserCredential res = await _auth.signInWithEmailAndPassword(
          email: email, password: password);

      DocumentSnapshot userDoc = await _db.collection('users').doc(res.user!.uid).get();

      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        // Cek apakah field faceRegistered bernilai true
        bool isFaceRegistered = userData.containsKey('faceRegistered') && userData['faceRegistered'] == true;

        return {
          "status": "Success",
          "isFaceRegistered": isFaceRegistered,
          "role": userData['role'] ?? 'user'
        };
      }
      return {"status": "Data user tidak ditemukan di database"};
    } catch (e) {
      return {"status": e.toString()};
    }
  }

  // FUNGSI SIGNUP (Pendaftaran User Baru)
  Future<String?> signUp(String email, String password, String name) async {
    try {
      UserCredential res = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);

      await _db.collection('users').doc(res.user!.uid).set({
        'uid': res.user!.uid,
        'nama': name,
        'email': email,
        'role': 'user',
        'faceRegistered': false, // Baru daftar otomatis belum scan
        'createdAt': FieldValue.serverTimestamp(),
      });
      return "Success";
    } catch (e) {
      return e.toString();
    }
  }

  // UPDATE STATUS SETELAH BERHASIL SCAN PERTAMA KALI
  Future<void> setFaceRegistered() async {
    try {
      String? uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _db.collection('users').doc(uid).update({
          'faceRegistered': true,
        });
      }
    } catch (e) {
      print("Gagal update status wajah: $e");
    }
  }

  // SIMPAN LOG ABSENSI
  Future<bool> simpanAbsensi(String imageUrl) async {
    try {
      String? uid = _auth.currentUser?.uid;
      if (uid == null) return false;

      await _db.collection('absensi').add({
        'uid': uid,
        'waktu': FieldValue.serverTimestamp(),
        'fotoUrl': imageUrl,
        'status': 'Hadir',
      });
      return true;
    } catch (e) {
      print("Gagal simpan absensi: $e");
      return false;
    }
  }

  // FUNGSI LOGOUT (Agar tidak error di Home)
  Future<void> signOut() async {
    await _auth.signOut();
  }
}