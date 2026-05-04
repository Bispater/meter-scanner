import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../domain/models/meter_reading_layout.dart';
import '../../domain/reading_value_codec.dart';
import '../../domain/models/water_measurement.dart';
import '../../domain/repositories/measurement_repository.dart';
import '../services/api_config.dart';
import '../services/auth_service.dart';

class MeasurementRepositoryImpl implements MeasurementRepository {
  final AuthService _authService;

  MeasurementRepositoryImpl({required AuthService authService})
      : _authService = authService;

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
      final rv = measurement.value.trim();
      if (rv.isNotEmpty) {
        final m3 = readingDigitsToApiM3String(
          rv,
          measurement.readingLayout ?? meterLayoutA,
        );
        if (m3.isNotEmpty) {
          request.fields['reading_value'] = m3;
        }
      }
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
        throw Exception('Su sesión ha expirado. Por favor inicie sesión nuevamente.');
      }

      debugPrint('[API] Submit error: ${response.body}');
      throw Exception(_parseApiError(response.body));
    } catch (e) {
      debugPrint('[API] Submit exception: $e');
      rethrow;
    }
  }

  /// Extracts the first human-readable error message from a DRF error response body.
  String _parseApiError(String body) {
    if (body.isEmpty) return 'Error al enviar la medición. Intente nuevamente.';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        for (final value in decoded.values) {
          if (value is List && value.isNotEmpty) {
            final first = value.first;
            if (first is Map && first.containsKey('message')) return first['message'].toString();
            return first.toString();
          }
          if (value is String) return value;
          if (value is Map) {
            for (final inner in value.values) {
              if (inner is List && inner.isNotEmpty) return inner.first.toString();
              if (inner is String) return inner;
            }
          }
        }
        return decoded.toString();
      }
      if (decoded is List && decoded.isNotEmpty) return decoded.first.toString();
    } catch (_) {}
    return body.length > 200 ? 'Error al enviar la medición. Intente nuevamente.' : body;
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
