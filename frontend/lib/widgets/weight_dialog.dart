import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api.dart';
import '../format.dart';
import '../models.dart';

/// Dialog tambah/edit berat badan. Mengembalikan true jika data berubah.
Future<bool> showWeightDialog(BuildContext context, {WeightLog? existing, DateTime? initialDate}) async {
  final changed = await showDialog<bool>(
    context: context,
    builder: (_) => _WeightDialog(existing: existing, initialDate: initialDate),
  );
  return changed ?? false;
}

class _WeightDialog extends StatefulWidget {
  final WeightLog? existing;
  final DateTime? initialDate;
  const _WeightDialog({this.existing, this.initialDate});

  @override
  State<_WeightDialog> createState() => _WeightDialogState();
}

class _WeightDialogState extends State<_WeightDialog> {
  late final _weight = TextEditingController(text: widget.existing == null ? '' : fmtNum(widget.existing!.weightKg));
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late DateTime _at = widget.existing?.measuredAt ?? _defaultTime();
  late String? _condition = widget.existing?.condition ?? 'belum_makan';
  bool _saving = false;

  DateTime _defaultTime() {
    final now = DateTime.now();
    final d = widget.initialDate;
    if (d == null || DateUtils.isSameDay(d, now)) return now;
    return DateTime(d.year, d.month, d.day, 7);
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_at));
    if (time == null) return;
    setState(() => _at = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _save() async {
    final kg = parseNum(_weight.text);
    if (kg == null || kg < 20 || kg > 400) return showMessage(context, 'Isi berat yang valid');
    setState(() => _saving = true);
    final body = {
      'weight_kg': kg,
      'measured_at': _at.toUtc().toIso8601String(),
      'condition': _condition,
      'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
    };
    try {
      final existing = widget.existing;
      existing == null ? await Api.instance.createWeight(body) : await Api.instance.updateWeight(existing.id, body);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        showMessage(context, e);
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    setState(() => _saving = true);
    try {
      await Api.instance.deleteWeight(widget.existing!.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        showMessage(context, e);
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Catat berat badan' : 'Edit berat badan'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _weight,
              autofocus: widget.existing == null,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Berat', suffixText: 'kg'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDateTime,
              icon: const Icon(Icons.schedule),
              label: Text(DateFormat('EEE, d MMM yyyy · HH.mm').format(_at)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final entry in conditionLabels.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _condition == entry.key,
                    onSelected: (sel) => setState(() => _condition = sel ? entry.key : null),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(controller: _note, decoration: const InputDecoration(labelText: 'Catatan (opsional)')),
          ],
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(onPressed: _saving ? null : _delete, child: const Text('Hapus')),
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('Simpan')),
      ],
    );
  }
}
