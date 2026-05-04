import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Overlay oscuro con agujero circular + [guía vectorial] para encuadrar.
/// Relleno: solo bordes y líneas; no hay bitmap ni áreas sólidas sobre el cristal.
class MeterOverlayPainter extends CustomPainter {
  /// Tipo A: 5+4; Tipo B: franja de carriles más alargada + círculo de esfera.
  final bool isTypeB;

  final Color overlayColor;
  final Color borderColor;
  final double borderWidth;
  final double cornerRadius;

  MeterOverlayPainter({
    this.isTypeB = false,
    this.overlayColor = const Color(0xAA000000),
    this.borderColor = const Color(0xFF00BCD4),
    this.borderWidth = 3.0,
    this.cornerRadius = 20.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final double circleRadius = size.width * 0.38;

    final overlayPaint = Paint()..color = overlayColor;
    final holePath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(center: center, radius: circleRadius))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(holePath, overlayPaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawCircle(center, circleRadius, borderPaint);

    _drawCornerBrackets(canvas, center, circleRadius, borderPaint);

    // Recuadro de la zona de lectura (solo trazo, sin relleno que tape el preview)
    final readingRect = _readingRectForLayout(center, circleRadius, isTypeB);
    final readingRectRR = RRect.fromRectAndRadius(
      readingRect,
      Radius.circular(isTypeB ? 4 : 6),
    );

    final readingBorderPaint = Paint()
      ..color = const Color(0xE600BCD4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(readingRectRR, readingBorderPaint);

    // Guías finas: 8 líneas = 9 columnas (5 enteros + 4 decimales, misma lógica A y B)
    _drawColumnGuides(
      canvas,
      readingRect,
      borderColor: const Color(0x99FFFFFF),
    );

    _drawRectCornerEmphasis(canvas, readingRect, borderColor);

    if (isTypeB) {
      _drawTypeBDialHint(canvas, center, circleRadius, const Color(0xE600BCD4));
    }

    _drawInstructionBackground(canvas, size, center, circleRadius);
  }

  /// Franja A: proporción clásica; Tipo B: más ancha y un poco más baja (carril).
  static Rect _readingRectForLayout(Offset center, double circleRadius, bool typeB) {
    final w = typeB ? circleRadius * 1.22 : circleRadius * 1.10;
    final h = typeB ? circleRadius * 0.24 : circleRadius * 0.28;
    final verticalShift = typeB ? -0.24 : -0.28;
    return Rect.fromCenter(
      center: Offset(
        center.dx + circleRadius * 0.05,
        center.dy - circleRadius * verticalShift,
      ),
      width: w,
      height: h,
    );
  }

  void _drawColumnGuides(
    Canvas canvas,
    Rect rect, {
    required Color borderColor,
    int columns = 9,
  }) {
    final p = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.butt;
    for (var i = 1; i < columns; i++) {
      final x = rect.left + rect.width * (i / columns);
      canvas.drawLine(Offset(x, rect.top + 1), Offset(x, rect.bottom - 1), p);
    }
  }

  void _drawRectCornerEmphasis(Canvas canvas, Rect readingRect, Color borderColor) {
    final cornerPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    const cLen = 10.0;
    final rl = readingRect.left;
    final rr = readingRect.right;
    final rt = readingRect.top;
    final rb = readingRect.bottom;
    canvas.drawLine(Offset(rl, rt + cLen), Offset(rl, rt), cornerPaint);
    canvas.drawLine(Offset(rl, rt), Offset(rl + cLen, rt), cornerPaint);
    canvas.drawLine(Offset(rr - cLen, rt), Offset(rr, rt), cornerPaint);
    canvas.drawLine(Offset(rr, rt), Offset(rr, rt + cLen), cornerPaint);
    canvas.drawLine(Offset(rl, rb - cLen), Offset(rl, rb), cornerPaint);
    canvas.drawLine(Offset(rl, rb), Offset(rl + cLen, rb), cornerPaint);
    canvas.drawLine(Offset(rr - cLen, rb), Offset(rr, rb), cornerPaint);
    canvas.drawLine(Offset(rr, rb), Offset(rr, rb - cLen), cornerPaint);
  }

  /// Círculo (esfera) abajo a la derecha — solo trazo, sin relleno.
  void _drawTypeBDialHint(Canvas canvas, Offset center, double circleRadius, Color color) {
    final dialCenter = Offset(
      center.dx + circleRadius * 0.34,
      center.dy + circleRadius * 0.32,
    );
    final r = circleRadius * 0.14;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(dialCenter, r, p);
    p.strokeWidth = 1.2;
    p.color = const Color(0x99FFFFFF);
    final c = dialCenter;
    canvas.drawLine(Offset(c.dx - 3, c.dy), Offset(c.dx + 3, c.dy), p);
    canvas.drawLine(Offset(c.dx, c.dy - 3), Offset(c.dx, c.dy + 3), p);
  }

  void _drawCornerBrackets(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
  ) {
    final bracketPaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    const bracketLength = 20.0;
    final positions = [0.0, 90.0, 180.0, 270.0];

    for (final angle in positions) {
      final rad = angle * math.pi / 180;
      final outerRadius = radius + 12;

      final x1 = center.dx + outerRadius * math.cos(rad);
      final y1 = center.dy + outerRadius * math.sin(rad);

      final x2 = center.dx + (outerRadius + bracketLength) * math.cos(rad);
      final y2 = center.dy + (outerRadius + bracketLength) * math.sin(rad);

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), bracketPaint);
    }
  }

  void _drawInstructionBackground(
    Canvas canvas,
    Size size,
    Offset center,
    double radius,
  ) {
    final textBgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + radius + 60),
        width: size.width * 0.8,
        height: 44,
      ),
      const Radius.circular(22),
    );
    final textBgPaint = Paint()..color = const Color(0x66000000);
    canvas.drawRRect(textBgRect, textBgPaint);
  }

  @override
  bool shouldRepaint(covariant MeterOverlayPainter oldDelegate) =>
      oldDelegate.isTypeB != isTypeB ||
      oldDelegate.borderColor != borderColor;
}
