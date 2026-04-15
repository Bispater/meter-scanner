class WaterMeasurement {
  final String? id;
  final int? apartmentId;
  final String meterId;
  final String apartmentInfo;
  final String value;
  final String ocrValue;
  final bool modifiedByUser;
  final String photoPath;
  final DateTime dateTime;

  WaterMeasurement({
    this.id,
    this.apartmentId,
    required this.meterId,
    required this.apartmentInfo,
    required this.value,
    this.ocrValue = '',
    this.modifiedByUser = false,
    required this.photoPath,
    required this.dateTime,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (apartmentId != null) 'apartment': apartmentId,
      'reading_value': value,
      'ocr_value': ocrValue,
      'modified_by_user': modifiedByUser,
      'captured_at': dateTime.toIso8601String(),
      'meter_id': meterId,
      'apartment_info': apartmentInfo,
    };
  }

  factory WaterMeasurement.fromJson(Map<String, dynamic> json) {
    return WaterMeasurement(
      id: json['id']?.toString() ?? '',
      apartmentId: json['apartment'] as int?,
      meterId: json['meter_id'] as String? ?? '',
      apartmentInfo: json['apartment_info'] as String? ??
          json['apartment_number'] as String? ?? '',
      value: json['reading_value']?.toString() ?? json['value'] as String? ?? '',
      ocrValue: json['ocr_value'] as String? ?? '',
      modifiedByUser: json['modified_by_user'] as bool? ?? false,
      photoPath: json['photo_url'] as String? ?? json['photo_path'] as String? ?? '',
      dateTime: json['captured_at'] != null
          ? DateTime.parse(json['captured_at'] as String)
          : json['date_time'] != null
              ? DateTime.parse(json['date_time'] as String)
              : DateTime.now(),
    );
  }

  WaterMeasurement copyWith({
    String? id,
    int? apartmentId,
    String? meterId,
    String? apartmentInfo,
    String? value,
    String? ocrValue,
    bool? modifiedByUser,
    String? photoPath,
    DateTime? dateTime,
  }) {
    return WaterMeasurement(
      id: id ?? this.id,
      apartmentId: apartmentId ?? this.apartmentId,
      meterId: meterId ?? this.meterId,
      apartmentInfo: apartmentInfo ?? this.apartmentInfo,
      value: value ?? this.value,
      ocrValue: ocrValue ?? this.ocrValue,
      modifiedByUser: modifiedByUser ?? this.modifiedByUser,
      photoPath: photoPath ?? this.photoPath,
      dateTime: dateTime ?? this.dateTime,
    );
  }

  /// Display helper for meter-style reading: 00546,1188
  String get formattedMeterValue {
    final digits = value.replaceAll(RegExp(r'[^0-9Xx]'), '').toUpperCase();
    if (digits.isEmpty) return value;
    final right = digits.length >= 4 ? digits.substring(digits.length - 4) : digits.padLeft(4, '0');
    final leftRaw = digits.length > 4 ? digits.substring(0, digits.length - 4) : '';
    final left = leftRaw.padLeft(5, '0');
    return '$left,$right';
  }
}
