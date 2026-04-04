import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../domain/models/water_measurement.dart';
import '../../domain/repositories/measurement_repository.dart';
import '../local/pending_measurement_db.dart';
import '../services/api_config.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';

class MeasurementRepositoryImpl implements MeasurementRepository {
  final AuthService _authService;
  final ConnectivityService _connectivity;
  final SyncService _syncService;

  MeasurementRepositoryImpl({
    required AuthService authService,
    required ConnectivityService connectivity,
    required SyncService syncService,
  })  : _authService = authService,
        _connectivity = connectivity,
        _syncService = syncService;

  @override
  Future<bool> submitMeasurement(WaterMeasurement measurement) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.measurementsUrl),
      );
      request.headers.addAll(_authService.authHeaders);

      // Add fields
      if (measurement.apartmentId != null) {
        request.fields['apartment'] = measurement.apartmentId.toString();
      }
      request.fields['reading_value'] = measurement.value;
      request.fields['ocr_value'] = measurement.ocrValue;
      request.fields['modified_by_user'] = measurement.modifiedByUser.toString();
      request.fields['captured_at'] = measurement.dateTime.toIso8601String();

      // Add photo file
      final photoFile = File(measurement.photoPath);
      if (await photoFile.exists()) {
        request.files.add(await http.MultipartFile.fromPath(
          'photo',
          measurement.photoPath,
        ));
      }

      debugPrint('[API] Enviando medición...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('[API] Submit status: ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      }

      if (response.statusCode == 401) {
        final refreshed = await _authService.refreshAccessToken();
        if (refreshed) {
          return submitMeasurement(measurement);
        }
      }

      debugPrint('[API] Submit error: ${response.body}');
      await _saveLocally(measurement);
      return false;
    } on SocketException {
      debugPrint('[API] No connection — saving locally');
      await _saveLocally(measurement);
      return false;
    } catch (e) {
      debugPrint('[API] Submit exception: $e');
      await _saveLocally(measurement);
      return false;
    }
  }

  /// Returns true if currently offline
  bool get isOffline => !_connectivity.isOnline;

  /// Save measurement to local queue for later sync
  Future<void> _saveLocally(WaterMeasurement measurement) async {
    final pending = PendingMeasurement(
      apartmentId: measurement.apartmentId,
      meterId: measurement.meterId,
      apartmentInfo: measurement.apartmentInfo,
      value: measurement.value,
      ocrValue: measurement.ocrValue,
      modifiedByUser: measurement.modifiedByUser,
      photoPath: measurement.photoPath,
      capturedAt: measurement.dateTime.toIso8601String(),
    );
    await _syncService.enqueue(pending);
    debugPrint('[API] Measurement saved locally for sync');
  }

  /// Explicitly save locally (for offline-aware submit)
  Future<void> saveForLaterSync(WaterMeasurement measurement) async {
    await _saveLocally(measurement);
  }

  @override
  Future<List<WaterMeasurement>> getRecentMeasurements() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.measurementsUrl),
        headers: {
          'Content-Type': 'application/json',
          ..._authService.authHeaders,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List<dynamic>? ?? data as List<dynamic>;
        return results
            .map((json) => WaterMeasurement.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      if (response.statusCode == 401) {
        final refreshed = await _authService.refreshAccessToken();
        if (refreshed) {
          return getRecentMeasurements();
        }
      }

      return [];
    } catch (e) {
      debugPrint('[API] GetRecent error: $e');
      return [];
    }
  }
}
