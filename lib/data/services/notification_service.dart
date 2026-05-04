import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/models/app_notification.dart';
import 'api_config.dart';
import 'auth_service.dart';

class NotificationService {
  NotificationService({required this.authService, http.Client? client})
      : _client = client ?? http.Client();

  final AuthService authService;
  final http.Client _client;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        ...authService.authHeaders,
      };

  Future<List<AppNotification>> fetchAll({bool unreadOnly = false}) async {
    final uri = Uri.parse(ApiConfig.notificationsUrl).replace(
      queryParameters: {
        'page_size': '100',
        if (unreadOnly) 'unread': '1',
      },
    );
    try {
      final res = await _client.get(uri, headers: _headers);
      if (res.statusCode != 200) {
        debugPrint('[Notifications] fetchAll status=${res.statusCode}');
        return [];
      }
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      final results = body is Map<String, dynamic>
          ? (body['results'] as List<dynamic>? ?? [])
          : (body as List<dynamic>);
      return results
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[Notifications] fetchAll error: $e');
      return [];
    }
  }

  Future<int> unreadCount() async {
    final uri = Uri.parse('${ApiConfig.notificationsUrl}unread_count/');
    try {
      final res = await _client.get(uri, headers: _headers);
      if (res.statusCode != 200) return 0;
      final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return (body['count'] as int?) ?? 0;
    } catch (e) {
      debugPrint('[Notifications] unreadCount error: $e');
      return 0;
    }
  }

  Future<bool> markAsRead(int id) async {
    final uri = Uri.parse('${ApiConfig.notificationsUrl}$id/mark_read/');
    try {
      final res = await _client.post(uri, headers: _headers);
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[Notifications] markAsRead error: $e');
      return false;
    }
  }

  Future<bool> markAllAsRead() async {
    final uri = Uri.parse('${ApiConfig.notificationsUrl}mark_all_read/');
    try {
      final res = await _client.post(uri, headers: _headers);
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[Notifications] markAllAsRead error: $e');
      return false;
    }
  }
}
