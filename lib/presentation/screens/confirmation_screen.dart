import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/meter_reading_layout.dart';
import '../../domain/models/water_measurement.dart';
import '../providers/app_providers.dart';
import 'home_screen.dart';

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
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _wholePartController = TextEditingController();
  final TextEditingController _decimalPartController = TextEditingController();
  bool _isLoadingOcr = true;
  bool _isSubmitting = false;
  String? _ocrError;
  String? _croppedPath;
  String _originalOcrValue = '';

  @override
  void initState() {
    super.initState();
    _runOcr();
  }

  @override
  void dispose() {
    _valueController.dispose();
    _wholePartController.dispose();
    _decimalPartController.dispose();
    // Clean up temp cropped image
    if (_croppedPath != null) {
      try { File(_croppedPath!).delete(); } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _runOcr() async {
    setState(() {
      _isLoadingOcr = true;
      _ocrError = null;
    });

    try {
      final ocrService = ref.read(ocrServiceProvider);

      // 1. Crop to circle zone (for display and analysis)
      if (_croppedPath == null) {
        final cropped = await ocrService.cropToCircleZone(widget.photoPath);
        if (mounted && cropped != null) {
          setState(() => _croppedPath = cropped);
        }
      }

      // 2. Analyze the cropped image (or full image as fallback)
      final pathToAnalyze = _croppedPath ?? widget.photoPath;
      final result = await ocrService.analyzeImage(
        pathToAnalyze,
        meterReadingType: widget.meterReadingLayout == meterLayoutB ? 'B' : 'A',
      );
      if (mounted) {
        final normalized = _normalizeReading(result);
        setState(() {
          _originalOcrValue = normalized;
          _setReadingFromRaw(normalized);
          _isLoadingOcr = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _ocrError = e.toString();
          _isLoadingOcr = false;
        });
      }
    }
  }

  Future<void> _submitMeasurement() async {
    final value = _normalizeReading(_valueController.text.trim());
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingrese un valor de lectura'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (value.length != 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La lectura debe tener 9 dígitos (5 enteros + 4 decimales/esferas).'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final wasModified = value != _originalOcrValue;
      final measurement = WaterMeasurement(
        meterId: widget.meterId,
        apartmentInfo: widget.apartmentInfo,
        apartmentId: widget.apartmentId,
        value: value,
        ocrValue: _originalOcrValue,
        modifiedByUser: wasModified,
        photoPath: widget.photoPath,
        dateTime: DateTime.now(),
      );

      final repository = ref.read(measurementRepositoryProvider);
      await repository.submitMeasurement(measurement);

      if (!mounted) return;
      _showSuccessDialog();
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
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _normalizeReading(String raw) {
    final upper = raw.toUpperCase();
    final cleaned = upper.replaceAll(RegExp(r'[^0-9X]'), '');
    return cleaned.length > 9 ? cleaned.substring(0, 9) : cleaned;
  }

  String _formatMeterReading(String raw) {
    final normalized = _normalizeReading(raw);
    if (normalized.isEmpty) return raw;
    final right = normalized.length >= 4
        ? normalized.substring(normalized.length - 4)
        : normalized.padLeft(4, '0');
    final leftRaw = normalized.length > 4
        ? normalized.substring(0, normalized.length - 4)
        : '';
    final left = leftRaw.padLeft(5, '0');
    return '$left,$right';
  }

  void _setReadingFromRaw(String raw) {
    final normalized = _normalizeReading(raw);
    _valueController.text = normalized;
    final whole = normalized.length <= 5 ? normalized : normalized.substring(0, 5);
    final decimal = normalized.length <= 5 ? '' : normalized.substring(5);
    _wholePartController.text = whole;
    _decimalPartController.text = decimal;
  }

  void _onWholeChanged(String value) {
    final sanitized = _normalizeReading(value);
    if (sanitized != value) {
      _wholePartController.value = TextEditingValue(
        text: sanitized,
        selection: TextSelection.collapsed(offset: sanitized.length),
      );
    }
    final combined = _normalizeReading('${_wholePartController.text}${_decimalPartController.text}');
    _setReadingFromRaw(combined);
  }

  void _onDecimalChanged(String value) {
    final sanitized = _normalizeReading(value);
    if (sanitized != value) {
      _decimalPartController.value = TextEditingValue(
        text: sanitized,
        selection: TextSelection.collapsed(offset: sanitized.length),
      );
    }
    final combined = _normalizeReading('${_wholePartController.text}${_decimalPartController.text}');
    _setReadingFromRaw(combined);
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.check_circle_rounded,
          color: Colors.green,
          size: 64,
        ),
        title: const Text('¡Medición Enviada!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Medidor: ${widget.meterId}',
              style: const TextStyle(color: Colors.white70),
            ),
            Text(
              'Valor: ${_formatMeterReading(_valueController.text)} m³',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Go back to home
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              );
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirmar Lectura'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Photo preview
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 280,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: Image.file(
                    File(_croppedPath ?? widget.photoPath),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image, size: 48, color: Colors.white38),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Action buttons row
              Row(
                children: [
                  // Re-analyze button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoadingOcr ? null : _runOcr,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Re-analizar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.secondary,
                        side: BorderSide(color: theme.colorScheme.secondary.withValues(alpha: 0.5)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Retake button
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.replay_rounded, size: 18),
                    label: const Text('Recapturar'),
                    style: TextButton.styleFrom(foregroundColor: Colors.white54),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // OCR Result section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_fix_high_rounded,
                              color: theme.colorScheme.secondary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Lectura Detectada (Gemini AI)',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (_isLoadingOcr)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 12),
                                Text(
                                  'Analizando imagen con IA...',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        if (_ocrError != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _ocrError!,
                              style: const TextStyle(
                                  color: Colors.orange, fontSize: 12),
                            ),
                          ),

                        // Editable value field
                        TextField(
                          controller: _valueController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 4,
                          ),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            labelText: 'Valor del Medidor (m³)',
                            suffixText: 'm³',
                            suffixStyle: TextStyle(
                              color: theme.colorScheme.secondary,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                            helperText:
                                'Formato esperado: 9 dígitos (5 enteros + 4 decimales/esferas)',
                            helperStyle:
                                const TextStyle(color: Colors.white38),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Formato medidor: ${_formatMeterReading(_valueController.text)}',
                            style: TextStyle(
                              color: theme.colorScheme.secondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _wholePartController,
                                onChanged: _onWholeChanged,
                                maxLength: 5,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'[0-9Xx]')),
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Enteros (5)',
                                  counterText: '',
                                ),
                                style: const TextStyle(
                                  fontSize: 24,
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
                                onChanged: _onDecimalChanged,
                                maxLength: 4,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'[0-9Xx]')),
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Esferas/decimales (4)',
                                  counterText: '',
                                ),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                  color: theme.colorScheme.secondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Meter info summary
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 20, color: Colors.white38),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Medidor: ${widget.meterId}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                            Text(
                              'Depto: ${widget.apartmentInfo}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Submit button
              ElevatedButton.icon(
                onPressed: _isSubmitting || _isLoadingOcr
                    ? null
                    : _submitMeasurement,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black54,
                        ),
                      )
                    : const Icon(Icons.cloud_upload_rounded, size: 24),
                label: Text(_isSubmitting ? 'Enviando...' : 'Enviar Medición'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
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
