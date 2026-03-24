import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/face_recognition_service.dart';
import '../services/auth_service.dart';

class ScanWajahPage extends StatefulWidget {
  const ScanWajahPage({super.key});

  @override
  State<ScanWajahPage> createState() => _ScanWajahPageState();
}

class _ScanWajahPageState extends State<ScanWajahPage> {
  CameraController? _controller;
  FaceDetector? _faceDetector;
  final FaceRecognitionService _recognitionService = FaceRecognitionService();
  final AuthService _authService = AuthService();

  bool _isBusy = false;
  bool _isUploading = false;
  double _progress = 0.0;
  String _alertMessage = "Menyiapkan Kamera...";
  int _statusColor = 1;

  bool _hasBlinked = false;
  bool _isSmiling = false;

  // Variabel untuk menyimpan tingkat kecerahan asli HP user
  double _originalBrightness = 0.5;

  final cloudinary = CloudinaryPublic('dubjinrem', 'face_scan', cache: false);

  @override
  void initState() {
    super.initState();
    _initBrightnessSettings(); // Ambil setelan asli lalu terangkan
    _initializeMLKit();
    _initScanner();
  }

  // Simpan kecerahan asli (misal 0) baru naikkan ke 1.0
  Future<void> _initBrightnessSettings() async {
    try {
      _originalBrightness = await ScreenBrightness().current;
      await ScreenBrightness().setScreenBrightness(1.0);
    } catch (e) {
      debugPrint("Gagal atur kecerahan: $e");
    }
  }

  // Fungsi sakti untuk balikin cahaya ke kondisi awal
  Future<void> _resetBrightness() async {
    try {
      await ScreenBrightness().resetScreenBrightness();
      // Atau paksa ke nilai awal jika reset bawaan plugin gagal
      await ScreenBrightness().setScreenBrightness(_originalBrightness);
    } catch (e) {
      debugPrint("Gagal reset kecerahan: $e");
    }
  }

  void _initializeMLKit() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
  }

  Future<void> _initScanner() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front);

    _controller = CameraController(
      front,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );

    try {
      await _controller!.initialize();
      _controller!.startImageStream((image) {
        if (_isBusy || _isUploading || !mounted) return;
        _processCameraImage(image);
      });
      if (mounted) setState(() {});
    } catch (e) {
      _updateUI("Kamera Gagal Dimuat", 0, 0.0);
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    _isBusy = true;
    try {
      final inputImage = _inputImageFromCameraImage(image);
      final faces = await _faceDetector!.processImage(inputImage);

      if (faces.isEmpty) {
        _updateUI("Wajah Tidak Terdeteksi", 0, 0.0);
      } else {
        final face = faces.first;
        if (!_hasBlinked) {
          _updateUI("Silakan Berkedip...", 1, 0.3);
          if ((face.leftEyeOpenProbability ?? 1.0) < 0.25) _hasBlinked = true;
        } else if (!_isSmiling) {
          _updateUI("Sekarang Tersenyum...", 1, 0.6);
          if ((face.smilingProbability ?? 0.0) > 0.75) _isSmiling = true;
        } else {
          _updateUI("Memproses Wajah...", 2, 0.9);
          _verifyAndProcess();
        }
      }
    } catch (e) {
      debugPrint("ML Error: $e");
    }
    _isBusy = false;
  }

  InputImage _inputImageFromCameraImage(CameraImage image) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation270deg,
        format: InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  Future<void> _verifyAndProcess() async {
    if (_isUploading) return;
    _isUploading = true;

    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    bool isVerifikasiMode = args?['isVerifikasi'] ?? false;
    List<double>? embeddingAsli = args?['embeddingAsli'] != null
        ? List<double>.from(args?['embeddingAsli'])
        : null;

    try {
      await _controller!.stopImageStream();
      XFile file = await _controller!.takePicture();
      File capturedFile = File(file.path);

      List<double>? currentEmb = await _recognitionService.getEmbedding(capturedFile);
      if (currentEmb == null) {
        _updateUI("Gagal Membaca Wajah", 0, 0.0);
        await Future.delayed(const Duration(seconds: 2));
        _resetState();
        return;
      }

      if (isVerifikasiMode && embeddingAsli != null) {
        double score = _recognitionService.compareFaces(embeddingAsli, currentEmb);
        if (score < 0.82) {
          _updateUI("Wajah Tidak Cocok!", 0, 0.0);
          await Future.delayed(const Duration(seconds: 2));
          _resetState();
          return;
        }
        _updateUI("Verifikasi Berhasil!", 2, 1.0);
      } else {
        _updateUI("Menyimpan Data Wajah...", 1, 0.95);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .update({
          'face_embedding': currentEmb,
          'isFaceRegistered': true
        });
      }

      _updateUI("Mengirim Data...", 2, 1.0);
      CloudinaryResponse res = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(capturedFile.path, resourceType: CloudinaryResourceType.Image),
      );

      await _authService.simpanAbsensi(res.secureUrl);

      // Sebelum pindah halaman, kembalikan cahaya ke normal
      await _resetBrightness();

      if (mounted) {
        String role = args?['role'] ?? 'user';
        String route = role == 'admin' ? '/home_admin' : '/home_user';
        Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
      }
    } catch (e) {
      _updateUI("Error: Terjadi Gangguan", 0, 0.0);
      await Future.delayed(const Duration(seconds: 2));
      _resetState();
    }
  }

  void _resetState() {
    if (!mounted) return;
    setState(() {
      _hasBlinked = false;
      _isSmiling = false;
      _isUploading = false;
      _progress = 0.0;
    });
    _initScanner();
  }

  void _updateUI(String msg, int color, double prog) {
    if (mounted) {
      setState(() {
        _alertMessage = msg;
        _statusColor = color;
        _progress = prog;
      });
    }
  }

  @override
  void dispose() {
    _resetBrightness(); // Pastikan cahaya balik normal saat widget dihancurkan
    _controller?.dispose();
    _faceDetector?.close();
    _recognitionService.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color uiColor = _statusColor == 0 ? Colors.red : (_statusColor == 1 ? Colors.orange : Colors.green);

    // PopScope akan menangkap aksi 'Back' dan mereset cahaya
    return PopScope(
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          await _resetBrightness();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            if (_controller != null && _controller!.value.isInitialized)
              Positioned.fill(child: CameraPreview(_controller!)),

            Positioned.fill(child: CustomPaint(painter: FaceOverlayPainter(color: uiColor))),

            Positioned(
              bottom: 80, left: 20, right: 20,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _alertMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: uiColor),
                    ),
                    const SizedBox(height: 15),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 10,
                        backgroundColor: Colors.grey[200],
                        color: uiColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FaceOverlayPainter extends CustomPainter {
  final Color color;
  FaceOverlayPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = Colors.white; // Background putih solid
    final holeRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 280,
      height: 380,
    );

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addOval(holeRect),
      ),
      backgroundPaint,
    );

    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawOval(holeRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}