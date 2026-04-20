import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../../domain/models/meter_reading_layout.dart';
import 'api_config.dart';

const _kRefreshTokenKey = 'metscan_refresh_token';
const _kRememberSessionKey = 'metscan_remember_session';

class AssignedApartment {
  final int id;
  final String meterId;
  final String qrCode;
  final String number;
  final String towerName;
  final String buildingName;
  final String apartmentInfo;
  final String readingLayout;

  AssignedApartment({
    required this.id,
    required this.meterId,
    required this.qrCode,
    required this.number,
    required this.towerName,
    required this.buildingName,
    required this.apartmentInfo,
    this.readingLayout = meterLayoutA,
  });

  factory AssignedApartment.fromJson(Map<String, dynamic> json) {
    final meterId = json['meter_id'] as String? ?? '';
    final qrCode = json['qr_code'] as String? ?? '';
    return AssignedApartment(
      id: json['id'] as int,
      meterId: meterId,
      qrCode: qrCode.isNotEmpty ? qrCode : meterId,
      number: json['number'] as String? ?? '',
      towerName: json['tower_name'] as String? ?? '',
      buildingName: json['building_name'] as String? ?? '',
      apartmentInfo: json['apartment_info'] as String? ?? '',
      readingLayout: normalizeMeterReadingLayout(json['reading_layout'] as String?),
    );
  }
}

class CyclePendingApartment {
  final int id;
  final String meterId;
  final String qrCode;
  final String number;
  final int floor;
  final String towerName;
  final String buildingName;
  final String apartmentInfo;
  final String readingLayout;

  CyclePendingApartment({
    required this.id,
    required this.meterId,
    required this.qrCode,
    required this.number,
    required this.floor,
    required this.towerName,
    required this.buildingName,
    required this.apartmentInfo,
    this.readingLayout = meterLayoutA,
  });

  factory CyclePendingApartment.fromJson(Map<String, dynamic> json) {
    final meterId = json['meter_id'] as String? ?? '';
    final qrCode = json['qr_code'] as String? ?? '';
    return CyclePendingApartment(
      id: json['id'] as int,
      meterId: meterId,
      qrCode: qrCode.isNotEmpty ? qrCode : meterId,
      number: json['number'] as String? ?? '',
      floor: json['floor'] as int? ?? 0,
      towerName: json['tower_name'] as String? ?? '',
      buildingName: json['building_name'] as String? ?? '',
      apartmentInfo: json['apartment_info'] as String? ?? '',
      readingLayout: normalizeMeterReadingLayout(json['reading_layout'] as String?),
    );
  }
}

class CycleInfo {
  final int id;
  final int buildingId;
  final String name;
  final String buildingName;
  final String monthName;
  final int year;
  final int month;
  final String scheduledDate;
  final String deadline;
  final String status;
  final int totalAssigned;
  final int measuredCount;
  final int pendingCount;
  final List<CyclePendingApartment> pendingApartments;

  CycleInfo({
    required this.id,
    this.buildingId = 0,
    required this.name,
    required this.buildingName,
    required this.monthName,
    required this.year,
    required this.month,
    required this.scheduledDate,
    required this.deadline,
    required this.status,
    required this.totalAssigned,
    required this.measuredCount,
    required this.pendingCount,
    required this.pendingApartments,
  });

  double get progressPct =>
      totalAssigned == 0 ? 1.0 : measuredCount / totalAssigned;

