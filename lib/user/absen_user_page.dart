import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AbsenUserPage extends StatelessWidget {
  const AbsenUserPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    // PENTING: Gunakan id_ID agar nama hari (Senin, Selasa, dll) cocok dengan Firestore Admin
    String today = DateFormat('EEEE', 'id_ID').format(DateTime.now());

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Absensi Hari Ini", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          StreamBuilder<DocumentSnapshot>(
            // Path disesuaikan dengan yang disimpan Admin
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('all_schedules')
                .doc(today)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return _buildNoJadwal();
              }

              var data = snapshot.data!.data() as Map<String, dynamic>;

              // Cek jika Admin mengatur hari ini sebagai LIBUR
              if (data['is_off'] == true) {
                return _buildNoJadwal(title: "Hari Ini Anda Libur", subtitle: "Selamat beristirahat!");
              }

              return _buildAbsenStatus(context, data, uid!);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAbsenStatus(BuildContext context, Map<String, dynamic> sched, String uid) {
    String todayDocId = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return StreamBuilder<DocumentSnapshot>(
      // Mengambil data absensi yang baru saja di-input
      stream: FirebaseFirestore.instance
          .collection('absensi')
          .doc(todayDocId)
          .collection('log')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        var attend = snapshot.data?.data() as Map<String, dynamic>?;
        bool sudahAbsen = attend != null && attend['check_in'] != null;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Jika sudah absen, tampilkan Foto Hasil Scan
                  if (sudahAbsen)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(attend['face_url'], width: 60, height: 60, fit: BoxFit.cover),
                    )
                  else
                    const CircleAvatar(backgroundColor: Color(0xFFE3F2FD), child: Icon(Icons.person, color: Colors.blue)),

                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sched['shift'] ?? "Shift", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Text("Jadwal: ${sched['time_in']} - ${sched['time_out']}"),
                      ],
                    ),
                  ),

                  // Tombol ganti jadi Ikon Centang jika sudah absen
                  if (!sudahAbsen)
                    IconButton.filled(
                      onPressed: () => Navigator.pushNamed(context, '/scan'),
                      icon: const Icon(Icons.camera_alt),
                    )
                  else
                    const Icon(Icons.check_circle, color: Colors.green, size: 40),
                ],
              ),
              if (sudahAbsen) ...[
                const Divider(height: 30),
                Text("Lokasi: ${attend['address'] ?? 'Lokasi tidak terdeteksi'}",
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
              const Divider(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _timeLog("IN", attend?['check_in'], sched['time_in']),
                  _timeLog("OUT", attend?['check_out'], sched['time_out']),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _timeLog(String label, String? time, String target) {
    bool isLate = false;
    if (label == "IN" && time != null) isLate = time.compareTo(target) > 0;

    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(time ?? "--:--", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isLate ? Colors.red : Colors.black)),
      ],
    );
  }

  Widget _buildNoJadwal({String title = "Tidak Ada Jadwal", String subtitle = "Hubungi admin jika ini kesalahan."}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          const Icon(Icons.event_busy, color: Colors.grey, size: 40),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}