import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Pastikan sudah tambah intl di pubspec.yaml
import '../widgets/admin_nav_bar.dart';
import 'user_list_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:face_absensi/auth/login_page.dart';

class HomeAdminPage extends StatefulWidget {
  const HomeAdminPage({super.key});
  @override
  State<HomeAdminPage> createState() => _HomeAdminPageState();
}

class _HomeAdminPageState extends State<HomeAdminPage> {
  int _currentIndex = 0;
  final String _todayDocId = DateFormat('yyyy-MM-dd').format(DateTime.now());

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Apakah Anda yakin ingin keluar dari akun Admin?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              // Langsung arahkan ke class LoginPage tanpa menggunakan nama route
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()), // Ganti dengan class login kamu
                    (route) => false,
              );
            },
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        title: const Text(
          "Admin Dashboard",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          // TOMBOL LOGOUT DI POJOK KANAN ATAS
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: _showLogoutDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: AdminNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildRealTimeDashboard(),
          const UserListPage(),
          const Center(child: Text("Halaman Laporan Detail")),
          const Center(child: Text("Halaman Pengaturan Sistem")),
        ],
      ),
    );
  }

  Widget _buildRealTimeDashboard() {
    return StreamBuilder<QuerySnapshot>(
      // Mengambil data semua user dengan role 'user'
      stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'user').snapshots(),
      builder: (context, userSnap) {
        return StreamBuilder<QuerySnapshot>(
          // Mengambil data absensi khusus hari ini
          stream: FirebaseFirestore.instance.collection('absensi').doc(_todayDocId).collection('logs').snapshots(),
          builder: (context, attendanceSnap) {
            if (!userSnap.hasData || !attendanceSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            // --- LOGIKA PERHITUNGAN DATA ASLI ---
            int totalKaryawan = userSnap.data!.docs.length;
            int hadir = attendanceSnap.data!.docs.length;

            // Hitung terlambat (Misal batas jam 08:00)
            int terlambat = attendanceSnap.data!.docs.where((doc) {
              final jamMasuk = doc['jam_masuk'] ?? "00:00";
              return int.parse(jamMasuk.split(":")[0]) >= 8 && int.parse(jamMasuk.split(":")[1]) > 0;
            }).length;

            int izin = 0; // Ini bisa dikoneksikan ke koleksi 'izin' jika sudah ada
            double presentase = totalKaryawan > 0 ? hadir / totalKaryawan : 0.0;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildHeader(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Statistik Real-Time", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),

                        // Row 1: Total & Hadir
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatCard("Total User", "$totalKaryawan", Icons.people, Colors.blue),
                            _buildStatCard("Hadir", "$hadir", Icons.check_circle, Colors.green),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Row 2: Terlambat & Belum Absen
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatCard("Terlambat", "$terlambat", Icons.timer, Colors.orange),
                            _buildStatCard("Belum Absen", "${totalKaryawan - hadir}", Icons.warning_amber_rounded, Colors.red),
                          ],
                        ),

                        const SizedBox(height: 32),
                        const Text("Presentase Kehadiran", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        _buildPieChartSection(presentase),

                        const SizedBox(height: 32),
                        const Text("Log Kehadiran Terbaru", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        _buildRecentActivityList(attendanceSnap.data!.docs),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- HEADER SLIVER ---
  Widget _buildHeader() {
    return SliverAppBar(
      expandedHeight: 100,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: const FlexibleSpaceBar(
        titlePadding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        title: Text("Admin Panel", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
    );
  }

  // --- CARD STATISTIK ---
  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.42,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  // --- PIE CHART SECTION (DENGAN DATA ASLI) ---
  Widget _buildPieChartSection(double value) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
      child: Row(
        children: [
          SizedBox(
            height: 100, width: 100,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value),
              duration: const Duration(seconds: 1),
              builder: (context, val, _) => Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(value: val, strokeWidth: 10, backgroundColor: Colors.grey[100], color: Colors.blueAccent, strokeCap: StrokeCap.round),
                  Text("${(val * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LegendItem(color: Colors.blueAccent, label: "Sudah Absen"),
                SizedBox(height: 8),
                _LegendItem(color: Colors.grey, label: "Belum Absen"),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- LIST LOG AKTIVITAS (DATA ASLI) ---
  Widget _buildRecentActivityList(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return const Center(child: Text("Belum ada aktivitas hari ini."));

    // Urutkan berdasarkan waktu terbaru
    var sortedDocs = docs.toList();

    return Column(
      children: sortedDocs.take(5).map((doc) {
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey[100]!)),
          child: ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.person, color: Colors.white)),
            title: Text(doc['nama'] ?? "User", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text("Masuk jam: ${doc['jam_masuk']}", style: const TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 12),
          ),
        );
      }).toList(),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

