import 'package:flutter/material.dart';

import '../api.dart';
import '../food_store.dart';
import '../format.dart';
import '../models.dart';
import '../widgets/error_view.dart';

class FoodsScreen extends StatefulWidget {
  const FoodsScreen({super.key});

  @override
  State<FoodsScreen> createState() => _FoodsScreenState();
}

class _FoodsScreenState extends State<FoodsScreen> {
  late Future<List<Food>> _future = FoodStore.load(force: true);
  String _query = '';

  void _reload() => setState(() => _future = FoodStore.load(force: true));

  Future<void> _edit([Food? food]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _FoodForm(food: food),
    );
    if (changed == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar makanan')),
      floatingActionButton: FloatingActionButton(onPressed: () => _edit(), tooltip: 'Tambah makanan', child: const Icon(Icons.add)),
      body: FutureBuilder<List<Food>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(message: '${snap.error}', onRetry: _reload);
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final q = _query.toLowerCase();
          final foods = snap.data!.where((f) => f.name.toLowerCase().contains(q)).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Cari makanan'),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: foods.length,
                  itemBuilder: (context, i) {
                    final food = foods[i];
                    return ListTile(
                      title: Text(food.name),
                      subtitle: Text(food.description),
                      trailing: food.isBuiltIn ? null : const Icon(Icons.person_outline, size: 18),
                      onTap: () => _edit(food),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FoodForm extends StatefulWidget {
  final Food? food;
  const _FoodForm({this.food});

  @override
  State<_FoodForm> createState() => _FoodFormState();
}

class _FoodFormState extends State<_FoodForm> {
  String _text(double? v) => v == null ? '' : fmtNum(v);

  late final _name = TextEditingController(text: widget.food?.name ?? '');
  late final _kcal100 = TextEditingController(text: _text(widget.food?.kcalPer100g));
  late final _protein100 = TextEditingController(text: _text(widget.food?.proteinPer100g));
  late final _unitName = TextEditingController(text: widget.food?.unitName ?? '');
  late final _kcalUnit = TextEditingController(text: _text(widget.food?.kcalPerUnit));
  late final _proteinUnit = TextEditingController(text: _text(widget.food?.proteinPerUnit));
  bool _saving = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _saving = true);
    try {
      await action();
      FoodStore.invalidate();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        showMessage(context, e);
        setState(() => _saving = false);
      }
    }
  }

  void _save() {
    final unitName = _unitName.text.trim();
    final body = {
      'name': _name.text.trim(),
      'kcal_per_100g': parseNum(_kcal100.text),
      'protein_per_100g': parseNum(_protein100.text),
      'unit_name': unitName.isEmpty ? null : unitName,
      'kcal_per_unit': parseNum(_kcalUnit.text),
      'protein_per_unit': parseNum(_proteinUnit.text),
    };
    if (body['name'] == '') return showMessage(context, 'Isi nama makanan');
    if (body['kcal_per_100g'] == null && body['kcal_per_unit'] == null) {
      return showMessage(context, 'Isi kalori per 100 g atau per satuan');
    }
    final food = widget.food;
    _run(() => food == null ? Api.instance.createFood(body) : Api.instance.updateFood(food.id, body));
  }

  Widget _numField(TextEditingController c, String label, String suffix) => Expanded(
        child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label, suffixText: suffix),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(food == null ? 'Makanan baru' : 'Edit makanan', style: theme.textTheme.titleLarge),
            if (food?.isBuiltIn == true)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Ini makanan bawaan. Perubahanmu disimpan sebagai versi milikmu sendiri.',
                    style: theme.textTheme.bodySmall),
              ),
            const SizedBox(height: 16),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nama')),
            const SizedBox(height: 16),
            Text('Per 100 gram', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(children: [
              _numField(_kcal100, 'Kalori', 'kkal'),
              const SizedBox(width: 12),
              _numField(_protein100, 'Protein', 'g'),
            ]),
            const SizedBox(height: 16),
            Text('Per satuan (bungkus, porsi, butir…) — opsional', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(controller: _unitName, decoration: const InputDecoration(labelText: 'Nama satuan', hintText: 'bungkus')),
            const SizedBox(height: 12),
            Row(children: [
              _numField(_kcalUnit, 'Kalori', 'kkal'),
              const SizedBox(width: 12),
              _numField(_proteinUnit, 'Protein', 'g'),
            ]),
            const SizedBox(height: 20),
            Row(
              children: [
                if (food != null && !food.isBuiltIn)
                  TextButton.icon(
                    onPressed: _saving ? null : () => _run(() => Api.instance.deleteFood(food.id)),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Hapus'),
                  ),
                const Spacer(),
                FilledButton(onPressed: _saving ? null : _save, child: const Text('Simpan')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
