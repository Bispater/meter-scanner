import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../domain/measurement_cycle_helpers.dart';
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
        duration: const Duration(seconds: 4),
      ),
    );
    _lastErrorTime = DateTime.now();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    if (_lastErrorTime != null &&
        DateTime.now().difference(_lastErrorTime!).inSeconds < 2) {
      return;
    }

    unawaited(_processCapture(capture));
  }

  Future<void> _processCapture(BarcodeCapture capture) async {
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    final String? rawValue = barcode.rawValue;
    if (rawValue == null) return;

    if (rawValue == _lastRejectedValue) return;

    setState(() => _isProcessing = true);

    try {
      String qrCode = '';
      String apartmentInfo = '';
      int? apartmentId;
      String meterReadingLayout = meterLayoutA;
      var parsedJsonQr = false;

      try {
        final Map<String, dynamic> data = jsonDecode(rawValue);
        final qrData = QrScanData.fromJson(data);
        parsedJsonQr = true;
        qrCode = qrData.qrCode;
        apartmentInfo = qrData.apartmentInfo.isNotEmpty ? qrData.apartmentInfo : '';
        apartmentId = qrData.apartmentId;
        meterReadingLayout = qrData.meterType;
      } catch (_) {
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

      final authService = ref.read(authServiceProvider);
      if (!authService.canAccessByQrCode(qrCode)) {
        _lastRejectedValue = rawValue;
        _showError('Este departamento no está asignado a su cuenta.');
        return;
      }

      apartmentId ??= authService.getApartmentIdByQrCode(qrCode);

      if (!parsedJsonQr) {
        meterReadingLayout = authService.getReadingLayoutForQrOrMeter(qrCode);
      }

      final repo = ref.read(measurementRepositoryProvider);
      final measurements = await repo.getRecentMeasurements();

      String buildingName = '';
      try {
        final a = authService.assignedApartments.firstWhere(
          (x) =>
              (apartmentId != null && x.id == apartmentId) ||
              x.qrCode == qrCode ||
              x.meterId == qrCode,
        );
        buildingName = a.buildingName;
      } catch (_) {}

      var duplicate = false;
      if (buildingName.isNotEmpty) {
        duplicate = apartmentHasMeasurementInActiveCycleWindows(
          apartmentId: apartmentId,
          meterId: qrCode,
          measurements: measurements,
          cycles: authService.activeCycles,
          buildingName: buildingName,
        );
      } else if (authService.userRole == 'admin') {
        for (final c in authService.activeCycles) {
          for (final m in measurements) {
            if (m.meterId == qrCode &&
                capturedInCycleWindow(m.dateTime, c.scheduledDate, c.deadline)) {
              duplicate = true;
              break;
            }
          }
          if (duplicate) break;
        }
      }

      if (duplicate) {
        _lastRejectedValue = rawValue;
        _showError(
          'Ya hay una medición registrada para este departamento en el período del ciclo actual. '
          'No se puede volver a medir desde la app.',
        );
        return;
      }

      if (!mounted) return;
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
    } finally {
      if (mounted) setState(() => _isProcessing = false);
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
