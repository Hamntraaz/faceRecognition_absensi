import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceRecognitionService {
  Interpreter? _interpreter;
  // Ukuran input standar untuk MobileFaceNet
  static const int inputSize = 112;

  FaceRecognitionService() {
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      // Di versi 0.12.0, penggunaan options tetap didukung namun lebih simpel
      final options = InterpreterOptions();

      // Aktifkan ini hanya jika hardware mendukung, jika error Library not found, matikan saja
      // if (Platform.isAndroid) options.addDelegate(XNNPackDelegate());

      _interpreter = await Interpreter.fromAsset(
        'assets/mobilefacenet.tflite', // Pastikan path asset sesuai dengan pubspec.yaml
        options: options,
      );
      print('Model Face Recognition Berhasil Dimuat');
    } catch (e) {
      print('Gagal memuat model: $e');
    }
  }

  Future<List<double>?> getEmbedding(File imageFile) async {
    if (_interpreter == null) {
      print('Interpreter belum siap');
      return null;
    }

    try {
      final bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image == null) return null;

      // Resize gambar ke 112x112 sesuai kebutuhan model
      img.Image resizedImage = img.copyResize(image, width: inputSize, height: inputSize);

      // Konversi gambar ke format Float32 (Normalisasi)
      var input = _imageToByteListFloat32(resizedImage);

      // Output model MobileFaceNet biasanya memiliki 192 dimensi
      var output = List.filled(1 * 192, 0.0).reshape([1, 192]);

      // Menjalankan inferensi
      _interpreter!.run(input, output);

      return List<double>.from(output[0]);
    } catch (e) {
      print('Error saat ekstraksi embedding: $e');
      return null;
    }
  }

  Uint8List _imageToByteListFloat32(img.Image image) {
    var convertedBytes = Float32List(1 * inputSize * inputSize * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;

    for (int i = 0; i < inputSize; i++) {
      for (int j = 0; j < inputSize; j++) {
        // Mendapatkan pixel (x, y)
        var pixel = image.getPixel(j, i);

        // Normalisasi pixel ke rentang -1 hingga 1 (sesuai kebutuhan MobileFaceNet)
        // Library image v4 menggunakan properti .r, .g, .b secara langsung
        buffer[pixelIndex++] = (pixel.r - 128) / 128.0;
        buffer[pixelIndex++] = (pixel.g - 128) / 128.0;
        buffer[pixelIndex++] = (pixel.b - 128) / 128.0;
      }
    }
    return convertedBytes.buffer.asUint8List();
  }

  double compareFaces(List<double> emb1, List<double> emb2) {
    if (emb1.length != emb2.length) return 0.0;

    double dot = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (int i = 0; i < emb1.length; i++) {
      dot += emb1[i] * emb2[i];
      norm1 += emb1[i] * emb1[i];
      norm2 += emb2[i] * emb2[i];
    }

    // Perhitungan Cosine Similarity
    double similarity = dot / (sqrt(norm1) * sqrt(norm2));

    // Mengubah range similarity (-1 s/d 1) ke (0 s/d 1) untuk kemudahan UI
    return (similarity + 1.0) / 2.0;
  }

  void close() {
    _interpreter?.close();
  }
}