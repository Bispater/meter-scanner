import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/meter_reading_input.dart';
import '../../domain/models/meter_reading_layout.dart'
    show meterLayoutA, meterLayoutB, meterTypeChipLabel, meterTypeDescription;
import '../../domain/models/water_measurement.dart';
import '../providers/app_providers.dart';
import 'home_screen.dart' show recentMeasurementsProvider;
import 'meter_photo_viewer_screen.dart';

class ConfirmationScreen extends ConsumerStatefulWidget {
  final String meterId;
  final String apartmentInfo;
  final int? apartmentId;
  final String photoPath;
  final String meterReadingLayout;

  const ConfirmationScreen({
    super.key,
    required this.meterId,
    required this.apartmentInfo,
    this.apartmentId,
    required this.photoPath,
    this.meterReadingLayout = meterLayoutA,
  });

  @override
  ConsumerState<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends ConsumerState<ConfirmationScreen> {
  final TextEditingController _wholePartController = TextEditingController();
  final TextEditingController _decimalPartController = TextEditingController();
  final FocusNode _wholeFocus = FocusNode();
  final FocusNode _decimalFocus = FocusNode();
  bool _isSubmitting = false;
  String? _croppedPath;
  bool _cropping = true;

  bool get _isLayoutB => widget.meterReadingLayout == meterLayoutB;

  MeterDigitLayout get _layout => meterDigitLayoutFor(widget.meterReadingLayout);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareCrop());
  }

  Future<void> _prepareCrop() async {
    try {
      final ocrService = ref.read(ocrServiceProvider);
      final cropped = await ocrService.cropToCircleZone(widget.photoPath);
      if (mounted) {
        setState(() {
          _croppedPath = cropped;
          _cropping = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cropping = false);
    }
  }

  @override
  void dispose() {
    _wholePartController.dispose();
    _decimalPartController.dispose();
    _wholeFocus.dispose();
    _decimalFocus.dispose();
    if (_croppedPath != null) {
      try {
        File(_croppedPath!).delete();
      } catch (_) {}
    }
    super.dispose();
  }

  String _combinedDigits() {
    final w = sanitizeMeterDigits(_wholePartController.text, maxLen: _layout.integerDigits);
    final d = sanitizeMeterDigits(_decimalPartController.text, maxLen: _layout.fractionalDigits);
    return '$w$d';
  }

  void _onWholeChanged(String value) {
    final maxL = _layout.integerDigits;
    final sanitized = sanitizeMeterDigits(value, maxLen: maxL);
    if (sanitized != value) {
      _wholePartController.value = TextEditingValue(
        text: sanitized,
        selection: TextSelection.collapsed(offset: sanitized.length),
      );
    }
    if (sanitized.length >= maxL && _wholeFocus.hasFocus) {
      FocusScope.of(context).requestFocus(_decimalFocus);
    }
    setState(() {});
  }

  void _onDecimalChanged(String value) {
    final maxL = _layout.fractionalDigits;
    final sanitized = sanitizeMeterDigits(value, maxLen: maxL);
    if (sanitized != value) {
      _decimalPartController.value = TextEditingValue(
        text: sanitized,
        selection: TextSelection.collapsed(offset: sanitized.length),
      );
    }
    if (sanitized.length >= maxL && _decimalFocus.hasFocus) {
      _decimalFocus.unfocus();
    }
    setState(() {});
  }

  Future<void> _submitMeasurement() async {
    final combined = _combinedDigits();
    final complete = isCompleteReading(combined, widget.meterReadingLayout);

    if (!complete) {
      final need = _layout.totalDigits;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isLayoutB
                ? 'Lectura obligatoria: complete los $need dígitos (5 enteros + 4 decimales: 5 negros + 3 rojos en barra + 1 esfera).'
                : 'Lectura obligatoria: complete los $need dígitos (5 enteros + 4 esferas).',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
      if (_wholePartController.text.length < _layout.integerDigits) {
        FocusScope.of(context).requestFocus(_wholeFocus);
      } else {
        FocusScope.of(context).requestFocus(_decimalFocus);
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final measurement = WaterMeasurement(
        meterId: widget.meterId,
        apartmentInfo: widget.apartmentInfo,
        apartmentId: widget.apartmentId,
        value: combined,
        ocrValue: '',
        modifiedByUser: true,
        photoPath: widget.photoPath,
        dateTime: DateTime.now(),
        readingLayout: widget.meterReadingLayout,
      );

      final repository = ref.read(measurementRepositoryProvider);
      await repository.submitMeasurement(measurement);

      if (!mounted) return;
      _showSuccessDialog(combined);
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _openPhotoViewer(String path) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => MeterPhotoViewerScreen(imagePath: path),
      ),
    );
  }

  void _showSuccessDialog(String manualDigits) {
    final formatted = '${formatMeterDigitsForDisplay(manualDigits, widget.meterReadingLayout)} m³';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 64),
        title: const Text('¡Medición enviada!'),
        actionsAlignment: MainAxisAlignment.center,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Medidor: ${widget.meterId}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 4),
            Text(
              meterTypeChipLabel(widget.meterReadingLayout),
              style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Valor enviado: $formatted',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              ref.invalidate(recentMeasurementsProvider);
              ref.read(authServiceProvider).refreshProfile();
              Navigator.of(ctx).pop();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Volver al Inicio'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previewPath = _croppedPath ?? widget.photoPath;
    final combined = _combinedDigits();
    final displayLine = formatMeterDigitsForDisplay(combined, widget.meterReadingLayout);
    final isComplete = isCompleteReading(combined, widget.meterReadingLayout);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Confirmar Lectura'),
            const SizedBox(height: 2),
            Text(
              meterTypeDescription(widget.meterReadingLayout),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.secondary.withValues(alpha: 0.95),
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Recapturar foto',
            icon: const Icon(Icons.replay_rounded),
            onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: () => _openPhotoViewer(previewPath),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.secondary.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_cropping)
                          const Center(child: CircularProgressIndicator())
                        else
                          Image.file(
                            File(previewPath),
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image, size: 48, color: Colors.white38),
                            ),
                          ),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.zoom_in, size: 18, color: theme.colorScheme.secondary),
                                const SizedBox(width: 6),
                                Text(
                                  'Toca para ampliar',
                                  style: TextStyle(color: theme.colorScheme.secondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.edit_note_rounded, color: theme.colorScheme.secondary, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Lectura manual',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              'Obligatoria',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isLayoutB
                            ? 'Tipo B: 5 rodillos negros (enteros) + 3 rodillos rojos y 1 esfera (4 “decimales”). Vista final: 00000,0646.'
                            : 'Tipo A: 5 dígitos enteros y 4 esferas decimales.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 13, height: 1.35),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _wholePartController,
                              focusNode: _wholeFocus,
                              onChanged: _onWholeChanged,
                              keyboardType: TextInputType.text,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => FocusScope.of(context).requestFocus(_decimalFocus),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[0-9Xx]')),
                              ],
                              maxLength: _layout.integerDigits,
                              decoration: InputDecoration(
                                labelText: 'Enteros (${_layout.integerDigits})',
                                counterText: '',
                                isDense: true,
                              ),
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _decimalPartController,
                              focusNode: _decimalFocus,
                              onChanged: _onDecimalChanged,
                              keyboardType: TextInputType.text,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _decimalFocus.unfocus(),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[0-9Xx]')),
                              ],
                              maxLength: _layout.fractionalDigits,
                              decoration: InputDecoration(
                                labelText: 'Decimales (${_layout.fractionalDigits})',
                                counterText: '',
                                isDense: true,
                              ),
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                                color: theme.colorScheme.secondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      if (_isLayoutB) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Decimales: 3 rodillos rojos en barra + 1 esfera (si no se ve, use X en ese dígito).',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (displayLine.isNotEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Vista medidor: $displayLine',
                            style: TextStyle(
                              color: theme.colorScheme.secondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 20, color: Colors.white38),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Medidor: ${widget.meterId}',
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            Text(
                              'Depto: ${widget.apartmentInfo}',
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitMeasurement,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54),
                      )
                    : Icon(isComplete ? Icons.cloud_upload_rounded : Icons.lock_outline, size: 24),
                label: Text(
                  _isSubmitting
                      ? 'Enviando...'
                      : isComplete
                          ? 'Enviar medición'
                          : 'Complete la lectura para enviar',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  backgroundColor: isComplete ? null : Colors.white12,
                  foregroundColor: isComplete ? null : Colors.white54,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
