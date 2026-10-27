import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api.dart';
import '../format.dart';
import '../models.dart';
import '../offline.dart';
import '../widgets/error_view.dart';
import '../widgets/weight_dialog.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  int _range = 30;
  late Future<(Stats, List<WeightLog>, EnergyEstimate)> _future = _load();

  Future<(Stats, List<WeightLog>, EnergyEstimate)> _load() async {
    final results = await Future.wait([
      Api.instance.getStats(days: _range),
      Api.instance.getWeights(),
      Api.instance.getEnergy(),
    ]);
    return (results[0] as Stats, results[1] as List<WeightLog>, results[2] as EnergyEstimate);
  }

  void _reload() => setState(() => _future = _load());

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

  Future<void> _useTarget(int kcal) async {
    try {
      await Api.instance.updateProfile({'daily_kcal_target': kcal});
      if (!mounted) return;
      showMessage(context, 'Target kalori diubah jadi ${fmtKcal(kcal)}');
      _reload();
    } catch (e) {
      if (mounted) showMessage(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progres')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (await showWeightDialog(context)) _reload();
        },
        icon: const Icon(Icons.monitor_weight_outlined),
        label: const Text('Timbang'),
      ),
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(message: '${snap.error}', onRetry: _reload);
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final (stats, weights, energy) = snap.data!;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 7, label: Text('7 hari')),
                    ButtonSegment(value: 30, label: Text('30 hari')),
                    ButtonSegment(value: 90, label: Text('90 hari')),
                  ],
                  selected: {_range},
                  onSelectionChanged: (s) {
                    _range = s.first;
                    _reload();
                  },
                ),
                const SizedBox(height: 12),
                _SummaryGrid(stats: stats),
                _Insight(stats: stats),
                _EnergyCard(energy: energy, currentTarget: stats.kcalTarget, onUseTarget: _useTarget),
                _ChartCard(title: 'Berat badan (pagi)', child: _WeightChart(stats: stats)),
                _ChartCard(title: 'Kalori per hari', child: _KcalChart(stats: stats)),
                const SizedBox(height: 16),
                Text('Riwayat timbangan', style: Theme.of(context).textTheme.titleMedium),
                if (weights.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Belum ada data.')),
                for (final w in weights.take(60))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.monitor_weight_outlined),
                    title: Text(fmtKg(w.weightKg)),
                    subtitle: Text([
                      DateFormat('EEE, d MMM yyyy · HH.mm').format(w.measuredAt),
                      if (w.condition != null) conditionLabels[w.condition],
                    ].join(' · ')),
                    onTap: () async {
                      if (await showWeightDialog(context, existing: w)) _reload();
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final Stats stats;
  const _SummaryGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final change = stats.weightStart != null && stats.weightEnd != null ? stats.weightEnd! - stats.weightStart! : null;
    String signed(double v, String unit) => '${v >= 0 ? '+' : ''}${NumberFormat('0.0#', 'id_ID').format(v)} $unit';

    final tiles = [
      ('Berat terakhir', stats.weightEnd == null ? '—' : fmtKg(stats.weightEnd!)),
      ('Perubahan', change == null ? '—' : signed(change, 'kg')),
      ('Tren', stats.weeklyChangeKg == null ? '—' : signed(stats.weeklyChangeKg!, 'kg/minggu')),
      ('Rata-rata kalori', stats.avgKcal == null ? '—' : fmtKcal(stats.avgKcal!)),
      ('Capai target', '${stats.daysOnTarget} / ${stats.daysLogged} hari'),
      ('Rata-rata protein', stats.avgProtein == null ? '—' : '${stats.avgProtein} g'),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.25,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (final (label, value) in tiles)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  FittedBox(child: Text(value, style: Theme.of(context).textTheme.titleMedium)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Ringkasan satu kalimat: apakah makan sudah cukup untuk naik berat.
class _Insight extends StatelessWidget {
  final Stats stats;
  const _Insight({required this.stats});

  @override
  Widget build(BuildContext context) {
    final avg = stats.avgKcal;
    if (avg == null || stats.daysLogged < 3) return const SizedBox.shrink();
    final gap = stats.kcalTarget - avg;
    final trend = stats.weeklyChangeKg;

    final String message;
    if (gap > 150) {
      message = 'Rata-rata kamu makan ${fmtKcal(avg)}/hari, kurang ${fmtKcal(gap)} dari target. '
          'Coba tambah 1 porsi camilan padat kalori atau Pro Gainer lebih sering.';
    } else if (trend != null && trend < 0.1) {
      message = 'Kalori sudah dekat target tapi berat belum naik. Pertimbangkan naikkan target ±250 kkal.';
    } else {
      message = 'Mantap, asupan sudah sesuai target. Pertahankan!';
    }

    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      color: gap > 150 ? scheme.tertiaryContainer : scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.lightbulb_outline),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

/// Kebutuhan kalori yang dihitung dari catatan makan + timbangan pagi 28 hari terakhir.
class _EnergyCard extends StatelessWidget {
  final EnergyEstimate energy;
  final int currentTarget;
  final ValueChanged<int> onUseTarget;
  const _EnergyCard({required this.energy, required this.currentTarget, required this.onUseTarget});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = energy;

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kebutuhan kalori kamu', style: theme.textTheme.titleMedium),
            Text('Dihitung dari catatan makan & timbangan pagi ${e.windowDays} hari terakhir',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            if (!e.ok)
              Text('${e.reason}.\nSaat ini: ${e.daysLogged} hari tercatat, ${e.weighIns} kali timbang.')
            else ...[
              Text('± ${fmtKcal(e.tdeeKcal!)} / hari', style: theme.textTheme.headlineSmall),
              Text('untuk menjaga berat tetap (keyakinan ${e.confidence})', style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              Text(
                'Rata-rata kamu makan ${fmtKcal(e.avgIntakeKcal!)} dan berat '
                '${e.weeklyChangeKg! >= 0 ? 'naik' : 'turun'} ${fmtNum(e.weeklyChangeKg!.abs())} kg/minggu.',
              ),
              const SizedBox(height: 12),
              for (final t in e.targets)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text('Naik ${fmtNum(t.weeklyGainKg)} kg/minggu'),
                  subtitle: Text('Makan ± ${fmtKcal(t.kcal)} / hari'),
                  trailing: t.kcal == currentTarget
                      ? const Chip(label: Text('Target aktif'))
                      : FilledButton.tonal(onPressed: () => onUseTarget(t.kcal), child: const Text('Jadikan target')),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 12),
              child: Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
            SizedBox(height: 200, child: child),
          ],
        ),
      ),
    );
  }
}

/// Label tanggal di sumbu bawah, cukup beberapa titik supaya tidak bertumpuk.
SideTitles _dateTitles(List<StatsDay> days) {
  final step = (days.length / 5).ceil().clamp(1, 1000);
  return SideTitles(
    showTitles: true,
    reservedSize: 24,
    interval: 1,
    getTitlesWidget: (value, meta) {
      final i = value.toInt();
      if (i < 0 || i >= days.length || value != i || i % step != 0) return const SizedBox.shrink();
      return SideTitleWidget(
        meta: meta,
        child: Text(DateFormat('d/M').format(days[i].date), style: const TextStyle(fontSize: 10)),
      );
    },
  );
}

class _WeightChart extends StatelessWidget {
  final Stats stats;
  const _WeightChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spots = [
      for (var i = 0; i < stats.days.length; i++)
        if (stats.days[i].weightKg != null) FlSpot(i.toDouble(), stats.days[i].weightKg!),
    ];
    if (spots.isEmpty) return const Center(child: Text('Belum ada data berat di rentang ini'));

    final values = [...spots.map((s) => s.y), if (stats.targetWeightKg != null) stats.targetWeightKg!];
    final minY = (values.reduce((a, b) => a < b ? a : b) - 1).floorToDouble();
    final maxY = (values.reduce((a, b) => a > b ? a : b) + 1).ceilToDouble();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (stats.days.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          bottomTitles: AxisTitles(sideTitles: _dateTitles(stats.days)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
        ),
        extraLinesData: ExtraLinesData(horizontalLines: [
          if (stats.targetWeightKg != null)
            HorizontalLine(
              y: stats.targetWeightKg!,
              color: scheme.tertiary,
              dashArray: [6, 4],
              label: HorizontalLineLabel(show: true, labelResolver: (_) => 'target'),
            ),
        ]),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            preventCurveOverShooting: true,
            color: scheme.primary,
            barWidth: 3,
            dotData: FlDotData(show: spots.length <= 31),
            belowBarData: BarAreaData(show: true, color: scheme.primary.withValues(alpha: 0.12)),
          ),
        ],
      ),
    );
  }
}

class _KcalChart extends StatelessWidget {
  final Stats stats;
  const _KcalChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxKcal = stats.days.fold<double>(stats.kcalTarget.toDouble(), (m, d) => d.kcal > m ? d.kcal : m);
    final barWidth = (240 / stats.days.length).clamp(2.0, 16.0);

    return BarChart(
      BarChartData(
        maxY: (maxKcal / 500).ceil() * 500,
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          bottomTitles: AxisTitles(sideTitles: _dateTitles(stats.days)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, interval: 1000)),
        ),
        extraLinesData: ExtraLinesData(horizontalLines: [
          HorizontalLine(y: stats.kcalTarget.toDouble(), color: scheme.primary, dashArray: [6, 4]),
        ]),
        barGroups: [
          for (var i = 0; i < stats.days.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: stats.days[i].kcal,
                width: barWidth,
                color: stats.days[i].kcal >= stats.kcalTarget ? scheme.primary : scheme.tertiary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(barWidth / 3)),
              ),
            ]),
        ],
      ),
    );
  }
}
