import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth_errors.dart';
import '../format.dart';
import '../widgets/auth_scaffold.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

/// 0 = kosong, 1 = lemah, 2 = sedang, 3 = kuat
int passwordStrength(String p) {
  if (p.isEmpty) return 0;
  var score = 0;
  if (p.length >= 8) score++;
  if (p.length >= 12) score++;
  if (RegExp(r'[a-zA-Z]').hasMatch(p) && RegExp(r'\d').hasMatch(p)) score++;
  if (RegExp(r'[^a-zA-Z0-9]').hasMatch(p) || RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p)) score++;
  if (p.length < 8) return 1;
  return score >= 3 ? 3 : 2;
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    final name = _name.text.trim();
    final email = _email.text.trim();
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: _password.text,
        data: {'display_name': name}, // dipakai trigger handle_new_user untuk mengisi profil
      );
      if (!mounted) return;

      if (res.session != null) {
        // Langsung login: tutup layar daftar, AuthGate otomatis menampilkan aplikasi.
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).popUntil((route) => route.isFirst);
        messenger.showSnackBar(SnackBar(content: Text('Akun dibuat. Selamat datang, $name! 🎉')));
      } else {
        // Project Supabase mewajibkan konfirmasi email.
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.mark_email_unread_outlined, size: 40),
            title: const Text('Cek email kamu'),
            content: Text('Kami mengirim link konfirmasi ke $email. Buka link itu, lalu masuk dengan akunmu.'),
            actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Oke'))],
          ),
        );
        if (mounted) Navigator.pop(context, email);
      }
    } on AuthException catch (e) {
      if (mounted) showMessage(context, authErrorMessage(e));
    } catch (e) {
      if (mounted) showMessage(context, 'Gagal membuat akun. Cek koneksi internet.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strength = passwordStrength(_password.text);
    final strengthInfo = switch (strength) {
      1 => ('Lemah', Colors.red),
      2 => ('Sedang', Colors.orange),
      3 => ('Kuat', Colors.green),
      _ => ('', Colors.transparent),
    };

    return AuthScaffold(
      showBack: true,
      title: 'Buat akun',
      subtitle: 'Mulai catat perjalanan naik berat badanmu',
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.nickname],
                decoration: const InputDecoration(labelText: 'Nama panggilan', prefixIcon: Icon(Icons.badge_outlined)),
                validator: (v) => v != null && v.trim().isNotEmpty ? null : 'Isi nama panggilan',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                validator: (v) =>
                    v != null && RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()) ? null : 'Email tidak valid',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: 'Minimal 8 karakter, campur huruf dan angka',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.length < 8) return 'Minimal 8 karakter';
                  if (!RegExp(r'[a-zA-Z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) return 'Campur huruf dan angka';
                  return null;
                },
              ),
              if (strength > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: strength / 3,
                          minHeight: 6,
                          color: strengthInfo.$2,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(strengthInfo.$1, style: theme.textTheme.bodySmall?.copyWith(color: strengthInfo.$2)),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirm,
                obscureText: _obscure,
                decoration: const InputDecoration(labelText: 'Ulangi password', prefixIcon: Icon(Icons.lock_reset)),
                validator: (v) => v == _password.text ? null : 'Password tidak sama',
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: _loading
                    ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Text('Buat akun', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _loading ? null : () => Navigator.pop(context),
                child: const Text('Sudah punya akun? Masuk'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
