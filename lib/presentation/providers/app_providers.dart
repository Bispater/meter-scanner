import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/measurement_repository_impl.dart';
import '../../data/services/ocr_service_impl.dart';
import '../../domain/models/qr_scan_data.dart';
import '../../domain/models/water_measurement.dart';
import '../../domain/repositories/measurement_repository.dart';

// Repository provider
final measurementRepositoryProvider = Provider<MeasurementRepository>((ref) {
  return MeasurementRepositoryImpl();
});

// OCR Service provider
final ocrServiceProvider = Provider<OcrServiceImpl>((ref) {
  return OcrServiceImpl();
});

// Current QR scan data
final qrScanDataProvider = StateProvider<QrScanData?>((ref) => null);

// Current captured photo path
final capturedPhotoPathProvider = StateProvider<String?>((ref) => null);

// OCR recognized value
final ocrValueProvider = StateProvider<String>((ref) => '');

// Loading state for submission
final isSubmittingProvider = StateProvider<bool>((ref) => false);

// Submit measurement
final submitMeasurementProvider =
    FutureProvider.family<bool, WaterMeasurement>((ref, measurement) async {
  final repository = ref.read(measurementRepositoryProvider);
  return repository.submitMeasurement(measurement);
});
