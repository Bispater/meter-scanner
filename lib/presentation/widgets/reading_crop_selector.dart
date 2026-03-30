import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// A widget that displays a captured photo with a draggable rectangle overlay.
/// The user positions the rectangle over the roller/odometer display, then
/// the normalised crop coordinates can be read via [cropRect].
class ReadingCropSelector extends StatefulWidget {
  final String imagePath;

  /// Called whenever the crop rectangle changes (normalised 0..1 values).
  final ValueChanged<Rect>? onCropChanged;

  /// Called when drag starts (true) or ends (false).
  /// Parent should disable scrolling while true.
  final ValueChanged<bool>? onDragStateChanged;

  const ReadingCropSelector({
    super.key,
    required this.imagePath,
    this.onCropChanged,
    this.onDragStateChanged,
  });

  @override
  State<ReadingCropSelector> createState() => ReadingCropSelectorState();
}

class ReadingCropSelectorState extends State<ReadingCropSelector> {
  // Normalised crop rect (0..1) — default targets upper-centre of meter.
  double _nLeft = 0.18;
  double _nTop = 0.25;
  double _nWidth = 0.64;
  double _nHeight = 0.18;

  /// Current normalised crop rectangle.
  Rect get cropRect => Rect.fromLTWH(_nLeft, _nTop, _nWidth, _nHeight);

  // Layout / image mapping
  Rect _imageRect = Rect.zero; // where the image is drawn (BoxFit.contain)
  ui.Image? _uiImage;
  bool _imageLoaded = false;

