import 'meter_reading_input.dart';
import 'models/meter_reading_layout.dart';

/// Convierte los dígitos de la app (5+4, tipos A y B) al valor en m³ que espera el API (decimal con punto).
String readingDigitsToApiM3String(String rawDigits, String readingLayout) {
  final layout = normalizeMeterReadingLayout(readingLayout);
  final ml = meterDigitLayoutFor(layout);
  final d = sanitizeMeterDigits(rawDigits, maxLen: ml.totalDigits);
  if (d.isEmpty) return '';

  final intPart = d.length > ml.fractionalDigits
      ? d.substring(0, d.length - ml.fractionalDigits)
      : '0';
  final frac = d.length >= ml.fractionalDigits
      ? d.substring(d.length - ml.fractionalDigits)
      : d.padLeft(ml.fractionalDigits, '0');

  if (frac.isEmpty) return intPart;
  return '$intPart.$frac';
}

/// Normaliza lo que vuelve del backend: puede ser "546.682" o "5466821" mal grabado
/// sin separador. Devuelve siempre [rawDigits] listos para [formatMeterDigitsForDisplay].
String normalizeApiReadingToDisplayDigits(String raw, String? readingLayout) {
  final layout = normalizeMeterReadingLayout(readingLayout);
  final ml = meterDigitLayoutFor(layout);
  final t = raw.trim();
  if (t.isEmpty) return '';

  if (t.contains('.')) {
    final parts = t.split('.');
    if (parts.length == 2) {
      var intPart = parts[0].replaceAll(RegExp(r'[^0-9Xx]'), '');
      var frac = parts[1].replaceAll(RegExp(r'[^0-9Xx]'), '');
      // Valores como "5466821.000" vienen del backend como decimal pero en realidad
      // son lectura en dígitos sin separar: tratar como entero (sin parte decimal).
      final fracNoZero = frac.replaceAll('0', '').replaceAll('X', '').replaceAll('x', '');
      if (fracNoZero.isEmpty) {
        intPart = '$intPart$frac';
        frac = '';
      }
      if (frac.isEmpty) {
        // Caída al armado por dígitos completos más abajo
        return _digitsOnlyPadToLayout(intPart, layout);
      }
      if (intPart.isEmpty) intPart = '0';
      if (ml.fractionalDigits > 0) {
        if (frac.length > ml.fractionalDigits) {
          frac = frac.substring(0, ml.fractionalDigits);
        } else {
          frac = frac.padRight(ml.fractionalDigits, '0');
        }
      } else {
        frac = '';
      }
      if (intPart.length < ml.integerDigits) {
        intPart = intPart.padLeft(ml.integerDigits, '0');
      }
      return intPart + frac;
    }
  }

  var digits = t.replaceAll(RegExp(r'[^0-9Xx]'), '').toUpperCase();
  if (digits.isEmpty) return '';

  return _digitsOnlyPadToLayout(digits, layout);
}

String _digitsOnlyPadToLayout(String digits, String readingLayout) {
  final ml = meterDigitLayoutFor(readingLayout);
  var d = digits.replaceAll(RegExp(r'[^0-9Xx]'), '').toUpperCase();
  if (d.isEmpty) return '';
  if (d.length < ml.totalDigits) {
    d = d.padLeft(ml.totalDigits, '0');
  } else if (d.length > ml.totalDigits) {
    d = d.substring(d.length - ml.totalDigits);
  }
  return d;
}

/// Formato visible tipo panel: 5 enteros (con ceros) + coma + 4 decimales (cara A).
String formatCubicMetersTypeA5Plus4(String nineDigits) {
  final d = sanitizeMeterDigits(nineDigits, maxLen: 9);
  if (d.length < 9) {
    return formatMeterDigitsForDisplay(d, meterLayoutA);
  }
  final intPart = d.substring(0, 5);
  final frac = d.substring(5, 9);
  return '$intPart,$frac';
}
