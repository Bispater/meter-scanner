import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class AuthService {
  final http.Client _client;

  String? _accessToken;
  String? _refreshToken;

  AuthService({http.Client? client}) : _client = client ?? http.Client();

  String? get accessToken => _accessToken;
  bool get isAuthenticated => _accessToken != null;

  Map<String, String> get authHeaders => {
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

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
        return true;
      }

      debugPrint('[Auth] Login fallido: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('[Auth] Error en login: $e');
      return false;
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