  // Drag state
  _DragMode _dragMode = _DragMode.none;
  Offset _dragStartLocal = Offset.zero;
  Rect _dragStartCrop = Rect.zero;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _uiImage = frame.image;
          _imageLoaded = true;
        });
      }
    } catch (_) {
      // If image can't be loaded, widget will show the File image fallback
      if (mounted) setState(() => _imageLoaded = true);
    }
  }

  void _computeImageRect(Size widgetSize) {
    final image = _uiImage;
    if (image == null) {
      _imageRect = Offset.zero & widgetSize;
      return;
    }
    final imgAspect = image.width / image.height;
    final boxAspect = widgetSize.width / widgetSize.height;
    double drawW, drawH;
    if (imgAspect > boxAspect) {
      drawW = widgetSize.width;
      drawH = widgetSize.width / imgAspect;
    } else {
      drawH = widgetSize.height;
      drawW = widgetSize.height * imgAspect;
    }
    final dx = (widgetSize.width - drawW) / 2;
    final dy = (widgetSize.height - drawH) / 2;
    _imageRect = Rect.fromLTWH(dx, dy, drawW, drawH);
  }

  // --- coordinate conversions ---
  Rect _normToPixel() {
    return Rect.fromLTWH(
      _imageRect.left + _nLeft * _imageRect.width,
      _imageRect.top + _nTop * _imageRect.height,
      _nWidth * _imageRect.width,
      _nHeight * _imageRect.height,
    );
  }

  void _pixelToNorm(Rect px) {
    _nLeft = ((px.left - _imageRect.left) / _imageRect.width).clamp(0.0, 1.0);
    _nTop = ((px.top - _imageRect.top) / _imageRect.height).clamp(0.0, 1.0);
    _nWidth = (px.width / _imageRect.width).clamp(0.05, 1.0 - _nLeft);
    _nHeight = (px.height / _imageRect.height).clamp(0.05, 1.0 - _nTop);
  }

  // --- drag handling ---
  static const double _handleSize = 36.0;

  _DragMode _hitTest(Offset local) {
    final r = _normToPixel();
    final hs = _handleSize;

    // Corner handles
    if ((local - r.topLeft).distance < hs) return _DragMode.topLeft;
    if ((local - r.topRight).distance < hs) return _DragMode.topRight;
    if ((local - r.bottomLeft).distance < hs) return _DragMode.bottomLeft;
    if ((local - r.bottomRight).distance < hs) return _DragMode.bottomRight;

    // Inside → move
    if (r.inflate(4).contains(local)) return _DragMode.move;

    return _DragMode.none;
  }

  void _onPanStart(DragStartDetails d) {
    _dragMode = _hitTest(d.localPosition);
    _dragStartLocal = d.localPosition;
    _dragStartCrop = _normToPixel();
    if (_dragMode != _DragMode.none) {
      widget.onDragStateChanged?.call(true);
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_dragMode == _DragMode.none) return;
    final delta = d.localPosition - _dragStartLocal;
    final r = _dragStartCrop;

    Rect newPx;
    switch (_dragMode) {
      case _DragMode.move:
        newPx = r.shift(delta);
        // Clamp to image bounds
        double dx = 0, dy = 0;
        if (newPx.left < _imageRect.left) dx = _imageRect.left - newPx.left;
        if (newPx.right > _imageRect.right) dx = _imageRect.right - newPx.right;
        if (newPx.top < _imageRect.top) dy = _imageRect.top - newPx.top;
        if (newPx.bottom > _imageRect.bottom) dy = _imageRect.bottom - newPx.bottom;
        newPx = newPx.shift(Offset(dx, dy));
        break;
      case _DragMode.topLeft:
        newPx = Rect.fromLTRB(
          (r.left + delta.dx).clamp(_imageRect.left, r.right - 30),
          (r.top + delta.dy).clamp(_imageRect.top, r.bottom - 30),
          r.right,
          r.bottom,
        );
        break;
      case _DragMode.topRight:
        newPx = Rect.fromLTRB(
          r.left,
          (r.top + delta.dy).clamp(_imageRect.top, r.bottom - 30),
          (r.right + delta.dx).clamp(r.left + 30, _imageRect.right),
          r.bottom,
        );
        break;
      case _DragMode.bottomLeft:
        newPx = Rect.fromLTRB(
          (r.left + delta.dx).clamp(_imageRect.left, r.right - 30),
          r.top,
          r.right,
          (r.bottom + delta.dy).clamp(r.top + 30, _imageRect.bottom),
        );
        break;
      case _DragMode.bottomRight:
        newPx = Rect.fromLTRB(
          r.left,
          r.top,
          (r.right + delta.dx).clamp(r.left + 30, _imageRect.right),
          (r.bottom + delta.dy).clamp(r.top + 30, _imageRect.bottom),
        );
        break;
      case _DragMode.none:
        return;
    }

    setState(() {
      _pixelToNorm(newPx);
    });
    widget.onCropChanged?.call(cropRect);
  }

  void _onPanEnd(DragEndDetails d) {
    _dragMode = _DragMode.none;
    widget.onDragStateChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _computeImageRect(size);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: Stack(
            children: [
              // Image
              Positioned.fill(
                child: Image.file(
                  File(widget.imagePath),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image, size: 48, color: Colors.white38),
                  ),
                ),
              ),
              // Overlay + crop rectangle
              if (_imageLoaded)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CropOverlayPainter(
                      imageRect: _imageRect,
                      cropRect: _normToPixel(),
                      handleSize: _handleSize,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

enum _DragMode { none, move, topLeft, topRight, bottomLeft, bottomRight }

class _CropOverlayPainter extends CustomPainter {
  final Rect imageRect;
  final Rect cropRect;
  final double handleSize;

  _CropOverlayPainter({
    required this.imageRect,
    required this.cropRect,
    required this.handleSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Dark overlay outside the crop rectangle
    final overlayPaint = Paint()..color = const Color(0x99000000);
    final outerPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(cropRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(outerPath, overlayPaint);

    // Bright border
    final borderPaint = Paint()
      ..color = const Color(0xFF00BCD4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRect(cropRect, borderPaint);

    // Corner handles
    _drawHandle(canvas, cropRect.topLeft);
    _drawHandle(canvas, cropRect.topRight);
    _drawHandle(canvas, cropRect.bottomLeft);
    _drawHandle(canvas, cropRect.bottomRight);

    // Dashed grid lines (thirds) inside rect for alignment help
    final gridPaint = Paint()
      ..color = const Color(0x5500BCD4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final thirdW = cropRect.width / 3;
    final thirdH = cropRect.height / 3;
    for (int i = 1; i <= 2; i++) {
      // Vertical
      final x = cropRect.left + thirdW * i;
      canvas.drawLine(Offset(x, cropRect.top), Offset(x, cropRect.bottom), gridPaint);
      // Horizontal
      final y = cropRect.top + thirdH * i;
      canvas.drawLine(Offset(cropRect.left, y), Offset(cropRect.right, y), gridPaint);
    }
  }

  void _drawHandle(Canvas canvas, Offset center) {
    final fillPaint = Paint()..color = const Color(0xFF00BCD4);
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, 8, fillPaint);
    canvas.drawCircle(center, 8, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter old) =>
      old.cropRect != cropRect || old.imageRect != imageRect;
}
