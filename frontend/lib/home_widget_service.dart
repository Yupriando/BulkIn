import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import 'format.dart';
import 'models.dart';

/// Penghubung ke widget layar utama Android (lihat android/.../BulkInWidgetProvider.kt).
///
/// Aplikasi menyimpan ringkasan hari ini → widget membacanya. Widget tidak mengambil data sendiri,
/// jadi angkanya sesuai saat terakhir aplikasi dibuka / makanan dicatat.
class HomeWidgetService {
  HomeWidgetService._();

  /// Semua ukuran widget (3×3, 2×2, 4×1, 2×1) — membaca data yang sama.
  static const _androidProviders = [
    'BulkInWidgetProvider',
    'BulkInWidgetSmallProvider',
    'BulkInWidgetWideProvider',
    'BulkInWidgetMiniProvider',
  ];

  static Future<void> _redrawAll() =>
      Future.wait([for (final name in _androidProviders) HomeWidget.updateWidget(androidName: name)]);

  /// Widget hanya ada di Android; di web / platform lain semua fungsi diam saja.
  static bool get _supported => !kIsWeb && Platform.isAndroid;

  /// Simpan ringkasan hari ini lalu minta widget menggambar ulang.
  static Future<void> update(DaySummary day) async {
    if (!_supported) return;
    try {
      final remaining = day.kcalTarget - day.totalKcal;
      final percent = day.kcalTarget == 0 ? 0 : (day.totalKcal / day.kcalTarget * 100).round();
      final proteinPercent = day.proteinTarget == 0 ? 0 : (day.totalProtein / day.proteinTarget * 100).round();
      final latest = day.weights.isEmpty
          ? null
          : day.weights.reduce((a, b) => a.measuredAt.isAfter(b.measuredAt) ? a : b);

      await Future.wait([
        HomeWidget.saveWidgetData<bool>('logged_in', true),
        HomeWidget.saveWidgetData<String>('date', day.date),
        HomeWidget.saveWidgetData<String>('kcal', fmtNum(day.totalKcal.round())),
        HomeWidget.saveWidgetData<String>('kcal_target', fmtNum(day.kcalTarget)),
        HomeWidget.saveWidgetData<int>('percent', percent),
        HomeWidget.saveWidgetData<String>(
          'remaining',
          remaining <= 0 ? '🔥 Tercapai +${fmtKcal(-remaining)}' : 'Sisa ${fmtKcal(remaining)}',
        ),
        HomeWidget.saveWidgetData<String>('protein', '${fmtNum(day.totalProtein.round())} / ${day.proteinTarget} g'),
        HomeWidget.saveWidgetData<int>('protein_percent', proteinPercent),
        HomeWidget.saveWidgetData<String>('protein_target', '${day.proteinTarget} g'),
        HomeWidget.saveWidgetData<String>(
          'weight',
          latest == null ? '' : 'Berat ${fmtKg(latest.weightKg)} · ${DateFormat('HH.mm').format(latest.measuredAt)}',
        ),
      ]);
      await _redrawAll();
    } catch (e) {
      debugPrint('Gagal memperbarui widget: $e'); // widget bukan fitur utama; jangan ganggu aplikasi
    }
  }

  /// Setelah logout: widget menampilkan ajakan masuk, bukan data akun sebelumnya.
  static Future<void> clear() async {
    if (!_supported) return;
    try {
      await HomeWidget.saveWidgetData<bool>('logged_in', false);
      await _redrawAll();
    } catch (e) {
      debugPrint('Gagal mengosongkan widget: $e');
    }
  }

  // ───────────── Tombol "+ Catat makan" di widget ─────────────

  /// `true` = ada permintaan "+ Catat makan" dari widget yang belum dibuka.
  /// HomeShell pindah ke tab Harian, lalu TodayScreen membuka form dan mengembalikannya ke `false`.
  static final pendingAdd = ValueNotifier<bool>(false);

  static bool _launchChecked = false;
  static StreamSubscription<Uri?>? _clicks;

  /// Mulai mendengarkan tombol widget (bulkin://add), baik saat aplikasi dibuka dari widget
  /// maupun saat aplikasi sudah berjalan di latar belakang. Aman dipanggil berulang.
  static void startListening() {
    if (!_supported) return;
    if (!_launchChecked) {
      _launchChecked = true; // intent pembuka hanya diproses sekali
      HomeWidget.initiallyLaunchedFromHomeWidget().then(_handle).catchError((_) {});
    }
    _clicks ??= HomeWidget.widgetClicked.listen(_handle);
  }

  static void _handle(Uri? uri) {
    if (uri?.scheme == 'bulkin' && uri?.host == 'add') pendingAdd.value = true;
  }
}
