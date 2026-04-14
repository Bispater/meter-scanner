import 'package:flutter_test/flutter_test.dart';
import 'package:metscan_app/domain/models/water_measurement.dart';
import 'package:metscan_app/domain/models/qr_scan_data.dart';

void main() {
  group('WaterMeasurement', () {
    test('toJson and fromJson round-trip', () {
      final measurement = WaterMeasurement(
        id: 'test-id',
        meterId: 'MED-001',
        apartmentInfo: '4B - Piso 2',
        value: '00546',
        photoPath: '/path/to/photo.jpg',
        dateTime: DateTime(2025, 3, 26, 14, 30),
      );

      final json = measurement.toJson();
      final restored = WaterMeasurement.fromJson(json);

      expect(restored.id, measurement.id);
      expect(restored.meterId, measurement.meterId);
      expect(restored.apartmentInfo, measurement.apartmentInfo);
      expect(restored.value, measurement.value);
      expect(restored.photoPath, measurement.photoPath);
      expect(restored.dateTime, measurement.dateTime);
    });

    test('copyWith creates modified copy', () {
      final original = WaterMeasurement(
        id: 'test-id',
        meterId: 'MED-001',
        apartmentInfo: '4B',
        value: '00100',
        photoPath: '/path.jpg',
        dateTime: DateTime(2025, 1, 1),
      );

      final modified = original.copyWith(value: '00200');
      expect(modified.value, '00200');
      expect(modified.meterId, original.meterId);
    });
  });

  group('QrScanData', () {
    test('fromJson parses correctly', () {
      final json = {'meter_id': 'MED-002', 'apartment_info': '5A - Piso 3'};
      final data = QrScanData.fromJson(json);

      expect(data.meterId, 'MED-002');
      expect(data.apartmentInfo, '5A - Piso 3');
    });

    test('fromJson handles missing fields', () {
      final json = <String, dynamic>{};
      final data = QrScanData.fromJson(json);

      expect(data.meterId, '');
      expect(data.apartmentInfo, '');
    });
  });
}
