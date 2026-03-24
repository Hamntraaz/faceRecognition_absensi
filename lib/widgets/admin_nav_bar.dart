import 'package:flutter/material.dart';

class AdminNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const AdminNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Definisi Menu Admin
    final List<_NavItem> navItems = [
      _NavItem(Icons.dashboard_rounded, "Dashboard"),
      _NavItem(Icons.people_alt_rounded, "Karyawan"),
      _NavItem(Icons.analytics_outlined, "Laporan"), // Ini nanti isinya Pie Chart dll
      _NavItem(Icons.settings_applications_rounded, "Sistem"),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(navItems.length, (index) {
              final item = navItems[index];
              final isSelected = index == currentIndex;

              return GestureDetector(
                onTap: () => onTap(index),
                behavior: HitTestBehavior.opaque,
                child: _AnimatedNavBarItem(
                  item: item,
                  isSelected: isSelected,
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// Model Data untuk Item Navigasi
class _NavItem {
  final IconData icon;
  final String label;
  _NavItem(this.icon, this.label);
}

// Widget Animasi untuk Setiap Item
class _AnimatedNavBarItem extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;

  const _AnimatedNavBarItem({
    required this.item,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Menggunakan TweenAnimationBuilder untuk animasi transisi warna & ukuran
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: isSelected ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut, // Efek membal (bouncy)
      builder: (context, value, child) {
        // Hitungan Warna
        final color = Color.lerp(Colors.grey[400], Colors.blueAccent, value);

        // Hitungan Padding & Ukuran Container (Efek Gembung)
        final double padding = 8 + (6 * value);
        final double containerWidth = isSelected ? 110 : 60; // Lebar gembung saat dipilih

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(horizontal: padding, vertical: 10),
          width: containerWidth,
          decoration: BoxDecoration(
            color: Color.lerp(Colors.white, Colors.blueAccent.withOpacity(0.1), value),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. ANIMASI IKON (Ukuran & Warna)
              Transform.scale(
                scale: 1.0 + (0.2 * value), // Ikon membesar sedikit
                child: Icon(
                  item.icon,
                  color: color,
                  size: 26,
                ),
              ),

              // 2. ANIMASI TEKS (Muncul dari Samping)
              if (isSelected) ...[
                const SizedBox(width: 8),
                // Gunakan ClipRect agar teks muncul mulus dari samping
                Flexible(
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      heightFactor: 1.0,
                      widthFactor: value, // Teks gembung dari samping
                      child: Text(
                        item.label,
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}