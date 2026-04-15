/// Tipo de cara del medidor para lectura de 9 dígitos (API: [reading_layout] / QR: meter_type).
typedef MeterReadingLayout = String;

const String meterLayoutA = 'A';
const String meterLayoutB = 'B';

String normalizeMeterReadingLayout(String? value) {
  final t = (value ?? meterLayoutA).trim().toUpperCase();
  return t == meterLayoutB ? meterLayoutB : meterLayoutA;
}
