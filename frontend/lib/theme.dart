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
  // "fidelity" menjaga warna utama tetap oranye menyala (bukan oranye pucat).
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.ember,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  ).copyWith(
    primary: dark ? const Color(0xFFFF7A2E) : const Color(0xFFE04A0C),
    onPrimary: dark ? const Color(0xFF1F0A00) : Colors.white,
    primaryContainer: dark ? const Color(0xFF4A1E0A) : const Color(0xFFFFE3D3),
    onPrimaryContainer: dark ? const Color(0xFFFFDCC8) : const Color(0xFF4A1700),
    secondary: dark ? Brand.volt : const Color(0xFF4F7A00),
    onSecondary: dark ? Brand.ink : Colors.white,
    tertiary: dark ? const Color(0xFFFFC94D) : const Color(0xFFB7791F),
    onTertiary: dark ? Brand.ink : Colors.white,
    tertiaryContainer: dark ? const Color(0xFF4A3A10) : const Color(0xFFFFF1CC),
    onTertiaryContainer: dark ? const Color(0xFFFFE8A3) : const Color(0xFF4A3205),
    surface: dark ? Brand.ink : const Color(0xFFFFF8F4),
    surfaceContainerHighest: dark ? Brand.inkLine : const Color(0xFFF6E7DF),
  );
  final cardColor = dark ? Brand.inkCard : Colors.white;
  final lineColor = dark ? Brand.inkLine : const Color(0xFFF1E2DA);
  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  final base = ThemeData(brightness: brightness, useMaterial3: true).textTheme;
  // Judul lebih tebal & rapat supaya terasa tegas.
  final textTheme = base.copyWith(
    displayMedium: base.displayMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1.5),
    headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
    headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
    titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w700),
  );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    textTheme: textTheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.8,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: lineColor),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: dark ? const Color(0xFF3A3542) : const Color(0xFFE6D3C9)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: rounded,
        minimumSize: const Size(0, 52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(shape: rounded, side: BorderSide(color: lineColor, width: 1.5)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      extendedTextStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.2),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: cardColor,
      indicatorColor: scheme.primaryContainer,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: scheme.primary,
        selectedForegroundColor: scheme.onPrimary,
        side: BorderSide(color: lineColor, width: 1.5),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: rounded),
    dividerTheme: DividerThemeData(color: lineColor),
  );
}
