import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'models.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

String isoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Klien untuk backend BulkIn. Token login diambil dari sesi Supabase (diperbarui otomatis).
class Api {
  Api._();
  static final instance = Api._();

  final _http = http.Client();

  Future<dynamic> _send(String method, String path,
      {Map<String, dynamic>? body, Duration timeout = const Duration(seconds: 20)}) async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    final request = http.Request(method, Uri.parse('${AppConfig.apiBaseUrl}/api$path'))
      ..headers['Content-Type'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) request.body = jsonEncode(body);

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request).timeout(timeout));
    } catch (_) {
      throw ApiException('Tidak bisa terhubung ke server. Cek koneksi internet.');
    }

    if (response.statusCode == 204) return null;
    final dynamic data = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 400) {
      if (response.statusCode == 401) await Supabase.instance.client.auth.signOut();
      throw ApiException(data is Map && data['error'] != null ? data['error'] : 'Error ${response.statusCode}');
    }
    return data;
  }

  // Profil
  Future<Profile> getProfile() async => Profile.fromJson(await _send('GET', '/profile'));
  Future<Profile> updateProfile(Map<String, dynamic> body) async =>
      Profile.fromJson(await _send('PUT', '/profile', body: body));

  // Makanan
  Future<List<Food>> getFoods() async =>
      (await _send('GET', '/foods') as List).map((e) => Food.fromJson(e)).toList();
  Future<Food> createFood(Map<String, dynamic> body) async => Food.fromJson(await _send('POST', '/foods', body: body));
  Future<Food> updateFood(int id, Map<String, dynamic> body) async =>
      Food.fromJson(await _send('PUT', '/foods/$id', body: body));
  Future<void> deleteFood(int id) => _send('DELETE', '/foods/$id');

  /// Tanya AI kalori makanan. Belum disimpan; simpan dengan [createFood] setelah user setuju.
  Future<FoodEstimate> estimateFood(String name) async => FoodEstimate.fromJson(
      await _send('POST', '/foods/estimate', body: {'name': name}, timeout: const Duration(seconds: 60)));

  // Catatan makan
  Future<DaySummary> getDay(DateTime date) async => DaySummary.fromJson(await _send('GET', '/days/${isoDate(date)}'));
  Future<void> createEntry(Map<String, dynamic> body) => _send('POST', '/entries', body: body);
  Future<void> updateEntry(int id, Map<String, dynamic> body) => _send('PUT', '/entries/$id', body: body);
  Future<void> deleteEntry(int id) => _send('DELETE', '/entries/$id');

  // Berat badan
  Future<List<WeightLog>> getWeights() async =>
      (await _send('GET', '/weights') as List).map((e) => WeightLog.fromJson(e)).toList();
  Future<void> createWeight(Map<String, dynamic> body) => _send('POST', '/weights', body: body);
  Future<void> updateWeight(int id, Map<String, dynamic> body) => _send('PUT', '/weights/$id', body: body);
  Future<void> deleteWeight(int id) => _send('DELETE', '/weights/$id');

  // Statistik
  Future<EnergyEstimate> getEnergy() async => EnergyEstimate.fromJson(await _send('GET', '/energy'));

  Future<Stats> getStats({required int days}) async {
    final to = DateTime.now();
    final from = to.subtract(Duration(days: days - 1));
    return Stats.fromJson(await _send('GET', '/stats?from=${isoDate(from)}&to=${isoDate(to)}'));
  }
}
