import '../models/water_measurement.dart';

abstract class MeasurementRepository {
  Future<bool> submitMeasurement(WaterMeasurement measurement);
  Future<List<WaterMeasurement>> getRecentMeasurements();
}
