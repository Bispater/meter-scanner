import '../data/services/auth_service.dart';
import 'models/water_measurement.dart';

/// True if [captured] falls on a calendar day within [scheduledDate] and [deadline] (inclusive).
bool capturedInCycleWindow(
  DateTime captured,
  String scheduledDateStr,
  String deadlineStr,
) {
  try {
    final start = DateTime.parse(scheduledDateStr);
    final end = DateTime.parse(deadlineStr);
    final d = DateTime(captured.year, captured.month, captured.day);
    final ds = DateTime(start.year, start.month, start.day);
    final de = DateTime(end.year, end.month, end.day);
    return !d.isBefore(ds) && !d.isAfter(de);
  } catch (_) {
    return false;
  }
}

/// Whether [measurements] already has a reading for this apartment in any [cycles]
/// window that matches the apartment's building (same as backend window).
bool apartmentHasMeasurementInActiveCycleWindows({
  required int? apartmentId,
  required String meterId,
  required List<WaterMeasurement> measurements,
  required List<CycleInfo> cycles,
  required String buildingName,
}) {
  for (final c in cycles) {
    if (c.buildingName != buildingName) continue;
    for (final m in measurements) {
      final sameApt = apartmentId != null && m.apartmentId == apartmentId;
      final sameMeter = m.meterId == meterId;
      if (!sameApt && !sameMeter) continue;
      if (capturedInCycleWindow(m.dateTime, c.scheduledDate, c.deadline)) {
        return true;
      }
    }
  }
  return false;
}
