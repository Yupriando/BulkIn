import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.load(); // cepat; supaya splash langsung tampil di mode yang benar
  runApp(const NaikInApp());
}

bool _supabaseReady = false;

/// Dijalankan oleh SplashScreen sambil animasi berjalan. Aman dipanggil ulang (tombol "Coba lagi").
Future<void> _initApp() async {
  await initializeDateFormatting('id_ID');
  Intl.defaultLocale = 'id_ID';
  if (AppConfig.isComplete && !_supabaseReady) {
    await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabaseAnonKey);
    _supabaseReady = true;
  }
}

class NaikInApp extends StatelessWidget {
  const NaikInApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, _) => _app(mode),
    );
  }

  Widget _app(ThemeMode mode) {
    return MaterialApp(
      title: 'NaikIn',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: mode,
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: SplashScreen(
        init: _initApp,
        next: () => AppConfig.isComplete ? const AuthGate() : const _MissingConfig(),
      ),
    );
  }
}

/// Tampilkan layar login atau aplikasi sesuai status sesi Supabase.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, _) => auth.currentSession == null ? const LoginScreen() : const HomeShell(),
    );
  }
}

class _MissingConfig extends StatelessWidget {
  const _MissingConfig();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Konfigurasi belum diisi.\n\nJalankan dengan:\nflutter run --dart-define-from-file=config.json',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
