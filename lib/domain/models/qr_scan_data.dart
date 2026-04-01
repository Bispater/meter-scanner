class QrScanData {
  final String meterId;
  final String apartmentInfo;
  final int? apartmentId;

  QrScanData({
    required this.meterId,
    required this.apartmentInfo,
    this.apartmentId,
  });

  factory QrScanData.fromJson(Map<String, dynamic> json) {
    return QrScanData(
      meterId: json['meter_id'] as String? ?? '',
      apartmentInfo: json['apartment_info'] as String? ?? '',
      apartmentId: json['apartment_id'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'meter_id': meterId,
      'apartment_info': apartmentInfo,
      if (apartmentId != null) 'apartment_id': apartmentId,
    };
  }
}
