import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../api.dart';
import '../format.dart';
import '../models.dart';
import '../widgets/error_view.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Profile> _future = Api.instance.getProfile();
  final _name = TextEditingController();
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _targetWeight = TextEditingController();
  bool _filled = false;
  bool _saving = false;

  void _fill(Profile p) {
    if (_filled) return;
    _filled = true;
    _name.text = p.displayName ?? '';
    _kcal.text = '${p.dailyKcalTarget}';
    _protein.text = '${p.dailyProteinTarget}';
    _targetWeight.text = p.targetWeightKg == null ? '' : fmtNum(p.targetWeightKg!);
  }

  Future<void> _save() async {
    final kcal = int.tryParse(_kcal.text.trim());
    final protein = int.tryParse(_protein.text.trim());
    if (kcal == null || protein == null) return showMessage(context, 'Target kalori & protein harus angka bulat');
    setState(() => _saving = true);
    try {
      await Api.instance.updateProfile({
        'display_name': _name.text.trim().isEmpty ? null : _name.text.trim(),
        'daily_kcal_target': kcal,
        'daily_protein_target': protein,
        'target_weight_kg': parseNum(_targetWeight.text),
      });
      if (mounted) showMessage(context, 'Tersimpan');
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Profil & target')),
      body: FutureBuilder<Profile>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return ErrorView(
              message: '${snap.error}',
              onRetry: () => setState(() => _future = Api.instance.getProfile()),
            );
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          _fill(snap.data!);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(email, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nama panggilan')),
              const SizedBox(height: 12),
              TextField(
                controller: _kcal,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Target kalori harian', suffixText: 'kkal'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _protein,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Target protein harian',
                  suffixText: 'g',
                  helperText: 'Untuk bulking umumnya 1,6–2 g per kg berat badan',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _targetWeight,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Target berat badan (opsional)', suffixText: 'kg'),
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: _saving ? null : _save, child: const Text('Simpan')),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () => Supabase.instance.client.auth.signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Keluar'),
              ),
            ],
          );
        },
      ),
    );
  }
}
