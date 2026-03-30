import 'dart:math' as math;
import 'package:flutter/material.dart';

class MeterOverlayPainter extends CustomPainter {
  final Color overlayColor;
  final Color borderColor;
  final double borderWidth;
  final double cornerRadius;

  MeterOverlayPainter({
    this.overlayColor = const Color(0xAA000000),
    this.borderColor = const Color(0xFF00BCD4),
    this.borderWidth = 3.0,
    this.cornerRadius = 20.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Circular cutout for round water meters
    final double circleRadius = size.width * 0.38;

    // Draw dark overlay with circular hole
    final overlayPaint = Paint()..color = overlayColor;
    final holePath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(center: center, radius: circleRadius))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(holePath, overlayPaint);

    // Draw cyan border around the circle
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawCircle(center, circleRadius, borderPaint);

    // Draw corner brackets for visual guidance
    _drawCornerBrackets(canvas, center, circleRadius, borderPaint);

    // Draw crosshair lines
    final crosshairPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Horizontal line
    canvas.drawLine(
      Offset(center.dx - circleRadius * 0.3, center.dy),
      Offset(center.dx + circleRadius * 0.3, center.dy),
      crosshairPaint,
    );
    // Vertical line
    canvas.drawLine(
      Offset(center.dx, center.dy - circleRadius * 0.3),
      Offset(center.dx, center.dy + circleRadius * 0.3),
      crosshairPaint,
    );

    // Draw instruction text area
    _drawInstructionBackground(canvas, size, center, circleRadius);
  }

  void _drawCornerBrackets(
      Canvas canvas, Offset center, double radius, Paint paint) {
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

      // Draw small tick marks at cardinal points
      final x2 = center.dx + (outerRadius + bracketLength) * math.cos(rad);
      final y2 = center.dy + (outerRadius + bracketLength) * math.sin(rad);

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), bracketPaint);
    }
  }

  void _drawInstructionBackground(
      Canvas canvas, Size size, Offset center, double radius) {
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
