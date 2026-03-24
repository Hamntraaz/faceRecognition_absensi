import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'manage_jadwal_page.dart'; // Import halaman jadwal yang sudah kamu buat

class UserListPage extends StatelessWidget {
  const UserListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        title: const Text("Pilih Karyawan", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Mengambil hanya user yang rolenya 'user' (bukan admin)
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'user')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Tidak ada data karyawan"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var user = snapshot.data!.docs[index];
              var userData = user.data() as Map<String, dynamic>;

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(color: Colors.grey[200]!),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueAccent.withOpacity(0.1),
                    child: const Icon(Icons.person, color: Colors.blueAccent),
                  ),
                  title: Text(
                    userData['nama'] ?? "Tanpa Nama",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(userData['email'] ?? "-"),
                  trailing: const Icon(Icons.calendar_month_outlined, color: Colors.blueAccent, size: 20),
                  onTap: () {
                    // PINDAH KE HALAMAN JADWAL DENGAN DATA DARI FIRESTORE
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ManageJadwalPage(
                          userId: user.id, // ID Dokumen Firestore
                          userName: userData['name'] ?? "User",
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}