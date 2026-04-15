abstract class OcrService {
  Future<String> recognizeText(String imagePath, {String meterReadingType = 'A'});

  Future<String?> cropToCircleZone(String imagePath);

  Future<String> analyzeImage(String imagePath, {String meterReadingType = 'A'});
}
