import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../api.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/brand.dart';
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
      final saved = await Api.instance.updateProfile({
        'display_name': _name.text.trim().isEmpty ? null : _name.text.trim(),
        'daily_kcal_target': kcal,
        'daily_protein_target': protein,
        'target_weight_kg': parseNum(_targetWeight.text),
      });
      if (!mounted) return;
      setState(() => _future = Future.value(saved)); // header ikut menampilkan target baru
      showMessage(context, 'Tersimpan');
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
          final profile = snap.data!;
          _fill(profile);
          final theme = Theme.of(context);
          final scheme = theme.colorScheme;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _ProfileHeader(name: profile.displayName, email: email, profile: profile),
              const SizedBox(height: 20),
              _Section(
                icon: Icons.person_outline,
                color: Brand.accents[0],
                title: 'Akun',
                children: [
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nama panggilan', prefixIcon: Icon(Icons.badge_outlined)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Section(
                icon: Icons.flag_outlined,
                color: Brand.accents[2],
                title: 'Target harian',
                children: [
                  TextField(
                    controller: _kcal,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Target kalori',
                      suffixText: 'kkal',
                      prefixIcon: Icon(Icons.local_fire_department_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _protein,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Target protein',
                      suffixText: 'g',
                      prefixIcon: Icon(Icons.egg_outlined),
                      helperText: 'Untuk bulking umumnya 1,6–2 g per kg berat badan',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _targetWeight,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Target berat badan (opsional)',
                      suffixText: 'kg',
                      prefixIcon: Icon(Icons.monitor_weight_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check),
                    label: const Text('Simpan perubahan'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Section(
                icon: Icons.palette_outlined,
                color: Brand.accents[4],
                title: 'Tampilan',
                children: [
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: ThemeController.mode,
                    builder: (context, mode, _) => SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto), label: Text('Sistem')),
                        ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode), label: Text('Terang')),
                        ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode), label: Text('Gelap')),
                      ],
                      selected: {mode},
                      onSelectionChanged: (s) => ThemeController.set(s.first),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () => Supabase.instance.client.auth.signOut(),
                style: TextButton.styleFrom(foregroundColor: scheme.error, minimumSize: const Size(0, 48)),
                icon: const Icon(Icons.logout),
                label: const Text('Keluar dari akun'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Kartu bergradasi di atas: avatar huruf awal, nama, email, dan ringkasan target.
class _ProfileHeader extends StatelessWidget {
  final String? name;
  final String email;
  final Profile profile;
  const _ProfileHeader({required this.name, required this.email, required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = (name?.trim().isNotEmpty ?? false) ? name!.trim() : 'Pejuang bulking';
    const white = Colors.white;
    final soft = white.withValues(alpha: 0.8);

    Widget stat(String value, String label) => Expanded(
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: theme.textTheme.titleMedium?.copyWith(color: white, fontWeight: FontWeight.w800)),
              ),
              Text(label, style: theme.textTheme.labelSmall?.copyWith(color: soft)),
            ],
          ),
        );

    return Container(
      decoration: BoxDecoration(
        gradient: Brand.gradientOf(context),
        borderRadius: BorderRadius.circular(26),
        boxShadow: Brand.glowOf(context),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Brand.mint,
                  border: Border.all(color: white.withValues(alpha: 0.5), width: 2),
                ),
                child: Text(
                  display.characters.first.toUpperCase(),
                  style: const TextStyle(color: Brand.navyDeep, fontSize: 26, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Halo,', style: theme.textTheme.bodyMedium?.copyWith(color: soft)),
                    Text(
                      display,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(color: white),
                    ),
                    if (email.isNotEmpty)
                      Text(email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: soft)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                stat(fmtKcal(profile.dailyKcalTarget), 'target kalori'),
                stat('${profile.dailyProteinTarget} g', 'target protein'),
                stat(profile.targetWeightKg == null ? '—' : fmtKg(profile.targetWeightKg!), 'target berat'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kelompok pengaturan dalam satu kartu dengan judul berikon.
class _Section extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final List<Widget> children;
  const _Section({required this.icon, required this.color, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconBadge(icon: icon, color: color, size: 32),
                const SizedBox(width: 10),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}
