import '../meter_reading_input.dart';
import '../reading_value_codec.dart';
import 'meter_reading_layout.dart';

class WaterMeasurement {
  final String? id;
  final int? apartmentId;
  final String meterId;
  final String apartmentInfo;
  final String apartmentNumber;
  final String towerName;
  final String buildingName;
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
    this.apartmentNumber = '',
    this.towerName = '',
    this.buildingName = '',
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
      'apartment_number': apartmentNumber,
      'tower_name': towerName,
      'building_name': buildingName,
    };
  }

  factory WaterMeasurement.fromJson(Map<String, dynamic> json) {
    final capturedRaw = json['captured_at'] as String? ?? json['date_time'] as String?;
    final parsedDate = capturedRaw != null ? DateTime.tryParse(capturedRaw) : null;
    final layout = json['reading_layout'] as String?;
    final rv = json['reading_value'] != null ? json['reading_value'].toString() : json['value']?.toString() ?? '';
    return WaterMeasurement(
      id: json['id']?.toString() ?? '',
      apartmentId: json['apartment'] as int?,
      meterId: json['meter_id'] as String? ?? '',
      apartmentInfo: json['apartment_info'] as String? ??
          json['apartment_number'] as String? ?? '',
      apartmentNumber: json['apartment_number'] as String? ?? '',
      towerName: json['tower_name'] as String? ?? '',
      buildingName: json['building_name'] as String? ?? '',
      value: normalizeApiReadingToDisplayDigits(rv, layout),
      ocrValue: json['ocr_value'] as String? ?? '',
      modifiedByUser: json['modified_by_user'] as bool? ?? false,
      photoPath: json['photo_url'] as String? ?? json['photo_path'] as String? ?? '',
      dateTime: parsedDate?.toLocal() ?? DateTime.now(),
      readingLayout: layout,
    );
  }

  WaterMeasurement copyWith({
    String? id,
    int? apartmentId,
    String? meterId,
    String? apartmentInfo,
    String? apartmentNumber,
    String? towerName,
    String? buildingName,
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
      apartmentNumber: apartmentNumber ?? this.apartmentNumber,
      towerName: towerName ?? this.towerName,
      buildingName: buildingName ?? this.buildingName,
      value: value ?? this.value,
      ocrValue: ocrValue ?? this.ocrValue,
      modifiedByUser: modifiedByUser ?? this.modifiedByUser,
      photoPath: photoPath ?? this.photoPath,
      dateTime: dateTime ?? this.dateTime,
      readingLayout: readingLayout ?? this.readingLayout,
    );
  }

  String get displayLocation {
    if (buildingName.isNotEmpty || towerName.isNotEmpty || apartmentNumber.isNotEmpty) {
      final parts = <String>[
        if (buildingName.isNotEmpty) buildingName,
        if (towerName.isNotEmpty) towerName,
        if (apartmentNumber.isNotEmpty) 'Depto $apartmentNumber',
      ];
      return parts.join(' · ');
    }
    return apartmentInfo;
  }

  /// Display helper según cara A/B (usa [readingLayout] o A por defecto).
  String get formattedMeterValue {
    final layout = normalizeMeterReadingLayout(readingLayout);
    final digits = value.replaceAll(RegExp(r'[^0-9Xx]'), '').toUpperCase();
    if (digits.isEmpty) return value;
    if (layout == meterLayoutA || layout == meterLayoutB) {
      return formatCubicMetersTypeA5Plus4(digits);
    }
    return formatMeterDigitsForDisplay(digits, layout);
  }
}
