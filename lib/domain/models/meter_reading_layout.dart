/// Tipo de cara del medidor (API: reading_layout): A = 5+4, B = 8 rodillos + 1 esfera (9 dígitos).
typedef MeterReadingLayout = String;

const String meterLayoutA = 'A';
const String meterLayoutB = 'B';

String normalizeMeterReadingLayout(String? value) {
  final t = (value ?? meterLayoutA).trim().toUpperCase();
  return t == meterLayoutB ? meterLayoutB : meterLayoutA;
}
