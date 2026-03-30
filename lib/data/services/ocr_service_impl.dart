import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../domain/services/ocr_service.dart';

class OcrServiceImpl implements OcrService {
  static const String _apiKey = 'AIzaSyCK39-3GKIxiDlbi5o27K6nAIDIZxCnUEI';

  late final GenerativeModel _model;

  static const String _prompt =
      'Eres un sistema automatizado experto en lectura de medidores de agua. '
      'Tu única tarea es extraer el número del consumo de agua actual. '
      'Reglas: '
      '1. Busca los números principales en los rodillos o diales centrales. '
      '2. Ignora por completo cualquier número de serie impreso en la carcasa. '
      '3. Ignora marcas de rotulador o marcador negro escritas sobre el cristal. '
      '4. Devuelve ÚNICAMENTE los dígitos de la lectura (incluyendo ceros a la '
      'izquierda si los hay). No agregues texto, ni explicaciones, ni unidades como m3.';

  /// Matches MeterOverlayPainter circle: radius = width * 0.38 → diameter = 76%
  static const double _circleDiameterRatio = 0.76;

  OcrServiceImpl() {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
    );
  }

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

  /// Sends the image at [imagePath] directly to Gemini (no crop).
  /// Use this when the image is already cropped.
  Future<String> analyzeImage(String imagePath) async {
    final Uint8List imageBytes = await File(imagePath).readAsBytes();

    final content = [
      Content.multi([
        TextPart(_prompt),
        DataPart('image/jpeg', imageBytes),
      ]),
    ];

    debugPrint('[Gemini] Enviando imagen (${imageBytes.length} bytes)...');
    final response = await _model.generateContent(content);
    final text = response.text?.trim() ?? '';
    debugPrint('[Gemini] Respuesta: "$text"');

    if (text.isEmpty) {
      throw Exception('Gemini devolvió respuesta vacía');
    }
    return text;
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
      debugPrint('[Gemini] Circle crop: ${clampedW}x$clampedH → $outPath');
      return outPath;
    } catch (e) {
      debugPrint('[Gemini] Error en crop: $e');
      return null;
    }
  }
}
