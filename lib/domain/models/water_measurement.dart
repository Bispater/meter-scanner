import '../meter_reading_input.dart';
import 'meter_reading_layout.dart';

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
  /// `'A'` / `'B'` desde API; si es null se asume A en formateo.
  final String? readingLayout;

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
    this.readingLayout,
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
      value: json['reading_value'] != null ? json['reading_value'].toString() : json['value']?.toString() ?? '',
      ocrValue: json['ocr_value'] as String? ?? '',
      modifiedByUser: json['modified_by_user'] as bool? ?? false,
      photoPath: json['photo_url'] as String? ?? json['photo_path'] as String? ?? '',
      dateTime: json['captured_at'] != null
          ? DateTime.parse(json['captured_at'] as String)
          : json['date_time'] != null
              ? DateTime.parse(json['date_time'] as String)
              : DateTime.now(),
      readingLayout: json['reading_layout'] as String?,
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
    String? readingLayout,
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
      readingLayout: readingLayout ?? this.readingLayout,
    );
  }

  /// Display helper según cara A/B (usa [readingLayout] o A por defecto).
  String get formattedMeterValue {
    final layout = normalizeMeterReadingLayout(readingLayout);
    final digits = value.replaceAll(RegExp(r'[^0-9Xx]'), '').toUpperCase();
    if (digits.isEmpty) return value;
    return formatMeterDigitsForDisplay(digits, layout);
  }
}
