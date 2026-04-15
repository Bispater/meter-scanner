import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../domain/models/meter_reading_layout.dart';
import '../../domain/models/qr_scan_data.dart';
import '../providers/app_providers.dart';
import 'prepare_measurement_screen.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  bool _isProcessing = false;
  String? _lastRejectedValue;
  DateTime? _lastErrorTime;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
    _lastErrorTime = DateTime.now();
    // Keep _isProcessing true for 2 seconds to prevent rapid re-scans
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isProcessing = false);
    });
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    // Cooldown: skip if last error was less than 2 seconds ago
    if (_lastErrorTime != null &&
        DateTime.now().difference(_lastErrorTime!).inSeconds < 2) {
      return;
    }

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? rawValue = barcode.rawValue;
      if (rawValue == null) continue;

      // Skip if this is the same QR we just rejected
      if (rawValue == _lastRejectedValue) return;

      setState(() => _isProcessing = true);

      String qrCode = '';
      String apartmentInfo = '';
      int? apartmentId;
      String meterReadingLayout = meterLayoutA;
      var parsedJsonQr = false;

      try {
        // Try to parse as JSON: {"qr_code": "1409A", "apartment_info": "...", "apartment_id": 1}
        // Also supports legacy format with "meter_id" key
        final Map<String, dynamic> data = jsonDecode(rawValue);
        final qrData = QrScanData.fromJson(data);
        parsedJsonQr = true;
        qrCode = qrData.qrCode;
        apartmentInfo = qrData.apartmentInfo.isNotEmpty ? qrData.apartmentInfo : '';
        apartmentId = qrData.apartmentId;
        meterReadingLayout = qrData.meterType;
      } catch (_) {
        // Plain text: either "1409A" or legacy "meter_id|apartment_info"
        final parts = rawValue.split('|');
        if (parts.length >= 2) {
          qrCode = parts[0].trim();
          apartmentInfo = parts[1].trim();
        } else {
          qrCode = rawValue.trim();
        }
      }

      if (qrCode.isEmpty) {
        _lastRejectedValue = rawValue;
        _showError('QR no válido. No se pudo leer el código del departamento.');
        return;
      }

      // Validate against assigned apartments
      final authService = ref.read(authServiceProvider);
      if (!authService.canAccessByQrCode(qrCode)) {
        _lastRejectedValue = rawValue;
        _showError('Este departamento no está asignado a su cuenta.');
        return;
      }

      // Resolve apartment_id from assigned apartments if not in QR
      apartmentId ??= authService.getApartmentIdByQrCode(qrCode);

      // QR sin JSON: tomar tipo desde asignación en /me
      if (!parsedJsonQr) {
        meterReadingLayout = authService.getReadingLayoutForQrOrMeter(qrCode);
      }

      // Clear any error snackbars before navigating
      ScaffoldMessenger.of(context).clearSnackBars();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PrepareMeasurementScreen(
            meterId: qrCode,
            apartmentInfo: apartmentInfo,
            apartmentId: apartmentId,
            meterReadingLayout: meterReadingLayout,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear QR del Medidor'),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _scannerController,
              builder: (context, state, child) {
                return Icon(
                  state.torchState == TorchState.on
                      ? Icons.flash_on
                      : Icons.flash_off,
                  color: state.torchState == TorchState.on
                      ? Colors.amber
                      : Colors.white,
                );
              },
            ),
            onPressed: () => _scannerController.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),

          // Overlay with scan area indicator
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.secondary,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          // Bottom instruction
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Text(
                  'Apunte al código QR del medidor',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),

          // Loading indicator
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
