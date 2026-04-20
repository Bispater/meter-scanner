import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/measurement_repository_impl.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/ocr_service_impl.dart';
import '../../domain/models/qr_scan_data.dart';
import '../../domain/models/water_measurement.dart';
import '../../domain/repositories/measurement_repository.dart';

/// Inicializado en [main] con [overrideWith] y [AuthService.loadPersistedSession].
final authServiceProvider = ChangeNotifierProvider<AuthService>((ref) {
  throw UnimplementedError('AuthService: usar ProviderScope(overrides: ...) desde main.dart');
});

// Repository provider
final measurementRepositoryProvider = Provider<MeasurementRepository>((ref) {
  final authService = ref.read(authServiceProvider);
  return MeasurementRepositoryImpl(authService: authService);
});

// OCR Service provider
final ocrServiceProvider = Provider<OcrServiceImpl>((ref) {
  final authService = ref.read(authServiceProvider);
  return OcrServiceImpl(authService: authService);
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
