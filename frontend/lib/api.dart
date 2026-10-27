import 'dart:convert';

import 'package:flutter/material.dart' show DateUtils;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'models.dart';
import 'offline.dart';

class ApiException implements Exception {
  final String message;
  final int? status;
  ApiException(this.message, {this.status});
  @override
  String toString() => message;
}

/// Server tidak bisa dihubungi (tidak ada internet / server mati).
class OfflineException extends ApiException {
  OfflineException() : super('Tidak ada internet. Fitur ini butuh koneksi.');
}

String isoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Klien untuk backend BulkIn. Token login diambil dari sesi Supabase (diperbarui otomatis).
///
/// Bisa dipakai offline: data yang dibaca disimpan di HP, dan catatan makan / berat / profil yang disimpan
/// saat offline masuk antrean ([LocalStore]) lalu dikirim otomatis saat internet kembali ([sync]).
class Api {
  Api._();
  static final instance = Api._();

  final _http = http.Client();

  Future<dynamic> _send(String method, String path,
      {Map<String, dynamic>? body, Duration timeout = const Duration(seconds: 20)}) async {
    final auth = Supabase.instance.client.auth;
    // Token bisa kedaluwarsa selama offline; perbarui dulu sebelum mengirim.
    if (auth.currentSession?.isExpired ?? false) {
      try {
        await auth.refreshSession();
      } catch (_) {}
    }
    final token = auth.currentSession?.accessToken;
    final request = http.Request(method, Uri.parse('${AppConfig.apiBaseUrl}/api$path'))
      ..headers['Content-Type'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) request.body = jsonEncode(body);

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request).timeout(timeout));
    } catch (_) {
      SyncStatus.online.value = false;
      throw OfflineException();
    }
    SyncStatus.online.value = true;

    if (response.statusCode == 204) return null;
    final dynamic data = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 400) {
      if (response.statusCode == 401) await auth.signOut();
      throw ApiException(
        data is Map && data['error'] != null ? data['error'] : 'Error ${response.statusCode}',
        status: response.statusCode,
      );
    }
    return data;
  }

  // ─── Offline ───

  Future<bool>? _syncing;

  /// Kirim antrean perubahan offline. Hasilnya true kalau antrean sudah kosong.
  Future<bool> sync() => _syncing ??= _flush().whenComplete(() => _syncing = null);

  Future<bool> _flush() async {
    var sent = false;
    try {
      while (true) {
        final ops = await LocalStore.pending();
        if (ops.isEmpty) return true;
        final op = ops.first;
        try {
          await _send(op.method, op.path, body: op.body);
        } on OfflineException {
          return false;
        } on ApiException catch (e) {
          // Belum login / server error: coba lagi nanti. Ditolak (4xx): buang supaya antrean tidak macet.
          if (e.status == null || e.status == 401 || e.status! >= 500) return false;
          SyncStatus.rejected.value = 'Perubahan offline ditolak server: ${e.message}';
        }
        sent = true;
        await LocalStore.savePending((await LocalStore.pending()).where((o) => o.seq != op.seq).toList());
      }
    } finally {
      if (sent) SyncStatus.synced.value++;
    }
  }

  /// Baca dari server dan simpan salinannya; kalau offline, pakai salinan terakhir (null kalau belum ada).
  Future<dynamic> _get(String path, {String? cacheKey}) async {
    final key = cacheKey ?? path;
    // Kirim antrean dulu supaya data dari server sudah termasuk perubahan offline.
    if (await sync()) {
      try {
        final data = await _send('GET', path, timeout: const Duration(seconds: 12));
        await LocalStore.write(key, data);
        return data;
      } on OfflineException {
        // pakai salinan
      }
    }
    return LocalStore.read(key);
  }

  /// Simpan perubahan ke server; kalau offline, masukkan antrean. Hasilnya null kalau masuk antrean.
  Future<dynamic> _write(String method, String path, {Map<String, dynamic>? body}) async {
    if (await sync()) {
      try {
        return await _send(method, path, body: body);
      } on OfflineException {
        // masuk antrean
      }
    }
    await LocalStore.enqueue(method, path, body);
    return null;
  }

  /// Ubah / hapus data yang dibuat offline (id negatif): cukup ubah antreannya.
  Future<void> _editPending(int tempId, Map<String, dynamic>? body) async {
    final ops = await LocalStore.pending();
    final i = ops.indexWhere((o) => o.tempId == tempId);
    if (i < 0) throw ApiException('Data ini baru saja tersinkron. Muat ulang lalu coba lagi.');
    if (body == null) {
      ops.removeAt(i);
    } else {
      ops[i].body = body;
    }
    await LocalStore.savePending(ops);
  }

  dynamic _orOffline(dynamic data) => data ?? (throw OfflineException());

  // Profil
  Future<Profile> getProfile() async {
    final data = Map<String, dynamic>.from(_orOffline(await _get('/profile')));
    return Profile.fromJson(applyPendingToProfile(data, await LocalStore.pending()));
  }

  Future<Profile> updateProfile(Map<String, dynamic> body) async {
    final saved = await _write('PUT', '/profile', body: body);
    if (saved != null) {
      await LocalStore.write('/profile', saved);
      return Profile.fromJson(saved);
    }
    final cached = Map<String, dynamic>.from(await LocalStore.read('/profile') ?? {});
    return Profile.fromJson(applyPendingToProfile(cached, await LocalStore.pending()));
  }

  // Makanan (tambah/edit/hapus butuh internet karena id makanan dibuat server)
  Future<List<Food>> getFoods() async =>
      (_orOffline(await _get('/foods')) as List).map((e) => Food.fromJson(e)).toList();
  Future<Food> createFood(Map<String, dynamic> body) async => Food.fromJson(await _send('POST', '/foods', body: body));
  Future<Food> updateFood(int id, Map<String, dynamic> body) async =>
      Food.fromJson(await _send('PUT', '/foods/$id', body: body));
  Future<void> deleteFood(int id) => _send('DELETE', '/foods/$id');

  /// Tanya AI kalori makanan. Belum disimpan; simpan dengan [createFood] setelah user setuju.
  Future<FoodEstimate> estimateFood(String name) async => FoodEstimate.fromJson(
      await _send('POST', '/foods/estimate', body: {'name': name}, timeout: const Duration(seconds: 60)));

  // Catatan makan
  Future<DaySummary> getDay(DateTime date) async {
    final data = await _get('/days/${isoDate(date)}');
    final day = data == null
        ? emptyDay(date, (await LocalStore.read('/profile') as Map?)?.cast<String, dynamic>())
        : Map<String, dynamic>.from(data);
    final foods = (await LocalStore.read('/foods') as List?) ?? const [];
    return DaySummary.fromJson(applyPendingToDay(day, await LocalStore.pending(), foods));
  }

  Future<void> createEntry(Map<String, dynamic> body) => _write('POST', '/entries', body: body);
  Future<void> updateEntry(int id, Map<String, dynamic> body) =>
      id < 0 ? _editPending(id, body) : _write('PUT', '/entries/$id', body: body);
  Future<void> deleteEntry(int id) => id < 0 ? _editPending(id, null) : _write('DELETE', '/entries/$id');

  // Berat badan
  Future<List<WeightLog>> getWeights() async {
    final data = _orOffline(await _get('/weights')) as List;
    return applyPendingToWeights(data, await LocalStore.pending()).map((e) => WeightLog.fromJson(e)).toList();
  }

  Future<void> createWeight(Map<String, dynamic> body) => _write('POST', '/weights', body: body);
  Future<void> updateWeight(int id, Map<String, dynamic> body) =>
      id < 0 ? _editPending(id, body) : _write('PUT', '/weights/$id', body: body);
  Future<void> deleteWeight(int id) => id < 0 ? _editPending(id, null) : _write('DELETE', '/weights/$id');

  // Statistik (saat offline memakai salinan terakhir, belum termasuk catatan yang masih di antrean)
  Future<EnergyEstimate> getEnergy() async => EnergyEstimate.fromJson(_orOffline(await _get('/energy')));

  Future<Stats> getStats({required int days}) async {
    final to = DateTime.now();
    final from = to.subtract(Duration(days: days - 1));
    final path = '/stats?from=${isoDate(from)}&to=${isoDate(to)}';
    return Stats.fromJson(_orOffline(await _get(path, cacheKey: '/stats/$days')));
  }

  /// Kalori per hari selama satu bulan (untuk kalender), sampai hari ini.
  Future<Stats> getMonth(DateTime month) async {
    final from = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1, 0);
    final today = DateUtils.dateOnly(DateTime.now());
    final to = end.isAfter(today) ? today : end;
    final path = '/stats?from=${isoDate(from)}&to=${isoDate(to)}';
    return Stats.fromJson(_orOffline(await _get(path, cacheKey: '/stats/month/${isoDate(from)}')));
  }
}
