import 'package:flutter/material.dart';

import '../api.dart';
import '../food_store.dart';
import '../format.dart';
import '../models.dart';

/// Waktu makan default berdasarkan jam sekarang.
String defaultMealType() {
  final h = DateTime.now().hour;
  if (h < 11) return 'sarapan';
  if (h < 15) return 'siang';
  if (h < 18) return 'sore';
  return 'malam';
}

/// Bottom sheet tambah/edit makanan. Mengembalikan true jika data berubah.
Future<bool> showEntrySheet(BuildContext context,
    {required DateTime date, String? mealType, MealEntry? existing}) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _EntrySheet(date: date, mealType: mealType ?? existing?.mealType ?? defaultMealType(), existing: existing),
  );
  return changed ?? false;
}

class _EntrySheet extends StatefulWidget {
  final DateTime date;
  final String mealType;
  final MealEntry? existing;
  const _EntrySheet({required this.date, required this.mealType, this.existing});

  @override
  State<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<_EntrySheet> {
  late String _mealType = widget.mealType;
  List<Food>? _foods;
  Object? _loadError;
  Food? _selected;
  bool _manual = false;
  bool _useUnit = false;
  bool _saving = false;
  bool _askingAi = false;
  String _query = '';

  final _amount = TextEditingController();
  final _manualName = TextEditingController();
  final _manualKcal = TextEditingController();
  final _manualProtein = TextEditingController();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      if (e.foodId == null) {
        _manual = true;
        _manualName.text = e.foodName;
        _manualKcal.text = fmtNum(e.kcal);
        _manualProtein.text = e.protein > 0 ? fmtNum(e.protein) : '';
      } else {
        _useUnit = e.grams == null;
        _amount.text = fmtNum(e.grams ?? e.quantity ?? 0);
      }
    }
    _amount.addListener(() => setState(() {}));
    FoodStore.load().then((foods) {
      if (!mounted) return;
      setState(() {
        _foods = foods;
        if (e?.foodId != null) {
          _selected = foods.where((f) => f.id == e!.foodId).firstOrNull;
          if (_selected == null) _manual = true; // makanannya sudah dihapus
        }
      });
    }, onError: (Object err) {
      if (mounted) setState(() => _loadError = err);
    });
  }

  /// Tanya AI kalori makanan yang belum ada di daftar, lalu simpan ke daftar supaya
  /// lain kali tidak perlu tanya lagi.
  Future<void> _askAi() async {
    final name = _query.trim();
    setState(() => _askingAi = true);
    try {
      final estimate = await Api.instance.estimateFood(name);
      if (!mounted) return;
      final ok = await showDialog<bool>(context: context, builder: (_) => _AiEstimateDialog(estimate: estimate));
      if (ok != true || !mounted) return;

      Food food;
      try {
        food = await Api.instance.createFood(estimate.toFoodBody());
      } on ApiException {
        // Nama sudah ada di daftar (mis. disimpan sebelumnya) — pakai yang sudah ada.
        final foods = await FoodStore.load(force: true);
        final existing = foods.where((f) => f.name.toLowerCase() == estimate.name.toLowerCase()).firstOrNull;
        if (existing == null) rethrow;
        food = existing;
      }
      FoodStore.invalidate();
      if (!mounted) return;
      setState(() => _foods = [...?_foods?.where((f) => f.id != food.id), food]);
      _select(food);
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted) setState(() => _askingAi = false);
    }
  }

  void _select(Food food) {
    setState(() {
      _selected = food;
      _useUnit = !food.hasPer100g;
      _amount.text = food.hasPer100g ? '' : '1';
    });
  }

  Future<void> _save() async {
    final body = <String, dynamic>{'eaten_on': isoDate(widget.date), 'meal_type': _mealType};
    if (_manual) {
      final kcal = parseNum(_manualKcal.text);
      if (_manualName.text.trim().isEmpty || kcal == null) return showMessage(context, 'Isi nama dan kalori');
      body.addAll({
        'food_name': _manualName.text.trim(),
        'kcal': kcal,
        'protein': parseNum(_manualProtein.text) ?? 0,
      });
    } else {
      final amount = parseNum(_amount.text);
      if (_selected == null || amount == null || amount <= 0) return showMessage(context, 'Pilih makanan dan isi jumlahnya');
      body.addAll({'food_id': _selected!.id, if (_useUnit) 'quantity': amount else 'grams': amount});
    }

    setState(() => _saving = true);
    try {
      final existing = widget.existing;
      existing == null ? await Api.instance.createEntry(body) : await Api.instance.updateEntry(existing.id, body);
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
      await Api.instance.deleteEntry(widget.existing!.id);
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
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(widget.existing == null ? 'Tambah makanan' : 'Edit makanan', style: theme.textTheme.titleLarge),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  for (final type in mealTypes)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(mealLabels[type]!),
                        selected: _mealType == type,
                        onSelected: (_) => setState(() => _mealType = type),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: _body(theme)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (widget.existing != null)
                    TextButton.icon(
                      onPressed: _saving ? null : _delete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Hapus'),
                    ),
                  const Spacer(),
                  if (_manual || _selected != null)
                    FilledButton(onPressed: _saving ? null : _save, child: const Text('Simpan')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(ThemeData theme) {
    if (_manual) return _manualForm();
    if (_selected != null) return _amountForm(theme, _selected!);
    if (_loadError != null) return Center(child: Text('$_loadError'));
    if (_foods == null) return const Center(child: CircularProgressIndicator());

    final q = _query.toLowerCase();
    final results = _foods!.where((f) => f.name.toLowerCase().contains(q)).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            autofocus: true,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Cari makanan… (nasi, ayam, oatmeal)'),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              if (_query.trim().length >= 2)
                ListTile(
                  leading: _askingAi
                      ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                  title: Text('Tanya AI: "${_query.trim()}"'),
                  subtitle: Text(_askingAi ? 'Sedang menghitung kalori…' : 'AI memperkirakan kalorinya, kamu tinggal isi gram'),
                  onTap: _askingAi ? null : _askAi,
                ),
              for (final food in results)
                ListTile(title: Text(food.name), subtitle: Text(food.description), onTap: () => _select(food)),
              ListTile(
                leading: const Icon(Icons.edit_note),
                title: Text(_query.isEmpty ? 'Isi kalori manual' : 'Isi manual: "$_query"'),
                subtitle: const Text('Untuk makanan yang tidak ada di daftar'),
                onTap: () => setState(() {
                  _manual = true;
                  _manualName.text = _query;
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _amountForm(ThemeData theme, Food food) {
    final amount = parseNum(_amount.text);
    final kcal = food.previewKcal(grams: _useUnit ? null : amount, quantity: _useUnit ? amount : null);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(food.name, style: theme.textTheme.titleMedium),
          subtitle: Text(food.description),
          trailing: widget.existing == null
              ? TextButton(onPressed: () => setState(() => _selected = null), child: const Text('Ganti'))
              : null,
        ),
        if (food.hasPer100g && food.hasUnit) ...[
          SegmentedButton<bool>(
            segments: [
              const ButtonSegment(value: false, label: Text('Gram')),
              ButtonSegment(value: true, label: Text(food.unitName!)),
            ],
            selected: {_useUnit},
            onSelectionChanged: (s) => setState(() {
              _useUnit = s.first;
              _amount.text = _useUnit ? '1' : '';
            }),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _amount,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: _useUnit ? 'Jumlah' : 'Berat',
            suffixText: _useUnit ? food.unitName : 'g',
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            kcal == null ? '— kkal' : fmtKcal(kcal),
            style: theme.textTheme.displaySmall?.copyWith(color: theme.colorScheme.primary),
          ),
        ),
      ],
    );
  }

  Widget _manualForm() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 8),
        TextField(controller: _manualName, decoration: const InputDecoration(labelText: 'Nama makanan')),
        const SizedBox(height: 12),
        TextField(
          controller: _manualKcal,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Kalori', suffixText: 'kkal'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _manualProtein,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Protein (opsional)', suffixText: 'g'),
        ),
        if (widget.existing == null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: () => setState(() => _manual = false), child: const Text('← Pilih dari daftar')),
          ),
      ],
    );
  }
}

class _AiEstimateDialog extends StatelessWidget {
  final FoodEstimate estimate;
  const _AiEstimateDialog({required this.estimate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = estimate;
    String per(double? kcal, double? protein, String unit) =>
        '${fmtKcal(kcal!)}${protein != null ? ' · protein ${fmtNum(protein)} g' : ''} / $unit';

    return AlertDialog(
      icon: Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
      title: Text(e.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (e.kcalPer100g != null) Text(per(e.kcalPer100g, e.proteinPer100g, '100 g'), style: theme.textTheme.titleMedium),
          if (e.kcalPerUnit != null) Text(per(e.kcalPerUnit, e.proteinPerUnit, e.unitName!), style: theme.textTheme.titleMedium),
          if (e.assumption.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(e.assumption, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 12),
          Text('Ini perkiraan AI. Bisa dikoreksi kapan saja di menu Makanan.', style: theme.textTheme.bodySmall),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Simpan & pakai')),
      ],
    );
  }
}
