import 'package:flutter/material.dart';

import '../api.dart';
import '../food_store.dart';
import '../format.dart';
import '../models.dart';
import '../widgets/brand.dart';
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    q.isEmpty ? '${foods.length} makanan' : '${foods.length} hasil untuk "$_query"',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ),
              Expanded(
                child: foods.isEmpty
                    ? _EmptyFoods(query: _query)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                        itemCount: foods.length,
                        itemBuilder: (context, i) => _FoodTile(food: foods[i], onTap: () => _edit(foods[i])),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Satu makanan: avatar huruf awal berwarna, nama, keterangan, dan kalori utama.
class _FoodTile extends StatelessWidget {
  final Food food;
  final VoidCallback onTap;
  const _FoodTile({required this.food, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = Brand.accentFor(food.name);
    final dark = theme.brightness == Brightness.dark;
    // Angka besar di kanan: per satuan kalau ada (lebih sering dipakai), selain itu per 100 g.
    final (kcal, unit) = food.hasUnit
        ? (food.kcalPerUnit!, '/${food.unitName}')
        : (food.kcalPer100g ?? 0, '/100 g');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: dark ? 0.22 : 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  food.name.isEmpty ? '?' : food.name.characters.first.toUpperCase(),
                  style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            food.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (!food.isBuiltIn) ...[
                          const SizedBox(width: 6),
                          Pill('Milikmu', color: scheme.secondary),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      food.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(fmtNum(kcal.round()), style: theme.textTheme.titleMedium?.copyWith(color: scheme.primary)),
                  Text('kkal$unit', style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFoods extends StatelessWidget {
  final String query;
  const _EmptyFoods({required this.query});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconBadge(icon: Icons.search_off, color: theme.colorScheme.primary, size: 64),
            const SizedBox(height: 16),
            Text('"$query" belum ada di daftar', style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              'Tambah sendiri dengan tombol +, atau pakai "Tanya AI" saat mencatat makanan.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
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
