import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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

      String? meterId;
      String? apartmentInfo;
      int? apartmentId;

      try {
        // Try to parse as JSON: {"meter_id": "...", "apartment_info": "...", "apartment_id": 1}
        final Map<String, dynamic> data = jsonDecode(rawValue);
        final qrData = QrScanData.fromJson(data);
        meterId = qrData.meterId;
        apartmentInfo = qrData.apartmentInfo;
        apartmentId = qrData.apartmentId;
      } catch (_) {
        // If not JSON, try to parse as simple text "meter_id|apartment_info"
        final parts = rawValue.split('|');
        if (parts.length >= 2) {
          meterId = parts[0].trim();
          apartmentInfo = parts[1].trim();
        }
      }

      if (meterId == null || meterId.isEmpty) {
        _lastRejectedValue = rawValue;
        _showError('QR no válido. Debe contener meter_id y apartment_info.');
        return;
      }

      // Validate against assigned apartments
      final authService = ref.read(authServiceProvider);
      if (!authService.canAccessMeter(meterId)) {
        _lastRejectedValue = rawValue;
        _showError('Este medidor no está asignado a su cuenta.');
        return;
      }

      // Resolve apartment_id from assigned apartments if not in QR
      apartmentId ??= authService.getApartmentIdByMeter(meterId);

      // Clear any error snackbars before navigating
      ScaffoldMessenger.of(context).clearSnackBars();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PrepareMeasurementScreen(
            meterId: meterId!,
            apartmentInfo: apartmentInfo ?? '',
            apartmentId: apartmentId,
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
