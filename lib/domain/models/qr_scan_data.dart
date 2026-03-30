class QrScanData {
  final String meterId;
  final String apartmentInfo;

  QrScanData({
    required this.meterId,
    required this.apartmentInfo,
  });

  factory QrScanData.fromJson(Map<String, dynamic> json) {
    return QrScanData(
      meterId: json['meter_id'] as String? ?? '',
      apartmentInfo: json['apartment_info'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'meter_id': meterId,
      'apartment_info': apartmentInfo,
    };
  }
}
