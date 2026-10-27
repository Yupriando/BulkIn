import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widgets/brand.dart';

/// Mode tampilan (Sistem / Terang / Gelap), disimpan di HP.
class ThemeController {
  static const _key = 'theme_mode';
  static final mode = ValueNotifier<ThemeMode>(ThemeMode.system);

  static Future<void> load() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_key);
      mode.value = ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => ThemeMode.system);
    } catch (_) {
      // Gagal baca pengaturan: tetap pakai mode sistem.
    }
  }

  static Future<void> set(ThemeMode value) async {
    mode.value = value;
    await (await SharedPreferences.getInstance()).setString(_key, value.name);
  }
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  // "fidelity" menjaga warna utama tetap dekat dengan biru tua aslinya (bukan biru pucat).
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.navy,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  ).copyWith(
    // Mode gelap: biru terang bertulisan putih, bukan biru pucat bawaan Material.
    primary: dark ? const Color(0xFF2F6FD6) : null,
    onPrimary: dark ? Colors.white : null,
    primaryContainer: dark ? const Color(0xFF1E3A6E) : null,
    onPrimaryContainer: dark ? const Color(0xFFD6E3FF) : null,
    tertiary: dark ? Brand.accent : const Color(0xFFB7791F),
    onTertiary: dark ? Brand.navyDeep : Colors.white,
    tertiaryContainer: dark ? const Color(0xFF4A3A10) : const Color(0xFFFFF1CC),
    onTertiaryContainer: dark ? const Color(0xFFFFE8A3) : const Color(0xFF4A3205),
    surface: dark ? const Color(0xFF0B1426) : const Color(0xFFF7F9FD),
  );
  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? const Color(0xFF13203A) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: dark ? const Color(0xFF1F2F50) : const Color(0xFFE3E9F4)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF13203A) : Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: dark ? const Color(0xFF2A3B5E) : const Color(0xFFCBD5E6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(shape: rounded)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(shape: rounded)),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      shape: rounded,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? const Color(0xFF0E1A31) : Colors.white,
      indicatorColor: scheme.primaryContainer,
      surfaceTintColor: Colors.transparent,
    ),
    chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: rounded),
  );
}
