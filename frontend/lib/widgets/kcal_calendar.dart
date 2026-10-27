import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api.dart';
import '../format.dart';
import '../models.dart';

/// Kalender bulanan yang menampilkan kalori yang dimakan tiap hari. Mengembalikan tanggal yang diketuk.
Future<DateTime?> showKcalCalendar(BuildContext context, {required DateTime selected}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _KcalCalendar(selected: DateUtils.dateOnly(selected)),
  );
}

class _KcalCalendar extends StatefulWidget {
  final DateTime selected;
  const _KcalCalendar({required this.selected});

  @override
  State<_KcalCalendar> createState() => _KcalCalendarState();
}

class _KcalCalendarState extends State<_KcalCalendar> {
  late DateTime _month = DateTime(widget.selected.year, widget.selected.month);
  late Future<Stats> _future = Api.instance.getMonth(_month);

  DateTime get _thisMonth => DateTime(DateTime.now().year, DateTime.now().month);

  void _go(int delta) => setState(() {
        _month = DateTime(_month.year, _month.month + delta);
        _future = Api.instance.getMonth(_month);
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: FutureBuilder<Stats>(
          future: _future,
          builder: (context, snap) {
            final stats = snap.data;
            final byDate = {for (final d in stats?.days ?? <StatsDay>[]) isoDate(d.date): d};
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(onPressed: () => _go(-1), icon: const Icon(Icons.chevron_left)),
                    Expanded(
                      child: Text(
                        DateFormat('MMMM yyyy').format(_month),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: _month.isBefore(_thisMonth) ? () => _go(1) : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _Legend(scheme: scheme),
                const SizedBox(height: 12),
                _Grid(
                  month: _month,
                  selected: widget.selected,
                  byDate: byDate,
                  kcalTarget: stats?.kcalTarget,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: Center(
                    child: switch (snap) {
                      AsyncSnapshot(hasError: true) => Text('${snap.error}', style: TextStyle(color: scheme.error)),
                      AsyncSnapshot(hasData: false) => const LinearProgressIndicator(),
                      _ => Text(
                          stats!.daysLogged == 0
                              ? 'Belum ada catatan di bulan ini'
                              : 'Rata-rata ${fmtKcal(stats.avgKcal ?? 0)} · ${stats.daysLogged} hari tercatat · '
                                  '${stats.daysOnTarget} capai target',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final ColorScheme scheme;
  const _Legend({required this.scheme});

  @override
  Widget build(BuildContext context) {
    Widget item(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      children: [item(scheme.primary, 'Capai target'), item(scheme.tertiary, 'Di bawah target')],
    );
  }
}

class _Grid extends StatelessWidget {
  final DateTime month;
  final DateTime selected;
  final Map<String, StatsDay> byDate;
  final int? kcalTarget;

  const _Grid({required this.month, required this.selected, required this.byDate, required this.kcalTarget});

  static const _weekdays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = DateUtils.dateOnly(DateTime.now());
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final leading = DateTime(month.year, month.month).weekday - 1; // minggu dimulai hari Senin

    return Column(
      children: [
        Row(
          children: [
            for (final w in _weekdays)
              Expanded(
                child: Text(
                  w,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: w == 'Min' ? scheme.error : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 0.78,
          ),
          itemCount: leading + daysInMonth,
          itemBuilder: (context, i) {
            if (i < leading) return const SizedBox.shrink();
            final date = DateTime(month.year, month.month, i - leading + 1);
            final stat = byDate[isoDate(date)];
            final logged = stat != null && stat.logged && stat.kcal > 0;
            final reached = logged && kcalTarget != null && stat.kcal >= kcalTarget!;
            final isSelected = DateUtils.isSameDay(date, selected);
            final isFuture = date.isAfter(today);

            final accent = reached ? scheme.primary : scheme.tertiary;
            final Color bg = isSelected
                ? scheme.primary
                : logged
                    ? (reached ? scheme.primaryContainer : scheme.tertiaryContainer)
                    : Colors.transparent;
            final Color fg = isSelected
                ? scheme.onPrimary
                : logged
                    ? (reached ? scheme.onPrimaryContainer : scheme.onTertiaryContainer)
                    : scheme.onSurface.withValues(alpha: isFuture ? 0.3 : 0.8);

            return Material(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: isFuture ? null : () => Navigator.pop(context, date),
                child: Container(
                  decoration: DateUtils.isSameDay(date, today) && !isSelected
                      ? BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: scheme.primary, width: 1.5),
                        )
                      : null,
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${date.day}',
                        style: theme.textTheme.titleSmall?.copyWith(color: fg, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          logged ? fmtNum(stat.kcal.round()) : (isFuture ? '' : '–'),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isSelected ? fg : (logged ? accent : fg),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
