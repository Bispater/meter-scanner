enum AppNotificationType {
  measurementRejected,
  measurementValidated,
  generic,
}

AppNotificationType _parseType(String? raw) {
  switch (raw) {
    case 'measurement_rejected':
      return AppNotificationType.measurementRejected;
    case 'measurement_validated':
      return AppNotificationType.measurementValidated;
    default:
      return AppNotificationType.generic;
  }
}

class AppNotification {
  final int id;
  final AppNotificationType type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;
  final int? measurementId;
  final Map<String, dynamic> payload;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.readAt,
    this.measurementId,
    this.payload = const {},
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int,
      type: _parseType(json['type'] as String?),
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      isRead: (json['is_read'] as bool?) ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at'] as String) : null,
      measurementId: json['measurement_id'] as int?,
      payload: (json['payload'] as Map<String, dynamic>?) ?? const {},
    );
  }

  String? get rejectionCategory {
    final cat = payload['category'];
    return cat is String ? cat : null;
  }

  String? get rejectionReason {
    final r = payload['reason'];
    return r is String && r.isNotEmpty ? r : null;
  }

  String? get apartmentNumber {
    final a = payload['apartment_number'];
    return a is String ? a : (a?.toString());
  }
}
