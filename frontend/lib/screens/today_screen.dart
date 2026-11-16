import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api.dart';
import '../format.dart';
import '../home_widget_service.dart';
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
  late Future<DaySummary> _future = _load();

  /// Ambil data hari terpilih; kalau itu hari ini, sekalian perbarui widget layar utama.
  Future<DaySummary> _load() async {
    final date = _date;
    final day = await Api.instance.getDay(date);
    if (DateUtils.isSameDay(date, DateTime.now())) HomeWidgetService.update(day).ignore();
    return day;
  }

  void _reload() => setState(() => _future = _load());

  @override
  void initState() {
    super.initState();
    SyncStatus.synced.addListener(_reload); // antrean offline terkirim: ambil data terbaru dari server
    HomeWidgetService.pendingAdd.addListener(_onWidgetAdd);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onWidgetAdd());
  }

  @override
  void dispose() {
    SyncStatus.synced.removeListener(_reload);
    HomeWidgetService.pendingAdd.removeListener(_onWidgetAdd);
    super.dispose();
  }

  /// Dibuka dari tombol "+ Catat makan" di widget: catat untuk hari ini.
  void _onWidgetAdd() {
    if (!mounted || !HomeWidgetService.pendingAdd.value) return;
    HomeWidgetService.pendingAdd.value = false;
    if (!DateUtils.isSameDay(_date, DateTime.now())) _changeDate(DateTime.now());
    Navigator.of(context).popUntil((r) => r.isFirst); // tutup sheet/dialog yang mungkin masih terbuka
    _addEntry();
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isToday ? 'Hari ini' : DateFormat('EEEE').format(_date)),
              Text(
                DateFormat('d MMMM yyyy').format(_date),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
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
    // Angka & cincin "berjalan" dari nilai sebelumnya ke nilai baru setiap data berubah.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: day.totalKcal),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, kcal, _) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: day.totalProtein),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, protein, _) => _build(context, kcal, protein),
      ),
    );
  }

  Widget _build(BuildContext context, double totalKcal, double totalProtein) {
    final theme = Theme.of(context);
    final progress = day.kcalTarget == 0 ? 0.0 : (totalKcal / day.kcalTarget).clamp(0.0, 1.0);
    final percent = day.kcalTarget == 0 ? 0 : (totalKcal / day.kcalTarget * 100).round();
    final proteinProgress = day.proteinTarget == 0 ? 0.0 : (totalProtein / day.proteinTarget).clamp(0.0, 1.0);
    // Status (kurang / tercapai) memakai nilai akhir, bukan nilai animasi, supaya tidak berkedip.
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
                        fmtKcal(totalKcal),
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
                '${fmtNum(totalProtein.round())} / ${day.proteinTarget} g',
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
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            IconBadge(icon: Icons.monitor_weight_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Berat badan', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  if (day.weights.isEmpty)
                    Text('Belum timbang hari ini', style: theme.textTheme.bodySmall)
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final w in day.weights)
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => onEdit(w),
                            child: Pill(
                              '${fmtKg(w.weightKg)} · ${DateFormat('HH.mm').format(w.measuredAt)}',
                              color: theme.colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            IconButton.filledTonal(tooltip: 'Catat berat', icon: const Icon(Icons.add), onPressed: onAdd),
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
    final scheme = theme.colorScheme;
    final accent = Brand.mealColors[type] ?? scheme.primary;
    final subtotal = entries.fold<double>(0, (s, e) => s + e.kcal);
    return Card(
      margin: const EdgeInsets.only(top: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                IconBadge(icon: _mealIcons[type] ?? Icons.restaurant, color: accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mealLabels[type]!, style: theme.textTheme.titleMedium),
                      Text(
                        entries.isEmpty ? 'Belum ada makanan' : '${entries.length} makanan',
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (entries.isNotEmpty) Pill(fmtKcal(subtotal), color: scheme.primary),
                IconButton(
                  tooltip: 'Tambah ke ${mealLabels[type]}',
                  icon: Icon(Icons.add_circle, color: accent),
                  onPressed: onAdd,
                ),
              ],
            ),
          ),
          for (final e in entries) ...[
            Divider(height: 1, indent: 16, endIndent: 16, color: theme.dividerTheme.color),
            InkWell(
              onTap: () => onEdit(e),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.foodName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                          if (_amount(e).isNotEmpty)
                            Text(_amount(e), style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    if (e.isPending)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Tooltip(
                          message: 'Belum terkirim ke server',
                          child: Icon(Icons.cloud_upload_outlined, size: 16, color: scheme.onSurfaceVariant),
                        ),
                      ),
                    Text(
                      e.kcal == 0 ? '? kkal' : fmtKcal(e.kcal),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: e.kcal == 0 ? scheme.error : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (entries.isNotEmpty) const SizedBox(height: 4),
        ],
      ),
    );
  }
}
