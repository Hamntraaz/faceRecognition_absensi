import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color color;
  final Color textColor;

  // Constructor dengan parameter yang bisa disesuaikan
  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color = Colors.blueAccent, // Warna default
    this.textColor = Colors.white,  // Warna teks default
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, // Tombol melebar penuh
      height: 50,             // Tinggi standar
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), // Sudut membulat
          ),
          elevation: 2,
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}