  factory CycleInfo.fromJson(Map<String, dynamic> json) => CycleInfo(
        id: json['id'] as int,
        buildingId: json['building_id'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        buildingName: json['building_name'] as String? ?? '',
        monthName: json['month_name'] as String? ?? '',
        year: json['year'] as int? ?? 0,
        month: json['month'] as int? ?? 0,
        scheduledDate: json['scheduled_date'] as String? ?? '',
        deadline: json['deadline'] as String? ?? '',
        status: json['status'] as String? ?? '',
        totalAssigned: json['total_assigned'] as int? ?? 0,
        measuredCount: json['measured_count'] as int? ?? 0,
        pendingCount: json['pending_count'] as int? ?? 0,
        pendingApartments: (json['pending_apartments'] as List<dynamic>? ?? [])
            .map((e) => CyclePendingApartment.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class AuthService extends ChangeNotifier {
  final http.Client _client;
  final FlutterSecureStorage _secureStorage;

  String? _accessToken;
  String? _refreshToken;
  String? _userRole;
  String? _displayName;
  List<AssignedApartment> _assignedApartments = [];
  List<CycleInfo> _activeCycles = [];

  AuthService({
    http.Client? client,
    FlutterSecureStorage? secureStorage,
  })  : _client = client ?? http.Client(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Call once at startup when using "Mantener sesión iniciada".
  Future<void> loadPersistedSession() async {
    try {
      final remember = await _secureStorage.read(key: _kRememberSessionKey);
      final storedRefresh = await _secureStorage.read(key: _kRefreshTokenKey);
      if (remember != 'true' || storedRefresh == null || storedRefresh.isEmpty) {
        notifyListeners();
        return;
      }
      _refreshToken = storedRefresh;
      final ok = await refreshAccessToken();
      if (ok) {
        await _fetchUserProfile();
      } else {
        await _clearPersistedTokens();
      }
    } catch (e) {
      debugPrint('[Auth] loadPersistedSession: $e');
      await _clearPersistedTokens();
    }
    notifyListeners();
  }

  Future<void> _persistTokensIfRemembered(bool rememberMe) async {
    if (rememberMe && _refreshToken != null) {
      await _secureStorage.write(key: _kRememberSessionKey, value: 'true');
      await _secureStorage.write(key: _kRefreshTokenKey, value: _refreshToken!);
    } else {
      await _clearPersistedTokens();
    }
  }

  Future<void> _clearPersistedTokens() async {
    await _secureStorage.delete(key: _kRememberSessionKey);
    await _secureStorage.delete(key: _kRefreshTokenKey);
  }

  String? get accessToken => _accessToken;
  bool get isAuthenticated => _accessToken != null;
  String? get userRole => _userRole;
  String? get displayName => _displayName;
  List<AssignedApartment> get assignedApartments => _assignedApartments;
  List<CycleInfo> get activeCycles => _activeCycles;

  Map<String, String> get authHeaders => {
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  /// Check if a qr_code is assigned to this operator.
  /// Falls back to meter_id check for backward compat.
  /// Admins can scan any code.
  bool canAccessByQrCode(String code) {
    if (_userRole == 'admin') return true;
    if (_assignedApartments.isEmpty) return true;
    return _assignedApartments.any((a) => a.qrCode == code || a.meterId == code);
  }

  /// Get the apartment_id for a given qr_code or meter_id (null if not found).
  int? getApartmentIdByQrCode(String code) {
    try {
      return _assignedApartments
          .firstWhere((a) => a.qrCode == code || a.meterId == code)
          .id;
    } catch (_) {
      return null;
    }
  }

  /// Legacy: Check if a meter_id is assigned to this operator.
  bool canAccessMeter(String meterId) => canAccessByQrCode(meterId);

  /// Legacy: Get the apartment_id for a given meter_id.
  int? getApartmentIdByMeter(String meterId) => getApartmentIdByQrCode(meterId);

  /// [reading_layout] A/B for the assigned apartment matching [code] (qr_code or meter_id).
  String getReadingLayoutForQrOrMeter(String code) {
    try {
      final a = _assignedApartments.firstWhere(
        (x) => x.qrCode == code || x.meterId == code,
      );
      return normalizeMeterReadingLayout(a.readingLayout);
    } catch (_) {
      return meterLayoutA;
    }
  }

  /// Login with username and password. [rememberMe] guarda el refresh token en el dispositivo.
  Future<bool> login(
    String username,
    String password, {
    bool rememberMe = true,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse(ApiConfig.loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access'];
        _refreshToken = data['refresh'];
        debugPrint('[Auth] Login exitoso');

        await _fetchUserProfile();
        await _persistTokensIfRemembered(rememberMe);
        notifyListeners();
        return true;
      }

      debugPrint('[Auth] Login fallido: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('[Auth] Error en login: $e');
      return false;
    }
  }

  /// Fetch user profile from /me endpoint.
  Future<void> _fetchUserProfile() async {
    try {
      final response = await _client.get(
        Uri.parse(ApiConfig.meUrl),
        headers: {
          'Content-Type': 'application/json',
          ...authHeaders,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _userRole = data['role'] as String?;
        _displayName = [
          data['first_name'] as String? ?? '',
          data['last_name'] as String? ?? '',
        ].where((s) => s.isNotEmpty).join(' ');
        if (_displayName!.isEmpty) _displayName = data['username'] as String?;
        final apartments = data['assigned_apartments'] as List<dynamic>? ?? [];
        _assignedApartments = apartments
            .map((a) => AssignedApartment.fromJson(a as Map<String, dynamic>))
            .toList();
        final cycles = data['active_cycles'] as List<dynamic>? ?? [];
        _activeCycles = cycles
            .map((c) => CycleInfo.fromJson(c as Map<String, dynamic>))
            .toList();
        debugPrint('[Auth] Rol: $_userRole, deptos asignados: ${_assignedApartments.length}, ciclos activos: ${_activeCycles.length}');
      }
    } catch (e) {
      debugPrint('[Auth] Error obteniendo perfil: $e');
    }
  }

  /// Try to refresh the access token using the refresh token.
  Future<bool> refreshAccessToken() async {
    if (_refreshToken == null) return false;

    try {
      final response = await _client.post(
        Uri.parse(ApiConfig.refreshUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': _refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access'];
        debugPrint('[Auth] Token refrescado');
        final remember = await _secureStorage.read(key: _kRememberSessionKey);
        if (remember == 'true' && _refreshToken != null) {
          await _secureStorage.write(key: _kRefreshTokenKey, value: _refreshToken!);
        }
        return true;
      }

      _accessToken = null;
      _refreshToken = null;
      await _clearPersistedTokens();
      return false;
    } catch (e) {
      debugPrint('[Auth] Error refrescando token: $e');
      return false;
    }
  }

  Future<void> logout() async {
    _accessToken = null;
    _refreshToken = null;
    _userRole = null;
    _displayName = null;
    _assignedApartments = [];
    _activeCycles = [];
    await _clearPersistedTokens();
    notifyListeners();
  }

  /// Re-fetch the profile without logging in again (useful to refresh cycle progress).
  Future<void> refreshProfile() async {
    await _fetchUserProfile();
    notifyListeners();
  }
}
