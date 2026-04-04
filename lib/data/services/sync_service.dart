import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../local/pending_measurement_db.dart';
import 'api_config.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';

class SyncService {
  final PendingMeasurementDb _db;
  final ConnectivityService _connectivity;
  final AuthService _authService;

  static const int _maxRetries = 5;

  bool _isSyncing = false;
  StreamSubscription<bool>? _connectivitySub;

  final _pendingCountController = StreamController<int>.broadcast();
  Stream<int> get pendingCountStream => _pendingCountController.stream;

  int _lastKnownCount = 0;
  int get pendingCount => _lastKnownCount;

  SyncService({
    required PendingMeasurementDb db,
    required ConnectivityService connectivity,
    required AuthService authService,
  })  : _db = db,
        _connectivity = connectivity,
        _authService = authService;

  Future<void> init() async {
    _lastKnownCount = await _db.count();
    _pendingCountController.add(_lastKnownCount);
    debugPrint('[SYNC] Init — $_lastKnownCount pending measurements');

    _connectivitySub = _connectivity.onConnectivityChanged.listen((isOnline) {
      if (isOnline) {
        debugPrint('[SYNC] Connection restored — starting sync');
        syncAll();
      }
    });

    // Try initial sync if online
    if (_connectivity.isOnline && _lastKnownCount > 0) {
      syncAll();
    }
  }

  Future<void> enqueue(PendingMeasurement measurement) async {
    await _db.insert(measurement);
    _lastKnownCount = await _db.count();
    _pendingCountController.add(_lastKnownCount);
    debugPrint('[SYNC] Enqueued — $_lastKnownCount pending');
  }

  Future<void> syncAll() async {
    if (_isSyncing) return;
    if (!_connectivity.isOnline) {
      debugPrint('[SYNC] Skip — offline');
      return;
    }

    _isSyncing = true;
    debugPrint('[SYNC] Starting sync...');

    try {
      final pending = await _db.getAll();
      int synced = 0;

      for (final m in pending) {
        if (!_connectivity.isOnline) {
          debugPrint('[SYNC] Lost connection — stopping');
          break;
        }

        if (m.retryCount >= _maxRetries) {
          debugPrint('[SYNC] Skipping #${m.dbId} — max retries reached');
          continue;
        }

        final success = await _uploadMeasurement(m);
        if (success) {
          await _db.delete(m.dbId!);
          synced++;
        } else {
          await _db.updateRetry(
            m.dbId!,
            m.retryCount + 1,
            'Sync failed at ${DateTime.now().toIso8601String()}',
          );
        }
      }

      _lastKnownCount = await _db.count();
      _pendingCountController.add(_lastKnownCount);
      debugPrint('[SYNC] Done — synced $synced, remaining $_lastKnownCount');
    } catch (e) {
      debugPrint('[SYNC] Error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> _uploadMeasurement(PendingMeasurement m) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.measurementsUrl),
      );
      request.headers.addAll(_authService.authHeaders);

      if (m.apartmentId != null) {
        request.fields['apartment'] = m.apartmentId.toString();
      }
      request.fields['reading_value'] = m.value;
      request.fields['ocr_value'] = m.ocrValue;
      request.fields['modified_by_user'] = m.modifiedByUser.toString();
      request.fields['captured_at'] = m.capturedAt;

      final photoFile = File(m.photoPath);
      if (await photoFile.exists()) {
        request.files.add(await http.MultipartFile.fromPath(
          'photo',
          m.photoPath,
        ));
      }

      debugPrint('[SYNC] Uploading #${m.dbId} (meter: ${m.meterId})...');
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201 || response.statusCode == 200) {
        debugPrint('[SYNC] #${m.dbId} uploaded successfully');
        // Clean up local photo after successful upload
        try { await photoFile.delete(); } catch (_) {}
        return true;
      }

      if (response.statusCode == 401) {
        final refreshed = await _authService.refreshAccessToken();
        if (refreshed) {
          return _uploadMeasurement(m);
        }
      }

      debugPrint('[SYNC] #${m.dbId} failed: ${response.statusCode} ${response.body}');
      return false;
    } on SocketException {
      debugPrint('[SYNC] #${m.dbId} — no connection');
      return false;
    } on TimeoutException {
      debugPrint('[SYNC] #${m.dbId} — timeout');
      return false;
    } catch (e) {
      debugPrint('[SYNC] #${m.dbId} — error: $e');
      return false;
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
    _pendingCountController.close();
  }
}
