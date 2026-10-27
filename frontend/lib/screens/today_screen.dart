import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api.dart';
import '../format.dart';
import '../models.dart';
import '../offline.dart';
import '../widgets/brand.dart';
import '../widgets/entry_sheet.dart';
import '../widgets/kcal_calendar.dart';
import '../widgets/error_view.dart';
import '../widgets/weight_dialog.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  late Future<DaySummary> _future = Api.instance.getDay(_date);

  void _reload() => setState(() => _future = Api.instance.getDay(_date));

  @override
  void initState() {
    super.initState();
    SyncStatus.synced.addListener(_reload); // antrean offline terkirim: ambil data terbaru dari server
  }

  @override
  void dispose() {
    SyncStatus.synced.removeListener(_reload);
    super.dispose();
  }

  void _changeDate(DateTime d) {
    _date = DateUtils.dateOnly(d);
    _reload();
  }

  Future<void> _pickDate() async {
    final d = await showKcalCalendar(context, selected: _date);
    if (d != null) _changeDate(d);
  }

  Future<void> _addEntry([String? mealType]) async {
    if (await showEntrySheet(context, date: _date, mealType: mealType)) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(_date, DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _pickDate,
          child: Text(isToday ? 'Hari ini' : DateFormat('EEE, d MMM yyyy').format(_date)),
        ),
        actions: [
          IconButton(
            tooltip: 'Hari sebelumnya',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeDate(_date.subtract(const Duration(days: 1))),
          ),
          IconButton(
            tooltip: 'Hari berikutnya',
            icon: const Icon(Icons.chevron_right),
            onPressed: isToday ? null : () => _changeDate(_date.add(const Duration(days: 1))),
          ),
          IconButton(tooltip: 'Pilih tanggal', icon: const Icon(Icons.calendar_month), onPressed: _pickDate),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addEntry(),
        icon: const Icon(Icons.add),
        label: const Text('Makanan'),
      ),
      body: FutureBuilder<DaySummary>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return ErrorView(message: '${snap.error}', onRetry: _reload);
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final day = snap.data!;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                _SummaryCard(day: day),
                const SizedBox(height: 12),
                _WeightCard(
                  day: day,
                  onAdd: () async {
                    if (await showWeightDialog(context, initialDate: _date)) _reload();
                  },
                  onEdit: (w) async {
                    if (await showWeightDialog(context, existing: w)) _reload();
                  },
                ),
                for (final type in mealTypes)
                  if (day.meals[type]!.isNotEmpty || type != 'camilan' && type != 'sore')
                    _MealCard(
                      type: type,
                      entries: day.meals[type]!,
                      onAdd: () => _addEntry(type),
                      onEdit: (e) async {
                        if (await showEntrySheet(context, date: _date, existing: e)) _reload();
                      },
                    ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final type in ['sore', 'camilan'])
                        if (day.meals[type]!.isEmpty)
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 18),
                            label: Text(mealLabels[type]!),
                            onPressed: () => _addEntry(type),
                          ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Kartu utama bergradasi: cincin kalori, sisa target, dan bar protein.
class _SummaryCard extends StatelessWidget {
  final DaySummary day;
  const _SummaryCard({required this.day});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = day.kcalTarget == 0 ? 0.0 : (day.totalKcal / day.kcalTarget).clamp(0.0, 1.0);
    final percent = day.kcalTarget == 0 ? 0 : (day.totalKcal / day.kcalTarget * 100).round();
    final proteinProgress = day.proteinTarget == 0 ? 0.0 : (day.totalProtein / day.proteinTarget).clamp(0.0, 1.0);
    final remaining = day.kcalTarget - day.totalKcal;
    final reached = remaining <= 0;
    const white = Colors.white;
    final soft = white.withValues(alpha: 0.8);

