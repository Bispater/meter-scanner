import 'package:flutter/material.dart';
import 'qr_scanner_screen.dart';
import 'prepare_measurement_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .secondary
                        .withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.water_drop_rounded,
                    size: 64,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  'HydroScan Cam',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 12),

                // Subtitle
                Text(
                  'Lectura rápida y precisa de\nmedidores de agua',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white60,
                        height: 1.5,
                      ),
                ),
                const SizedBox(height: 64),

                // Scan QR button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const QrScannerScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 28),
                    label: const Text('Escanear QR'),
                  ),
                ),
                const SizedBox(height: 16),

                // Manual entry option
                TextButton(
                  onPressed: () {
                    _showManualEntryDialog(context);
                  },
                  child: const Text(
                    'Ingreso manual',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),

                const SizedBox(height: 48),

                // Version info
                Text(
                  'v1.0.0 — MVP',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white24,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showManualEntryDialog(BuildContext context) {
    final meterIdController = TextEditingController();
    final apartmentController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ingreso Manual'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: meterIdController,
              decoration: const InputDecoration(
                labelText: 'ID del Medidor',
                hintText: 'Ej: MED-001',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: apartmentController,
              decoration: const InputDecoration(
                labelText: 'Departamento',
                hintText: 'Ej: 4B - Piso 2',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (meterIdController.text.isNotEmpty &&
                  apartmentController.text.isNotEmpty) {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PrepareMeasurementScreen(
                      meterId: meterIdController.text,
                      apartmentInfo: apartmentController.text,
                    ),
                  ),
                );
              }
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }
}

