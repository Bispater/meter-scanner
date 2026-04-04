import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import 'qr_scanner_screen.dart';
import 'prepare_measurement_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _pendingCount = 0;
  bool _isOnline = true;
  bool _isSyncing = false;
  StreamSubscription<int>? _pendingSub;
  StreamSubscription<bool>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    final syncService = ref.read(syncServiceProvider);
    final connectivity = ref.read(connectivityServiceProvider);

    _pendingCount = syncService.pendingCount;
    _isOnline = connectivity.isOnline;

    _pendingSub = syncService.pendingCountStream.listen((count) {
      if (mounted) setState(() => _pendingCount = count);
    });

    _connectivitySub = connectivity.onConnectivityChanged.listen((online) {
      if (mounted) setState(() => _isOnline = online);
    });
  }

  @override
  void dispose() {
    _pendingSub?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _manualSync() async {
    setState(() => _isSyncing = true);
    final syncService = ref.read(syncServiceProvider);
    await syncService.syncAll();
    if (mounted) setState(() => _isSyncing = false);
  }

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
                // Offline banner
                if (!_isOnline)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Sin conexión a internet',
                          style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),

                // Pending sync banner
                if (_pendingCount > 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_sync_rounded, color: Colors.cyan, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '$_pendingCount medición${_pendingCount == 1 ? '' : 'es'} pendiente${_pendingCount == 1 ? '' : 's'}',
                          style: const TextStyle(color: Colors.cyan, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        if (_isOnline) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _isSyncing ? null : _manualSync,
                            child: _isSyncing
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyan))
                                : const Icon(Icons.sync_rounded, color: Colors.cyan, size: 20),
                          ),
                        ],
                      ],
                    ),
                  ),

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

