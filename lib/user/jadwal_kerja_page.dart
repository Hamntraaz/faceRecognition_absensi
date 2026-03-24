import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class JadwalKerjaPage extends StatefulWidget {
  const JadwalKerjaPage({super.key});
  @override
  State<JadwalKerjaPage> createState() => _JadwalKerjaPageState();
}

class _JadwalKerjaPageState extends State<JadwalKerjaPage> {
  final List<String> urutanHari = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
  String get hariIni => DateFormat('EEEE', 'id_ID').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
          title: const Text("Jadwal Kerja", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Path sub-koleksi all_schedules milik user login
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('all_schedules')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          // Mengurutkan data agar muncul dari Senin - Minggu
          var docs = snapshot.data!.docs.toList();
          docs.sort((a, b) => urutanHari.indexOf(a.id).compareTo(urutanHari.indexOf(b.id)));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String hari = docs[index].id;
              bool isToday = hari == hariIni;
              bool isOff = data['is_off'] ?? false;

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(color: isToday ? Colors.blueAccent : Colors.grey[200]!, width: isToday ? 2 : 1),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isOff ? Colors.red[50] : Colors.blue[50],
                    child: Icon(isOff ? Icons.bedtime_outlined : Icons.work_outline,
                        color: isOff ? Colors.red : Colors.blueAccent),
                  ),
                  title: Text(hari, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: isOff
                      ? const Text("Libur", style: TextStyle(color: Colors.red))
                      : Text("Shift: ${data['shift']}\nJam: ${data['time_in']} - ${data['time_out']}"),
                  trailing: isToday
                      ? const Chip(label: Text("Hari Ini", style: TextStyle(fontSize: 10, color: Colors.white)), backgroundColor: Colors.blueAccent)
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("Belum ada jadwal dari admin", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}