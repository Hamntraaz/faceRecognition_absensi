import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:screen_brightness/screen_brightness.dart'; // Import fitur kecerahan
import '../services/auth_service.dart';

class ScanWajahPage extends StatefulWidget {
  const ScanWajahPage({super.key});

  @override
  State<ScanWajahPage> createState() => _ScanWajahPageState();
}

class _ScanWajahPageState extends State<ScanWajahPage> {
  CameraController? _controller;
  FaceDetector? _faceDetector;
  final AuthService _authService = AuthService();

  bool _isBusy = false;
  bool _isUploading = false;
  double _progress = 0.0;
  String _alertMessage = "Menyiapkan Kamera...";
  int _statusColor = 0; // 0: Merah, 1: Kuning, 2: Hijau

  bool _hasBlinked = false;
  bool _isSmiling = false;

  final cloudinary = CloudinaryPublic('dubjinrem', 'face_scan', cache: false);

  @override
  void initState() {
    super.initState();
    _setFullBrightness(); // FIX 1: Set kecerahan maksimal saat mulai
    _initializeMLKit();
    _initScanner();
  }

  // Fungsi untuk mengatur kecerahan layar ke 100%
  Future<void> _setFullBrightness() async {
    try {
      await ScreenBrightness().setScreenBrightness(1.0);
    } catch (e) {
      debugPrint("Gagal mengatur kecerahan: $e");
    }
  }

  // Fungsi untuk reset kecerahan layar ke normal
  Future<void> _resetBrightness() async {
    try {
      await ScreenBrightness().resetScreenBrightness();
    } catch (e) {
      debugPrint("Gagal reset kecerahan: $e");
    }
  }

  void _initializeMLKit() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableTracking: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
  }

  Future<void> _initScanner() async {
    final cameras = await availableCameras();
    final frontCam = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
    );

    _controller = CameraController(
      frontCam,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    try {
      await _controller!.initialize();
      _controller!.startImageStream((image) {
        if (_isBusy || _isUploading) return;
        _processCameraImage(image);
      });
      if (mounted) setState(() => _alertMessage = "Mencari Wajah...");
    } catch (e) {
      debugPrint("Kamera Error: $e");
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    _isBusy = true;
    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) return;

      final faces = await _faceDetector!.processImage(inputImage);

      if (faces.isEmpty) {
        _updateUI("Wajah tidak terdeteksi", 0, 0.0);
      } else {
        final face = faces.first;
        _analyzeLiveness(face);
      }
    } catch (e) {
      debugPrint("Proses Gambar Error: $e");
    } finally {
      _isBusy = false;
    }
  }

  void _analyzeLiveness(Face face) {
    // FIX 2: Validasi posisi wajah di dalam area oval (tengah layar)
    final double previewWidth = _controller!.value.previewSize!.height;
    final double previewHeight = _controller!.value.previewSize!.width;
    final double faceCenterX = face.boundingBox.center.dx;
    final double faceCenterY = face.boundingBox.center.dy;

    // Cek apakah koordinat wajah berada di area oval (tengah)
    bool isInsideOval = faceCenterX > (previewWidth * 0.2) &&
        faceCenterX < (previewWidth * 0.8) &&
        faceCenterY > (previewHeight * 0.2) &&
        faceCenterY < (previewHeight * 0.8);

    if (!isInsideOval) {
      _updateUI("Posisikan Wajah di Dalam Oval", 0, 0.0);
      return;
    }

    double leftEye = face.leftEyeOpenProbability ?? 1.0;
    double rightEye = face.rightEyeOpenProbability ?? 1.0;
    double smile = face.smilingProbability ?? 0.0;

    if (!_hasBlinked && leftEye < 0.4 && rightEye < 0.4) {
      _hasBlinked = true;
    }

    if (_hasBlinked && !_isSmiling && smile > 0.7) {
      _isSmiling = true;
    }

    if (!_hasBlinked) {
      _updateUI("Silakan Berkedip", 1, 0.3);
    } else if (!_isSmiling) {
      _updateUI("Bagus! Sekarang Tersenyum", 1, 0.6);
    } else {
      _updateUI("Verifikasi Berhasil!", 2, 1.0);
      _takeAction();
    }
  }

  void _updateUI(String msg, int colorCode, double prog) {
    if (!mounted) return;
    setState(() {
      _alertMessage = msg;
      _statusColor = colorCode;
      _progress = prog;
    });
  }

  Future<void> _takeAction() async {
    if (_isUploading) return;
    _isUploading = true;

    try {
      // FIX 3: Hentikan stream kamera sebelum pindah halaman untuk cegah Black Screen
      await _controller?.stopImageStream();

      XFile file = await _controller!.takePicture();
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(file.path, resourceType: CloudinaryResourceType.Image),
      );

      await _authService.setFaceRegistered();
      await _authService.simpanAbsensi(response.secureUrl);

      if (mounted) {
        await _resetBrightness(); // Kembalikan kecerahan ke normal
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Absensi Berhasil!")),
        );
        // FIX 4: Gunakan pushAndRemoveUntil agar stack bersih dan tidak Black Screen
        Navigator.pushNamedAndRemoveUntil(context, '/home_user', (route) => false);
      }
    } catch (e) {
      _updateUI("Gagal: $e", 0, 0.0);
      _isUploading = false;
    }
  }

  InputImage? _convertCameraImage(CameraImage image) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation270deg,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    _resetBrightness(); // Pastikan kecerahan kembali normal saat keluar
    _controller?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    Color uiColor = _statusColor == 2 ? Colors.greenAccent : (_statusColor == 1 ? Colors.orangeAccent : Colors.redAccent);

    return Scaffold(
      backgroundColor: Colors.white, // FIX: Background dasar putih
      body: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: 1 / _controller!.value.aspectRatio,
              child: CameraPreview(_controller!),
            ),
          ),
          // Overlay Putih Solid
          CustomPaint(
            size: Size.infinite,
            painter: FaceOverlayPainter(color: uiColor),
          ),
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                if (_isUploading) const CircularProgressIndicator(color: Colors.greenAccent),
                const SizedBox(height: 10),
                Text(
                  _alertMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: uiColor, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 250,
                  height: 10,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _progress,
                      color: uiColor,
                      backgroundColor: Colors.grey[300],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Painter untuk membuat area PUTIH SOLID di luar oval
class FaceOverlayPainter extends CustomPainter {
  final Color color;
  FaceOverlayPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // FIX: Menggunakan Putih Solid (bukan hitam transparan)
    final paint = Paint()..color = Colors.white;
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
      paint,
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