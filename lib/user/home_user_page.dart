import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

// Import widget & halaman (Sesuaikan path import jika berbeda)
import '../widgets/user_nav_bar.dart';
import 'absen_user_page.dart';
import 'profile_page.dart';
import 'jadwal_kerja_page.dart';
import '../services/auth_service.dart';

class HomeUserPage extends StatefulWidget {
  const HomeUserPage({super.key});
  @override
  State<HomeUserPage> createState() => _HomeUserPageState();
}

class _HomeUserPageState extends State<HomeUserPage> {
  int _currentIndex = 0;
  Timer? _authTimer;
  late Stream<DateTime> _timeStream;
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    _startTimer();
    _timeStream = Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
  }

  void _startTimer() {
    _authTimer?.cancel();
    _authTimer = Timer(const Duration(minutes: 10), _logoutUser);
  }

  void _logoutUser() async {
    await AuthService().signOut();
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  @override
  void dispose() {
    _authTimer?.cancel();
    super.dispose();
  }

  // Helper untuk mendapatkan hari ini dalam bahasa Indonesia
  String _getHariIni() => DateFormat('EEEE', 'id_ID').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _startTimer(),
      child: Scaffold(
        backgroundColor: const Color(0xFFFBFBFB),
        body: SafeArea(
          child: IndexedStack(
            index: _currentIndex,
            children: [
              _buildHomeDashboard(),    // Indeks 0: Home
              const AbsenUserPage(),    // Indeks 1: Absen
              const JadwalKerjaPage(),  // Indeks 2: Jadwal
              const ProfilePage(),      // Indeks 3: Profil
            ],
          ),
        ),
        bottomNavigationBar: UserNavBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
        ),
      ),
    );
  }

  Widget _buildHomeDashboard() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _animatedEntrance(
            delay: 0,
            direction: 'down',
            child: _headerSapaanDanJam(),
          ),
          const SizedBox(height: 35),

          // --- FIX BAGIAN INI ---
          _animatedEntrance(
            delay: 200,
            direction: 'right',
            child: _cardJadwalHariIni(),
          ),
          // ----------------------

          const SizedBox(height: 35),
          _animatedEntrance(
            delay: 400,
            child: _statistikKehadiran(),
          ),
          const SizedBox(height: 35),
          _animatedEntrance(
            delay: 600,
            child: _pengumumanAdmin(),
          ),
        ],
      ),
    );
  }

  // --- WIDGET KOMPONEN (DESAIN ASLI ANDA) ---

  Widget _headerSapaanDanJam() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
          builder: (context, snapshot) {
            String namaUser = snapshot.hasData ? (snapshot.data!['nama'] ?? "User") : "User";
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Selamat Datang,", style: TextStyle(color: Colors.grey, fontSize: 16, letterSpacing: 0.5)),
                Text(namaUser, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, height: 1.1, letterSpacing: -0.5)),
              ],
            );
          },
        ),
        StreamBuilder<DateTime>(
          stream: _timeStream,
          builder: (context, snapshot) {
            final now = snapshot.data ?? DateTime.now();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(DateFormat('HH:mm').format(now), style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: Colors.blueAccent, height: 1.0)),
                Text(DateFormat('EEEE', 'id_ID').format(now), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(DateFormat('d MMM yyyy', 'id_ID').format(now), style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            );
          },
        ),
      ],
    );
  }

  // --- INI ADALAH LOGIKA YANG DIPERBAIKI (DESAIN TETAP SAMA) ---
  Widget _cardJadwalHariIni() {
    // PERBAIKAN: Nama variabel tidak boleh pakai spasi
    String todayName = _getHariIni(); // Contoh: Jumat

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('all_schedules')
          .doc(todayName) // PERBAIKAN: Gunakan nama variabel yang benar
          .snapshots(),
      builder: (context, snapshot) {
        String shift = "Libur";
        String waktu = "-";
        bool isLibur = true;

        if (snapshot.hasData && snapshot.data!.exists) {
          var data = snapshot.data!.data() as Map<String, dynamic>;
          isLibur = data['is_off'] ?? false;

          if (!isLibur) {
            shift = data['shift'] ?? "N/A";
            waktu = "${data['time_in'] ?? '00:00'} - ${data['time_out'] ?? '00:00'}";
          }
        }

        // UI TETAP SAMA PERSIS SEPERTI DESAIN ANDA
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: isLibur
                ? LinearGradient(colors: [Colors.grey[400]!, Colors.grey[600]!])
                : const LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFF1565C0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: (isLibur ? Colors.grey : Colors.blue).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 35),
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Jadwal Hari Ini",
                    style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    shift,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Jam Kerja: $waktu",
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statistikKehadiran() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Statistik Kehadiran", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        StreamBuilder<QuerySnapshot>(
          // PENTING: Gunakan collectionGroup agar mencari 'log' di semua tanggal
          stream: FirebaseFirestore.instance.collectionGroup('log')
              .where('uid', isEqualTo: uid)
              .snapshots(),
          builder: (context, snapshot) {
            int hadir = 0;
            if (snapshot.hasData) {
              hadir = snapshot.data!.docs.length; // Menghitung berapa kali dokumen UID muncul
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem("Hadir", hadir.toString(), Colors.green, Icons.check_circle_outline),
                _buildStatItem("Telat", "0", Colors.orange, Icons.timer_outlined),
                _buildStatItem("Izin", "0", Colors.blue, Icons.info_outline),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color, IconData icon) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.26,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _pengumumanAdmin() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Pengumuman Internal", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
            TextButton(onPressed: () {}, child: const Text("Lihat Semua", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold))),
          ],
        ),
        const SizedBox(height: 5),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('pengumuman').orderBy('createdAt', descending: true).limit(2).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildPengumumanCard("Info Sistem", "Belum ada pengumuman terbaru dari admin hari ini.");
            }
            return Column(
              children: snapshot.data!.docs.map((doc) {
                return _buildPengumumanCard(doc['judul'] ?? "Pengumuman", doc['isi'] ?? "");
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPengumumanCard(String title, String content) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: const Border(left: BorderSide(color: Colors.orangeAccent, width: 5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 5),
          Text(content, style: const TextStyle(color: Colors.black54, fontSize: 14)),
        ],
      ),
    );
  }

  // HELPER ANIMASI (TETAP DIJAGA SESUAI ASLINYA)
  Widget _animatedEntrance({required int delay, required Widget child, String direction = 'up'}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        double offsetX = 0;
        double offsetY = 0;
        if (direction == 'up') offsetY = 60 * (1 - value);
        if (direction == 'down') offsetY = -60 * (1 - value);
        if (direction == 'right') offsetX = -60 * (1 - value);
        return Transform.translate(
          offset: Offset(offsetX, offsetY),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: child,
    );
  }
}