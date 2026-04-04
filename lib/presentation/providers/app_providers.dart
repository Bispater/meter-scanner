import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local/pending_measurement_db.dart';
import '../../data/repositories/measurement_repository_impl.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/connectivity_service.dart';
import '../../data/services/ocr_service_impl.dart';
import '../../data/services/sync_service.dart';
import '../../domain/models/qr_scan_data.dart';
import '../../domain/models/water_measurement.dart';
import '../../domain/repositories/measurement_repository.dart';

// Auth service (singleton)
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Connectivity service (singleton — initialized in main.dart)
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

// Pending measurement database (singleton)
final pendingDbProvider = Provider<PendingMeasurementDb>((ref) {
  return PendingMeasurementDb();
});

// Sync service (singleton — initialized in main.dart)
final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.read(pendingDbProvider);
  final connectivity = ref.read(connectivityServiceProvider);
  final authService = ref.read(authServiceProvider);
  return SyncService(
    db: db,
    connectivity: connectivity,
    authService: authService,
  );
});

// Repository provider
final measurementRepositoryProvider = Provider<MeasurementRepository>((ref) {
  final authService = ref.read(authServiceProvider);
  final connectivity = ref.read(connectivityServiceProvider);
  final syncService = ref.read(syncServiceProvider);
  return MeasurementRepositoryImpl(
    authService: authService,
    connectivity: connectivity,
    syncService: syncService,
  );
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
