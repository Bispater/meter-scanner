import 'models/meter_reading_layout.dart' show normalizeMeterReadingLayout;

/// Cantidad de dígitos enteros y decimales según el tipo de cara del medidor.
class MeterDigitLayout {
  final int integerDigits;
  final int fractionalDigits;

  const MeterDigitLayout({required this.integerDigits, required this.fractionalDigits});

  int get totalDigits => integerDigits + fractionalDigits;
}

MeterDigitLayout meterDigitLayoutFor(String layout) {
  // Tipo A y B: misma estructura lógica 5+4. A/B distingue solo la lectura física (OCR / UI de ayuda).
  normalizeMeterReadingLayout(layout);
  return const MeterDigitLayout(integerDigits: 5, fractionalDigits: 4);
}

/// Solo dígitos y X (duda); mayúsculas.
String sanitizeMeterDigits(String raw, {required int maxLen}) {
  final upper = raw.toUpperCase();
  final cleaned = upper.replaceAll(RegExp(r'[^0-9X]'), '');
  if (cleaned.length <= maxLen) return cleaned;
  return cleaned.substring(0, maxLen);
}

/// Formato visual con coma: tipo A y B → 5+4 (9 dígitos en total, misma posición de la coma lógica).
String formatMeterDigitsForDisplay(String digitsOnly, String layout) {
  final ml = meterDigitLayoutFor(layout);
  final d = sanitizeMeterDigits(digitsOnly, maxLen: ml.totalDigits);
  if (d.isEmpty) return '';
  final right = d.length >= ml.fractionalDigits
      ? d.substring(d.length - ml.fractionalDigits)
      : d.padLeft(ml.fractionalDigits, '0');
  final leftRaw = d.length > ml.fractionalDigits ? d.substring(0, d.length - ml.fractionalDigits) : '';
  final left = leftRaw.padLeft(ml.integerDigits, '0');
  return '$left,$right';
}

/// Valida que haya exactamente [total] caracteres (dígitos/X) o vacío.
bool isCompleteReading(String digitsOnly, String layout) {
  final ml = meterDigitLayoutFor(layout);
  final d = sanitizeMeterDigits(digitsOnly, maxLen: ml.totalDigits);
  return d.length == ml.totalDigits;
}
