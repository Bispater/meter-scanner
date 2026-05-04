/// Tipo de cara del medidor (API: `reading_layout`): A y B usan 9 dígitos con coma lógica 5+4; B se distingue por la lectura física (OCR), no por otro formulario numérico.
typedef MeterReadingLayout = String;

const String meterLayoutA = 'A';
const String meterLayoutB = 'B';

String normalizeMeterReadingLayout(String? value) {
  final t = (value ?? meterLayoutA).trim().toUpperCase();
  return t == meterLayoutB ? meterLayoutB : meterLayoutA;
}

/// Texto corto para chips y barras (p. ej. "Tipo B").
String meterTypeChipLabel(String layout) {
  final t = normalizeMeterReadingLayout(layout);
  return t == meterLayoutB ? 'Tipo B' : 'Tipo A';
}

/// Descripción breve para pantallas de detalle / ayuda.
String meterTypeDescription(String layout) {
  final t = normalizeMeterReadingLayout(layout);
  if (t == meterLayoutB) {
    return 'Tipo B — carril (5+3) + esfera; lectura lógica 5+4';
  }
  return 'Tipo A — 5 enteros + 4 esferas';
}