    return Container(
      decoration: BoxDecoration(
        gradient: Brand.gradientOf(context),
        borderRadius: BorderRadius.circular(26),
        boxShadow: Brand.glowOf(context),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox.square(
                dimension: 116,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 11,
                      backgroundColor: white.withValues(alpha: 0.22),
                      color: reached ? Brand.mint : white,
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$percent%', style: theme.textTheme.headlineSmall?.copyWith(color: white)),
                          Text('target', style: theme.textTheme.bodySmall?.copyWith(color: soft)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('KALORI', style: theme.textTheme.labelMedium?.copyWith(color: soft, letterSpacing: 1.5)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        fmtKcal(day.totalKcal),
                        style: theme.textTheme.headlineMedium?.copyWith(color: white, fontWeight: FontWeight.w900),
                      ),
                    ),
                    Text('dari ${fmtKcal(day.kcalTarget)}', style: theme.textTheme.bodyMedium?.copyWith(color: soft)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: reached ? Brand.mint : Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        reached ? '🔥 Tercapai +${fmtKcal(-remaining)}' : 'Kurang ${fmtKcal(remaining)}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: reached ? Brand.navyDeep : white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text('Protein', style: theme.textTheme.labelLarge?.copyWith(color: white, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text(
                '${fmtNum(day.totalProtein.round())} / ${day.proteinTarget} g',
                style: theme.textTheme.labelLarge?.copyWith(color: soft),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: proteinProgress,
              minHeight: 8,
              backgroundColor: white.withValues(alpha: 0.22),
              color: proteinProgress >= 1 ? Brand.mint : white,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeightCard extends StatelessWidget {
  final DaySummary day;
  final VoidCallback onAdd;
  final ValueChanged<WeightLog> onEdit;
  const _WeightCard({required this.day, required this.onAdd, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.monitor_weight_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: day.weights.isEmpty
                  ? const Text('Belum timbang')
                  : Wrap(
                      spacing: 8,
                      children: [
                        for (final w in day.weights)
                          ActionChip(
                            label: Text('${fmtKg(w.weightKg)} · ${DateFormat('HH.mm').format(w.measuredAt)}'),
                            onPressed: () => onEdit(w),
                          ),
                      ],
                    ),
            ),
            IconButton(tooltip: 'Catat berat', icon: const Icon(Icons.add), onPressed: onAdd),
          ],
        ),
      ),
    );
  }
}

const _mealIcons = {
  'sarapan': Icons.wb_twilight,
  'siang': Icons.wb_sunny_outlined,
  'sore': Icons.local_cafe_outlined,
  'malam': Icons.nightlight_outlined,
  'camilan': Icons.cookie_outlined,
};

class _MealCard extends StatelessWidget {
  final String type;
  final List<MealEntry> entries;
  final VoidCallback onAdd;
  final ValueChanged<MealEntry> onEdit;
  const _MealCard({required this.type, required this.entries, required this.onAdd, required this.onEdit});

  String _amount(MealEntry e) {
    if (e.grams != null) return '${fmtNum(e.grams!)} g';
    if (e.quantity != null) return '${fmtNum(e.quantity!)}×';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtotal = entries.fold<double>(0, (s, e) => s + e.kcal);
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_mealIcons[type] ?? Icons.restaurant, color: theme.colorScheme.onPrimaryContainer, size: 22),
            ),
            title: Text(mealLabels[type]!, style: theme.textTheme.titleMedium),
            subtitle: entries.isEmpty ? null : Text(fmtKcal(subtotal)),
            trailing: IconButton(tooltip: 'Tambah ke ${mealLabels[type]}', icon: const Icon(Icons.add_circle_outline), onPressed: onAdd),
          ),
          for (final e in entries)
            ListTile(
              dense: true,
              title: Text(e.foodName),
              subtitle: Text(_amount(e)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (e.isPending)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Tooltip(
                        message: 'Belum terkirim ke server',
                        child: Icon(Icons.cloud_upload_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  Text(
                    e.kcal == 0 ? '? kkal' : fmtKcal(e.kcal),
                    style: e.kcal == 0 ? TextStyle(color: theme.colorScheme.error) : null,
                  ),
                ],
              ),
              onTap: () => onEdit(e),
            ),
          if (entries.isNotEmpty) const SizedBox(height: 8),
        ],
      ),
    );
  }
}
