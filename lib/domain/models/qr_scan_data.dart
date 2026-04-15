import 'meter_reading_layout.dart';

class QrScanData {
  final String qrCode;
  final String meterId;
  final String apartmentInfo;
  final int? apartmentId;
  /// Desde JSON `meter_type`: "A" o "B" (disposición de 9 dígitos).
  final String meterType;

  QrScanData({
    required this.qrCode,
    this.meterId = '',
    required this.apartmentInfo,
    this.apartmentId,
    this.meterType = meterLayoutA,
  });

  factory QrScanData.fromJson(Map<String, dynamic> json) {
    final qrCode = json['qr_code'] as String?;
    final meterId = json['meter_id'] as String? ?? '';
    final rawType = json['meter_type'] as String?;
    return QrScanData(
      qrCode: qrCode?.isNotEmpty == true ? qrCode! : meterId,
      meterId: meterId,
      apartmentInfo: json['apartment_info'] as String? ?? '',
      apartmentId: json['apartment_id'] as int?,
      meterType: normalizeMeterReadingLayout(rawType),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'qr_code': qrCode,
      if (meterId.isNotEmpty) 'meter_id': meterId,
      'apartment_info': apartmentInfo,
      if (apartmentId != null) 'apartment_id': apartmentId,
      'meter_type': meterType,
    };
  }
}
