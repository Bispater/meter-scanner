import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart' show SharePlus, ShareParams;
import '../../data/services/auth_service.dart';
import '../../domain/measurement_cycle_helpers.dart';
import '../../domain/models/meter_reading_layout.dart' show meterTypeChipLabel;
import '../../domain/models/water_measurement.dart';
import '../providers/app_providers.dart';
import 'home_screen.dart' show recentMeasurementsProvider;
import 'prepare_measurement_screen.dart';

/// Plan de trabajo: pendientes por ciclo y departamentos asignados, con búsqueda y filtros.
class WorkPlanScreen extends ConsumerStatefulWidget {
  const WorkPlanScreen({super.key});

  @override
  ConsumerState<WorkPlanScreen> createState() => _WorkPlanScreenState();
}

enum _PlanFilter { all, todo, hecho }

class _WorkPlanScreenState extends ConsumerState<WorkPlanScreen>
    with SingleTickerProviderStateMixin {
  bool _refreshing = false;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  _PlanFilter _filter = _PlanFilter.all;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 1);
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await ref.read(authServiceProvider).refreshProfile();
    ref.invalidate(recentMeasurementsProvider);
    if (mounted) setState(() => _refreshing = false);
  }

  int _comparePending(CyclePendingApartment a, CyclePendingApartment b) {
    final bld = a.buildingName.compareTo(b.buildingName);
    if (bld != 0) return bld;
    final tw = a.towerName.compareTo(b.towerName);
    if (tw != 0) return tw;
    final f = a.floor.compareTo(b.floor);
    if (f != 0) return f;
    return _numKey(a.number).compareTo(_numKey(b.number));
  }

  int _numKey(String s) {
    final n = int.tryParse(s.replaceAll(RegExp(r'\D'), ''));
    return n ?? 0;
  }

  int _compareAssigned(AssignedApartment a, AssignedApartment b) {
    final bld = a.buildingName.compareTo(b.buildingName);
    if (bld != 0) return bld;
    final tw = a.towerName.compareTo(b.towerName);
    if (tw != 0) return tw;
    return _numKey(a.number).compareTo(_numKey(b.number));
  }

  List<CyclePendingApartment> _mergedPending(List<CycleInfo> cycles) {
    final seen = <int>{};
    final out = <CyclePendingApartment>[];
    for (final c in cycles) {
      for (final a in c.pendingApartments) {
        if (seen.add(a.id)) out.add(a);
      }
    }
    out.sort(_comparePending);
    return out;
  }

  bool _matchesQuery(String q, String building, String tower, String number, String meterId, String info) {
    if (q.isEmpty) return true;
    final hay = '${building.toLowerCase()} ${tower.toLowerCase()} ${number.toLowerCase()} '
        '${meterId.toLowerCase()} ${info.toLowerCase()}';
    return hay.contains(q);
  }

  String _exportText(List<CyclePendingApartment> pending, List<AssignedApartment> assigned) {
    final buf = StringBuffer();
    final date = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    buf.writeln('Metscan — Plan de trabajo');
    buf.writeln('Generado: $date');
    buf.writeln('');
    buf.writeln('=== Pendientes en ciclos activos (${pending.length}) ===');
    for (final a in pending) {
      buf.writeln(
        '${a.buildingName} | ${a.towerName} | Piso ${a.floor} | Dpto ${a.number} | Medidor ${a.meterId} | ${a.apartmentInfo}',
      );
    }
    buf.writeln('');
    buf.writeln('=== Mis departamentos asignados (${assigned.length}) ===');
    for (final a in assigned) {
      buf.writeln(
        '${a.buildingName} | ${a.towerName} | Dpto ${a.number} | Medidor ${a.meterId} | ${a.apartmentInfo}',
      );
    }
    return buf.toString();
  }

  Future<void> _copyExport(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lista copiada al portapapeles')),
    );
  }

  Future<void> _shareExport(String text) async {
    await SharePlus.instance.share(
      ShareParams(text: text, subject: 'Metscan — plan de trabajo'),
    );
  }

  bool _doneAssigned(
    AssignedApartment a,
    List<WaterMeasurement> measurements,
    List<CycleInfo> cycles,
  ) {
    return apartmentHasMeasurementInActiveCycleWindows(
      apartmentId: a.id,
      meterId: a.meterId,
      measurements: measurements,
      cycles: cycles,
      buildingName: a.buildingName,
    );
  }

  bool _donePending(
    CyclePendingApartment a,
    List<WaterMeasurement> measurements,
    List<CycleInfo> cycles,
  ) {
    return apartmentHasMeasurementInActiveCycleWindows(
      apartmentId: a.id,
      meterId: a.meterId,
      measurements: measurements,
      cycles: cycles,
      buildingName: a.buildingName,
    );
  }

  List<CyclePendingApartment> _filterPending(
    List<CyclePendingApartment> list,
    List<WaterMeasurement> measurements,
    List<CycleInfo> cycles,
  ) {
    return list.where((a) {
      if (!_matchesQuery(_query, a.buildingName, a.towerName, a.number, a.meterId, a.apartmentInfo)) {
        return false;
      }
      final done = _donePending(a, measurements, cycles);
      switch (_filter) {
        case _PlanFilter.all:
          return true;
        case _PlanFilter.todo:
          return !done;
        case _PlanFilter.hecho:
          return done;
      }
    }).toList();
  }

  List<AssignedApartment> _filterAssigned(
    List<AssignedApartment> list,
    List<WaterMeasurement> measurements,
    List<CycleInfo> cycles,
  ) {
    return list.where((a) {
      if (!_matchesQuery(_query, a.buildingName, a.towerName, a.number, a.meterId, a.apartmentInfo)) {
        return false;
      }
      final done = _doneAssigned(a, measurements, cycles);
      switch (_filter) {
        case _PlanFilter.all:
          return true;
        case _PlanFilter.todo:
          return !done;
        case _PlanFilter.hecho:
          return done;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authServiceProvider);
    final recentAsync = ref.watch(recentMeasurementsProvider);
    final measurements = recentAsync.maybeWhen(
      data: (list) => list,
      orElse: () => <WaterMeasurement>[],
    );
    final cycles = auth.activeCycles;
    final assigned = [...auth.assignedApartments]..sort(_compareAssigned);
    final pending = _mergedPending(cycles);

    final assignedDone = assigned.where((a) => _doneAssigned(a, measurements, cycles)).length;
    final pendingDone = pending.where((a) => _donePending(a, measurements, cycles)).length;

    final theme = Theme.of(context);
    final export = _exportText(pending, assigned);

    final filteredPending = _filterPending(pending, measurements, cycles);
    final filteredAssigned = _filterAssigned(assigned, measurements, cycles);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan de trabajo'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'En ciclo (${pending.length})'),
            Tab(text: 'Mi asignación (${assigned.length})'),
          ],
        ),
        actions: [
          if (_refreshing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar desde servidor',
              onPressed: _refresh,
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.ios_share_outlined),
            tooltip: 'Exportar lista completa',
            onSelected: (v) {
              if (v == 'copy') _copyExport(export);
              if (v == 'share') _shareExport(export);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'copy', child: Text('Copiar texto')),
              PopupMenuItem(value: 'share', child: Text('Compartir…')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (cycles.isEmpty)
            Material(
              color: Colors.amber.withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade400, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Sin ciclos activos no se puede marcar "Ya medido" por fechas. '
                        'Las lecturas siguen en "Mis mediciones recientes".',
                        style: TextStyle(color: Colors.amber.shade200, fontSize: 12, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _SummaryCard(
              pendingCount: pending.length,
              pendingDone: pendingDone,
              cycleCount: cycles.length,
              assignedCount: assigned.length,
              assignedDone: assignedDone,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Buscar edificio, torre, depto, medidor…',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                    prefixIcon: Icon(Icons.search, color: theme.colorScheme.secondary.withValues(alpha: 0.8)),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                            },
                          ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Todos',
                        selected: _filter == _PlanFilter.all,
                        onTap: () => setState(() => _filter = _PlanFilter.all),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Por medir',
                        selected: _filter == _PlanFilter.todo,
                        onTap: () => setState(() => _filter = _PlanFilter.todo),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Ya medidos',
                        selected: _filter == _PlanFilter.hecho,
                        onTap: () => setState(() => _filter = _PlanFilter.hecho),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  onRefresh: _refresh,
                  color: theme.colorScheme.secondary,
                  child: _pendingTabBody(
                    context,
                    filteredPending,
                    pending,
                    measurements,
                    cycles,
                  ),
                ),
                RefreshIndicator(
                  onRefresh: _refresh,
                  color: theme.colorScheme.secondary,
                  child: _assignedTabBody(
                    context,
                    filteredAssigned,
                    assigned,
                    measurements,
                    cycles,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pendingTabBody(
    BuildContext context,
    List<CyclePendingApartment> filtered,
    List<CyclePendingApartment> full,
    List<WaterMeasurement> measurements,
    List<CycleInfo> cycles,
  ) {
    if (full.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Aquí aparecen los departamentos que el servidor marca como pendientes en tus ciclos activos.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 16),
          _emptyBox('No hay pendientes en ciclos activos, o aún no hay ciclos cargados.'),
        ],
      );
    }
    if (filtered.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          _emptyBox('Ningún resultado con el buscador o filtro actual. Prueba "Todos" o borra el texto.'),
        ],
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final a = filtered[i];
        final done = _donePending(a, measurements, cycles);
        return _PendingTile(
          apt: a,
          isMeasured: done,
          onTap: () {
            if (done) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Ya consta una medición en el período del ciclo. Use "Actualizar" si acaba de enviar.',
                  ),
                ),
              );
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PrepareMeasurementScreen(
                  meterId: a.meterId,
                  apartmentInfo: a.apartmentInfo,
                  apartmentId: a.id,
                  meterReadingLayout: a.readingLayout,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _assignedTabBody(
    BuildContext context,
    List<AssignedApartment> filtered,
    List<AssignedApartment> full,
    List<WaterMeasurement> measurements,
    List<CycleInfo> cycles,
  ) {
    if (full.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Tu administrador define qué departamentos puedes leer. '
            'Escanea el QR o usa esta lista para ir uno por uno.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 16),
          _emptyBox('No hay departamentos en tu asignación (revisa con tu administrador).'),
        ],
      );
    }
    if (filtered.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          _emptyBox('Ningún resultado con el buscador o filtro actual. Prueba "Todos" o borra el texto.'),
        ],
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final a = filtered[i];
        final done = _doneAssigned(a, measurements, cycles);
        return _AssignedTile(
          apt: a,
          isMeasured: done,
          onTap: () {
            if (done) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Ya consta una medición en el período del ciclo para este departamento.',
                  ),
                ),
              );
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PrepareMeasurementScreen(
                  meterId: a.meterId,
                  apartmentInfo: a.apartmentInfo,
                  apartmentId: a.id,
                  meterReadingLayout: a.readingLayout,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _emptyBox(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(msg, style: const TextStyle(color: Colors.white38, fontSize: 13)),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.secondary;
    return Material(
      color: selected ? accent.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? accent : Colors.white70,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int pendingCount;
  final int pendingDone;
  final int cycleCount;
  final int assignedCount;
  final int assignedDone;

  const _SummaryCard({
    required this.pendingCount,
    required this.pendingDone,
    required this.cycleCount,
    required this.assignedCount,
    required this.assignedDone,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progreso (según tu app y ventana de fechas del ciclo)',
            style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            '• Ciclo: $pendingDone de $pendingCount pendientes del servidor con lectura en ventana',
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
          ),
          Text(
            '• Asignación: $assignedDone de $assignedCount con lectura en ventana',
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
          ),
          if (cycleCount > 0)
            Text(
              '• $cycleCount ciclo${cycleCount != 1 ? 's' : ''} activo${cycleCount != 1 ? 's' : ''}',
              style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.35),
            ),
        ],
      ),
    );
  }
}

class _PendingTile extends StatelessWidget {
  final CyclePendingApartment apt;
  final bool isMeasured;
  final VoidCallback onTap;

  const _PendingTile({
    required this.apt,
    required this.isMeasured,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.secondary;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isMeasured ? Colors.white.withValues(alpha: 0.04) : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isMeasured
                      ? Colors.green.withValues(alpha: 0.2)
                      : accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: isMeasured
                      ? Icon(Icons.check_circle, color: Colors.green.shade400, size: 22)
                      : Text(
                          '${apt.floor}',
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            apt.apartmentInfo,
                            style: TextStyle(
                              color: isMeasured ? Colors.white70 : Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (isMeasured)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Ya medido',
                              style: TextStyle(
                                color: Colors.green.shade400,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      '${apt.buildingName} · ${apt.towerName} · Dpto ${apt.number}',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    Text(
                      apt.meterId,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      meterTypeChipLabel(apt.readingLayout),
                      style: TextStyle(
                        color: accent.withValues(alpha: 0.75),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: accent.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssignedTile extends StatelessWidget {
  final AssignedApartment apt;
  final bool isMeasured;
  final VoidCallback onTap;

  const _AssignedTile({
    required this.apt,
    required this.isMeasured,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.secondary;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isMeasured ? Colors.white.withValues(alpha: 0.04) : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                isMeasured ? Icons.check_circle : Icons.home_work_outlined,
                color: isMeasured ? Colors.green.shade400 : accent.withValues(alpha: 0.85),
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            apt.apartmentInfo,
                            style: TextStyle(
                              color: isMeasured ? Colors.white70 : Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (isMeasured)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Ya medido',
                              style: TextStyle(
                                color: Colors.green.shade400,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      '${apt.buildingName} · ${apt.towerName} · Dpto ${apt.number}',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    Text(
                      apt.meterId,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      meterTypeChipLabel(apt.readingLayout),
                      style: TextStyle(
                        color: accent.withValues(alpha: 0.75),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.touch_app_outlined, color: accent.withValues(alpha: 0.5), size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
