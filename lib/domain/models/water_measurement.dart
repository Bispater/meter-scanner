class WaterMeasurement {
  final String id;
  final String meterId;
  final String apartmentInfo;
  final String value;
  final String photoPath;
  final DateTime dateTime;

  WaterMeasurement({
    required this.id,
    required this.meterId,
    required this.apartmentInfo,
    required this.value,
    required this.photoPath,
    required this.dateTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'meter_id': meterId,
      'apartment_info': apartmentInfo,
      'value': value,
      'photo_path': photoPath,
      'date_time': dateTime.toIso8601String(),
    };
  }

  factory WaterMeasurement.fromJson(Map<String, dynamic> json) {
    return WaterMeasurement(
      id: json['id'] as String,
      meterId: json['meter_id'] as String,
      apartmentInfo: json['apartment_info'] as String,
      value: json['value'] as String,
      photoPath: json['photo_path'] as String,
      dateTime: DateTime.parse(json['date_time'] as String),
    );
  }

  WaterMeasurement copyWith({
    String? id,
    String? meterId,
    String? apartmentInfo,
    String? value,
    String? photoPath,
    DateTime? dateTime,
  }) {
    return WaterMeasurement(
      id: id ?? this.id,
      meterId: meterId ?? this.meterId,
      apartmentInfo: apartmentInfo ?? this.apartmentInfo,
      value: value ?? this.value,
      photoPath: photoPath ?? this.photoPath,
      dateTime: dateTime ?? this.dateTime,
    );
  }
}
