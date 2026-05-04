import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/auth_service.dart';
import '../../domain/measurement_cycle_helpers.dart';
import '../../domain/models/meter_reading_layout.dart'
    show
        meterLayoutA,
        meterTypeChipLabel,
        meterTypeDescription,
        normalizeMeterReadingLayout;
import '../../domain/reading_value_codec.dart';
import '../../domain/models/water_measurement.dart';
import '../providers/app_providers.dart';
import 'qr_scanner_screen.dart';
import 'prepare_measurement_screen.dart';
import 'work_plan_screen.dart';

// ── Provider that fetches recent measurements ──────────────────────────────
final recentMeasurementsProvider = FutureProvider<List<WaterMeasurement>>((ref) async {
  final repo = ref.read(measurementRepositoryProvider);
  return repo.getRecentMeasurements();
});

// ── Home screen ────────────────────────────────────────────────────────────
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    final auth = ref.read(authServiceProvider);
    await auth.refreshProfile();
    ref.invalidate(recentMeasurementsProvider);
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _logout() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
          '¿Desea cerrar sesión? Se borrará la sesión en este dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    await ref.read(authServiceProvider).logout();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authServiceProvider);
    final recentAsync = ref.watch(recentMeasurementsProvider);
    final cycles = auth.activeCycles;
    final name = auth.displayName ?? 'Operador';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: Theme.of(context).colorScheme.secondary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── App bar ──────────────────────────────────────────────
              SliverAppBar(
                floating: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: Row(
                  children: [
                    Icon(
                      Icons.water_drop_rounded,
                      color: Theme.of(context).colorScheme.secondary,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Metscan',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white54),
                    tooltip: 'Cerrar sesión',
                    onPressed: _logout,
                  ),
                  if (_refreshing)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white54),
                      onPressed: _refresh,
                      tooltip: 'Actualizar',
                    ),
                ],
              ),

              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Greeting ──────────────────────────────────────
                    Text(
                      'Hola, $name',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _greetingSubtitle(cycles),
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    const SizedBox(height: 24),

                    // ── Scan button ────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                        ),
                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 26),
                        label: const Text('Escanear Medidor'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const WorkPlanScreen()),
                        ),
                        icon: const Icon(Icons.checklist_rtl_rounded, size: 22),
                        label: const Text('Plan de trabajo y asignación'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.secondary,
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.45),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: TextButton(
                        onPressed: () => _showManualEntryDialog(context),
                        child: const Text(
                          'Ingreso manual',
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Active cycles ──────────────────────────────────
                    if (cycles.isNotEmpty) ...[
                      _sectionTitle('Ciclos Activos', Icons.event_repeat),
                      const SizedBox(height: 10),
                      ...cycles.map((c) => _CycleCard(
                            cycle: c,
                            onTapPending: (apt) => _navigateToMeter(context, apt),
                          )),
                      const SizedBox(height: 28),
                    ],

                    // ── Recent measurements ────────────────────────────
                    _sectionTitle('Mis Mediciones Recientes', Icons.history),
                    const SizedBox(height: 10),
                    recentAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (_, __) => _emptyCard('No se pudieron cargar las mediciones.'),
                      data: (list) {
                        if (list.isEmpty) {
                          return _emptyCard('Aún no tienes mediciones registradas.');
                        }
                        final sorted = [...list]
                          ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
                        return Column(
                          children: sorted
                              .take(20)
                              .map((m) => _MeasurementTile(measurement: m))
                              .toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _greetingSubtitle(List<CycleInfo> cycles) {
    if (cycles.isEmpty) return 'No hay ciclos activos en este momento.';
    final total = cycles.fold<int>(0, (s, c) => s + c.pendingCount);
    if (total == 0) return '¡Todo al día! No tienes mediciones pendientes.';
    return '$total medición${total != 1 ? 'es' : ''} pendiente${total != 1 ? 's' : ''} en ${cycles.length} ciclo${cycles.length != 1 ? 's' : ''}.';
  }

  Widget _sectionTitle(String title, IconData icon) => Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      );

  Widget _emptyCard(String message) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            message,
            style: const TextStyle(color: Colors.white38, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      );

  Future<void> _navigateToMeter(BuildContext context, CyclePendingApartment apt) async {
    final repo = ref.read(measurementRepositoryProvider);
    final list = await repo.getRecentMeasurements();
    final auth = ref.read(authServiceProvider);
    if (apartmentHasMeasurementInActiveCycleWindows(
      apartmentId: apt.id,
      meterId: apt.meterId,
      measurements: list,
      cycles: auth.activeCycles,
      buildingName: apt.buildingName,
    )) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ya hay medición en el período del ciclo para este departamento.'),
        ),
      );
      return;
    }
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrepareMeasurementScreen(
          meterId: apt.meterId,
          apartmentInfo: apt.apartmentInfo,
          apartmentId: apt.id,
          meterReadingLayout: apt.readingLayout,
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
                hintText: 'Ej: Torre A — Depto 4B',
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
                final auth = ref.read(authServiceProvider);
                final layout = auth.getReadingLayoutForQrOrMeter(
                  meterIdController.text.trim(),
                );
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PrepareMeasurementScreen(
                      meterId: meterIdController.text.trim(),
                      apartmentInfo: apartmentController.text,
                      meterReadingLayout: layout,
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

// ── Cycle card widget ───────────────────────────────────────────────────────
class _CycleCard extends StatefulWidget {
  final CycleInfo cycle;
  final void Function(CyclePendingApartment) onTapPending;

  const _CycleCard({required this.cycle, required this.onTapPending});

  @override
  State<_CycleCard> createState() => _CycleCardState();
}

class _CycleCardState extends State<_CycleCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.cycle;
    final pct = c.progressPct;
    final color = pct >= 1.0 ? Colors.green : Theme.of(context).colorScheme.secondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      _StatusChip(status: c.status),
                      const SizedBox(width: 6),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.white38,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${c.buildingName} · Límite: ${c.deadline}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  // Progress bar
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: Colors.white12,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${c.measuredCount}/${c.totalAssigned}',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (c.pendingCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${c.pendingCount} departamento${c.pendingCount != 1 ? 's' : ''} pendiente${c.pendingCount != 1 ? 's' : ''}',
                        style: TextStyle(
                          color: Colors.amber.shade300,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Expandable pending list
          if (_expanded && c.pendingApartments.isNotEmpty)
            Column(
              children: [
                const Divider(color: Colors.white10, height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                  child: Row(
                    children: [
                      Icon(Icons.pending_actions, size: 14, color: Colors.amber.shade300),
                      const SizedBox(width: 6),
                      Text(
                        'Pendientes',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade300,
                        ),
                      ),
                    ],
                  ),
                ),
                ...c.pendingApartments.map(
                  (apt) => InkWell(
                    onTap: () => widget.onTapPending(apt),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                apt.number,
                                style: TextStyle(
                                  color: Colors.amber.shade300,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  apt.apartmentInfo,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  apt.meterId,
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.qr_code_scanner,
                            size: 18,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          if (_expanded && c.pendingApartments.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: Colors.green.shade400),
                  const SizedBox(width: 6),
                  Text(
                    '¡Todas las mediciones completadas!',
                    style: TextStyle(color: Colors.green.shade400, fontSize: 13),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Status chip ─────────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'in_progress' => ('En Curso', Colors.cyan),
      'pending' => ('Pendiente', Colors.amber),
      'completed' => ('Completado', Colors.green),
      _ => ('Cerrado', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ── Recent measurement tile ─────────────────────────────────────────────────
class _MeasurementTile extends StatelessWidget {
  final WaterMeasurement measurement;
  const _MeasurementTile({required this.measurement});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.secondary;
    final dateStr = _formatDate(measurement.dateTime);

    return InkWell(
      onTap: () => _showDetails(context),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.speed, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    measurement.displayLocation,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    measurement.meterId,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meterTypeChipLabel(measurement.readingLayout ?? meterLayoutA),
                    style: TextStyle(
                      color: accent.withValues(alpha: 0.75),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${measurement.formattedMeterValue} m³',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  dateStr,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return 'Hoy ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Ayer';
    }
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  void _showDetails(BuildContext context) {
    final layout = normalizeMeterReadingLayout(measurement.readingLayout);
    final opLine = measurement.value.isEmpty
        ? '—'
        : '${measurement.formattedMeterValue} m³';
    final ocrRaw = measurement.ocrValue.trim();
    String? aiLine;
    if (ocrRaw.isNotEmpty) {
      final ocrNorm = normalizeApiReadingToDisplayDigits(ocrRaw, layout);
      aiLine = '${formatCubicMetersTypeA5Plus4(ocrNorm)} m³';
    }
    final captured = measurement.dateTime;
    final capturedStr =
        '${captured.day.toString().padLeft(2, '0')}/${captured.month.toString().padLeft(2, '0')}/${captured.year} '
        '${captured.hour.toString().padLeft(2, '0')}:${captured.minute.toString().padLeft(2, '0')}:${captured.second.toString().padLeft(2, '0')}';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Detalle de medición'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(measurement.displayLocation, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 4),
            Text('Medidor: ${measurement.meterId}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            Text('Lectura registrada: $opLine', style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 6),
            Text(
              'Estimación automática: ${aiLine ?? '—'}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Text(
              'Cara: ${meterTypeDescription(layout)}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Text('Fecha y hora de captura: $capturedStr', style: const TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

