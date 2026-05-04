import 'package:flutter/material.dart';
import '../../domain/models/meter_reading_layout.dart'
    show meterLayoutA, meterTypeChipLabel;
import 'camera_capture_screen.dart';

class PrepareMeasurementScreen extends StatelessWidget {
  final String meterId;
  final String apartmentInfo;
  final int? apartmentId;
  final String meterReadingLayout;

  const PrepareMeasurementScreen({
    super.key,
    required this.meterId,
    required this.apartmentInfo,
    this.apartmentId,
    this.meterReadingLayout = meterLayoutA,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preparar Medición'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),

              // Success indicator
              Icon(
                Icons.check_circle_outline_rounded,
                size: 72,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(height: 16),
              Text(
                'QR Escaneado Correctamente',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 32),

              // Meter info card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Datos del Medidor',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                      const Divider(height: 24),

                      // Meter ID
                      _InfoRow(
                        icon: Icons.speed_rounded,
                        label: 'ID Medidor',
                        value: meterId,
                      ),
                      const SizedBox(height: 16),

                      // Apartment Info
                      _InfoRow(
                        icon: Icons.apartment_rounded,
                        label: 'Departamento',
                        value: apartmentInfo,
                      ),
                      const SizedBox(height: 16),

                      _InfoRow(
                        icon: Icons.tune_rounded,
                        label: 'Cara del medidor',
                        value: meterTypeChipLabel(meterReadingLayout),
                      ),
                      const SizedBox(height: 16),

                      // Timestamp
                      _InfoRow(
                        icon: Icons.access_time_rounded,
                        label: 'Fecha / Hora',
                        value: _formattedNow(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Instructions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Encaje el medidor en la guía (círculo y recuadro) para una foto clara.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Capture button
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CameraCaptureScreen(
                        meterId: meterId,
                        apartmentInfo: apartmentInfo,
                        apartmentId: apartmentId,
                        meterReadingLayout: meterReadingLayout,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.camera_alt_rounded, size: 28),
                label: const Text('Capturar Medidor'),
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

  String _formattedNow() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/'
        '${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.white54),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white38,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                softWrap: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
