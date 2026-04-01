import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class AssignedApartment {
  final int id;
  final String meterId;
  final String number;
  final String towerName;
  final String buildingName;
  final String apartmentInfo;

  AssignedApartment({
    required this.id,
    required this.meterId,
    required this.number,
    required this.towerName,
    required this.buildingName,
    required this.apartmentInfo,
  });

  factory AssignedApartment.fromJson(Map<String, dynamic> json) {
    return AssignedApartment(
      id: json['id'] as int,
      meterId: json['meter_id'] as String? ?? '',
      number: json['number'] as String? ?? '',
      towerName: json['tower_name'] as String? ?? '',
      buildingName: json['building_name'] as String? ?? '',
      apartmentInfo: json['apartment_info'] as String? ?? '',
    );
  }
}

class AuthService {
  final http.Client _client;

  String? _accessToken;
  String? _refreshToken;
  String? _userRole;
  List<AssignedApartment> _assignedApartments = [];

  AuthService({http.Client? client}) : _client = client ?? http.Client();

  String? get accessToken => _accessToken;
  bool get isAuthenticated => _accessToken != null;
  String? get userRole => _userRole;
  List<AssignedApartment> get assignedApartments => _assignedApartments;

  Map<String, String> get authHeaders => {
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  /// Check if a meter_id is assigned to this operator.
  /// Admins can scan any meter.
  bool canAccessMeter(String meterId) {
    if (_userRole == 'admin') return true;
    if (_assignedApartments.isEmpty) return true; // no restrictions if none assigned
    return _assignedApartments.any((a) => a.meterId == meterId);
  }

  /// Get the apartment_id for a given meter_id (null if not found).
  int? getApartmentIdByMeter(String meterId) {
    try {
      return _assignedApartments
          .firstWhere((a) => a.meterId == meterId)
          .id;
    } catch (_) {
      return null;
    }
  }

  /// Login with username and password. Returns true on success.
  Future<bool> login(String username, String password) async {
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

        // Fetch user profile to get role and assigned apartments
        await _fetchUserProfile();
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
        final apartments = data['assigned_apartments'] as List<dynamic>? ?? [];
        _assignedApartments = apartments
            .map((a) => AssignedApartment.fromJson(a as Map<String, dynamic>))
            .toList();
        debugPrint('[Auth] Rol: $_userRole, deptos asignados: ${_assignedApartments.length}');
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
        return true;
      }

      // Refresh token expired, need to login again
      _accessToken = null;
      _refreshToken = null;
      return false;
    } catch (e) {
      debugPrint('[Auth] Error refrescando token: $e');
      return false;
    }
  }

  void logout() {
    _accessToken = null;
    _refreshToken = null;
  }
}
