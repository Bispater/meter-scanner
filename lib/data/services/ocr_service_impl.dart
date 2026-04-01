import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../domain/services/ocr_service.dart';
import 'api_config.dart';
import 'auth_service.dart';

class OcrServiceImpl implements OcrService {
  final AuthService _authService;

  /// Matches MeterOverlayPainter circle: radius = width * 0.38 → diameter = 76%
  static const double _circleDiameterRatio = 0.76;

  OcrServiceImpl({required AuthService authService})
      : _authService = authService;

  @override
  Future<String> recognizeText(String imagePath) async {
    // Crop + analyze in one step (used when no UI preview is needed)
    final croppedPath = await cropToCircleZone(imagePath);
    final pathToAnalyze = croppedPath ?? imagePath;
    try {
      return await analyzeImage(pathToAnalyze);
    } finally {
      // Clean up temp crop
      if (croppedPath != null) {
        try { await File(croppedPath).delete(); } catch (_) {}
      }
    }
  }

  /// Sends the image at [imagePath] to the Django OCR endpoint.
  /// Use this when the image is already cropped.
  Future<String> analyzeImage(String imagePath) async {
    final file = File(imagePath);
    final bytes = await file.readAsBytes();

    debugPrint('[OCR] Enviando imagen al servidor (${bytes.length} bytes)...');

    final request = http.MultipartRequest('POST', Uri.parse(ApiConfig.ocrUrl));
    request.headers.addAll(_authService.authHeaders);
    request.files.add(http.MultipartFile.fromBytes(
      'photo',
      bytes,
      filename: 'meter_${DateTime.now().millisecondsSinceEpoch}.jpg',
    ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    debugPrint('[OCR] Response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final ocrValue = data['ocr_value'] as String? ?? '';
      debugPrint('[OCR] Valor detectado: "$ocrValue"');

      if (ocrValue.isEmpty) {
        throw Exception('El servidor devolvió respuesta vacía');
      }
      return ocrValue;
    } else if (response.statusCode == 401) {
      // Try to refresh token and retry once
      final refreshed = await _authService.refreshAccessToken();
      if (refreshed) {
        return analyzeImage(imagePath);
      }
      throw Exception('Sesión expirada. Inicie sesión nuevamente.');
    } else {
      debugPrint('[OCR] Error body: ${response.body}');
      try {
        final data = jsonDecode(response.body);
        final msg = data['error'] ?? data['detail'] ?? response.body;
        throw Exception('Error del servidor ($msg) [${response.statusCode}]');
      } catch (e) {
        if (e is Exception && e.toString().contains('Error del servidor')) rethrow;
        throw Exception('Error del servidor (${response.statusCode}): ${response.body}');
      }
    }
  }

  /// Crop a square from the center of the image matching the overlay circle.
  /// The circle guide has diameter = 76% of screen width; the camera preview
  /// fills the screen width, so we crop 76% of image width as a centered square.
  /// Returns the path to a temp JPEG, or null on failure.
  Future<String?> cropToCircleZone(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final original = img.decodeImage(bytes);
      if (original == null) return null;

      final w = original.width;
      final h = original.height;

      // Square side = 76% of image width (matching the overlay circle diameter)
      final side = (w * _circleDiameterRatio).round();
      final x = ((w - side) / 2).round();
      final y = ((h - side) / 2).round();

      // Safety clamp
      final clampedX = x.clamp(0, w - 1);
      final clampedY = y.clamp(0, h - 1);
      final clampedW = side.clamp(1, w - clampedX);
      final clampedH = side.clamp(1, h - clampedY);

      final cropped = img.copyCrop(
        original,
        x: clampedX,
        y: clampedY,
        width: clampedW,
        height: clampedH,
      );

      final dir = await getTemporaryDirectory();
      final outPath = p.join(dir.path, 'meter_circle_crop_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await File(outPath).writeAsBytes(img.encodeJpg(cropped, quality: 90));
      debugPrint('[OCR] Circle crop: ${clampedW}x$clampedH → $outPath');
      return outPath;
    } catch (e) {
      debugPrint('[OCR] Error en crop: $e');
      return null;
    }
  }
}
