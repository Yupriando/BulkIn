import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api.dart' show isoDate;

/// Satu perubahan (catatan makan, berat, profil) yang belum terkirim ke server.
class PendingOp {
  final int seq;
  final String method;
  final String path;
  Map<String, dynamic>? body;

  PendingOp({required this.seq, required this.method, required this.path, this.body});

  /// Id sementara untuk data yang dibuat offline. Negatif supaya tidak bentrok dengan id dari server.
  int get tempId => -seq;

  Map<String, dynamic> toJson() => {'seq': seq, 'method': method, 'path': path, 'body': body};

  factory PendingOp.fromJson(Map<String, dynamic> j) => PendingOp(
        seq: j['seq'],
        method: j['method'],
        path: j['path'],
        body: (j['body'] as Map?)?.cast<String, dynamic>(),
      );
}

/// Status sinkronisasi untuk ditampilkan di layar.
class SyncStatus {
  static final online = ValueNotifier<bool>(true);
  static final pending = ValueNotifier<int>(0);

  /// Pesan kalau ada perubahan offline yang ditolak server (mis. datanya sudah dihapus di HP lain).
  static final rejected = ValueNotifier<String?>(null);

  /// Bertambah setiap antrean selesai terkirim, supaya layar memuat ulang data dari server.
  static final synced = ValueNotifier<int>(0);
}

/// Penyimpanan di HP: salinan data terakhir dari server + antrean perubahan. Dipisah per akun.
class LocalStore {
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _p() async => _prefs ??= await SharedPreferences.getInstance();
  static String _key(String name) => 'offline:${Supabase.instance.client.auth.currentUser?.id ?? '-'}:$name';

  static Future<dynamic> read(String key) async {
    final s = (await _p()).getString(_key('cache:$key'));
    return s == null ? null : jsonDecode(s);
  }

  static Future<void> write(String key, dynamic data) async =>
      (await _p()).setString(_key('cache:$key'), jsonEncode(data));

  static Future<List<PendingOp>> pending() async {
    final s = (await _p()).getString(_key('outbox'));
    final ops = s == null ? <PendingOp>[] : (jsonDecode(s) as List).map((e) => PendingOp.fromJson(e)).toList();
    SyncStatus.pending.value = ops.length;
    return ops;
  }

  static Future<void> savePending(List<PendingOp> ops) async {
    await (await _p()).setString(_key('outbox'), jsonEncode(ops.map((o) => o.toJson()).toList()));
    SyncStatus.pending.value = ops.length;
  }

  static Future<PendingOp> enqueue(String method, String path, Map<String, dynamic>? body) async {
    final prefs = await _p();
    final seq = (prefs.getInt(_key('seq')) ?? 0) + 1;
    await prefs.setInt(_key('seq'), seq);
    final op = PendingOp(seq: seq, method: method, path: path, body: body);
    await savePending([...await pending(), op]);
    return op;
  }
}

// ─── Menerapkan antrean ke data salinan, supaya yang dicatat offline langsung terlihat ───

double _num(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);
double _round1(double v) => (v * 10).round() / 10;
int? _idOf(String path, String prefix) => path.startsWith(prefix) ? int.tryParse(path.substring(prefix.length)) : null;

/// Bentuk baris catatan makan seperti dari server. Kalori dihitung sama dengan backend (nutrition.js).
Map<String, dynamic> _entryFromBody(int id, Map<String, dynamic> body, List<dynamic> foods) {
  final entry = <String, dynamic>{
    'id': id,
    'eaten_on': body['eaten_on'],
    'meal_type': body['meal_type'],
    'food_id': body['food_id'],
    'food_name': body['food_name'] ?? '',
    'grams': body['grams'],
    'quantity': body['quantity'],
    'kcal': _num(body['kcal']),
    'protein': _num(body['protein']),
  };
  if (body['food_id'] == null) return entry;

  final food = foods.cast<Map>().where((f) => f['id'] == body['food_id']).firstOrNull;
  if (food == null) return entry;
  entry['food_name'] = food['name'];
  final grams = _num(body['grams']);
  final quantity = _num(body['quantity']);
  if (grams > 0 && food['kcal_per_100g'] != null) {
    entry['kcal'] = _round1(_num(food['kcal_per_100g']) * grams / 100);
    entry['protein'] = _round1(_num(food['protein_per_100g']) * grams / 100);
  } else if (quantity > 0 && food['kcal_per_unit'] != null) {
    entry['kcal'] = _round1(_num(food['kcal_per_unit']) * quantity);
    entry['protein'] = _round1(_num(food['protein_per_unit']) * quantity);
  }
  return entry;
}

/// Terapkan perubahan berat badan ke daftar berat (format GET /weights).
List<Map<String, dynamic>> _applyWeights(List<Map<String, dynamic>> weights, List<PendingOp> ops) {
  final list = [...weights];
  for (final op in ops) {
    if (op.method == 'POST' && op.path == '/weights') {
      list.add({...?op.body, 'id': op.tempId});
    } else if (_idOf(op.path, '/weights/') case final id?) {
      final i = list.indexWhere((w) => w['id'] == id);
      if (i < 0) continue;
      if (op.method == 'DELETE') {
        list.removeAt(i);
      } else {
        list[i] = {...list[i], ...?op.body};
      }
    }
  }
  return list;
}

/// Ringkasan harian kosong, untuk hari yang belum pernah dibuka saat online.
Map<String, dynamic> emptyDay(DateTime date, Map<String, dynamic>? profile) => {
      'date': isoDate(date),
      'target': {
        'kcal': profile?['daily_kcal_target'] ?? 3000,
        'protein': profile?['daily_protein_target'] ?? 120,
      },
      'totals': {'kcal': 0, 'protein': 0},
      'meals': <String, dynamic>{},
      'weights': <dynamic>[],
    };

/// Terapkan antrean ke ringkasan harian (format GET /days/:date).
Map<String, dynamic> applyPendingToDay(Map<String, dynamic> day, List<PendingOp> ops, List<dynamic> foods) {
  final date = day['date'] as String;
  var entries = [
    for (final list in (day['meals'] as Map).values)
      for (final e in list as List) Map<String, dynamic>.from(e),
  ];
  final target = Map<String, dynamic>.from(day['target']);

  for (final op in ops) {
    if (op.method == 'POST' && op.path == '/entries') {
      entries.add(_entryFromBody(op.tempId, op.body!, foods));
    } else if (_idOf(op.path, '/entries/') case final id?) {
      final i = entries.indexWhere((e) => e['id'] == id);
      if (op.method == 'DELETE') {
        if (i >= 0) entries.removeAt(i);
      } else if (i >= 0) {
        entries[i] = _entryFromBody(id, op.body!, foods); // tetap di urutan yang sama
      } else {
        entries.add(_entryFromBody(id, op.body!, foods)); // dipindah dari hari lain
      }
    } else if (op.path == '/profile') {
      if (op.body!['daily_kcal_target'] != null) target['kcal'] = op.body!['daily_kcal_target'];
      if (op.body!['daily_protein_target'] != null) target['protein'] = op.body!['daily_protein_target'];
    }
  }
  entries = entries.where((e) => e['eaten_on'] == date).toList();

  final weights = _applyWeights(
    [for (final w in day['weights'] as List) Map<String, dynamic>.from(w)],
    ops,
  ).where((w) => isoDate(DateTime.parse(w['measured_at']).toLocal()) == date).toList()
    ..sort((a, b) => (a['measured_at'] as String).compareTo(b['measured_at']));

  return {
    ...day,
    'target': target,
    'totals': {
      'kcal': _round1(entries.fold(0.0, (s, e) => s + _num(e['kcal']))),
      'protein': _round1(entries.fold(0.0, (s, e) => s + _num(e['protein']))),
    },
    'meals': {
      for (final type in entries.map((e) => e['meal_type']).toSet())
        type: entries.where((e) => e['meal_type'] == type).toList(),
    },
    'weights': weights,
  };
}

/// Terapkan antrean ke daftar berat badan (format GET /weights, terbaru dulu).
List<Map<String, dynamic>> applyPendingToWeights(List<dynamic> weights, List<PendingOp> ops) =>
    _applyWeights([for (final w in weights) Map<String, dynamic>.from(w)], ops)
      ..sort((a, b) => (b['measured_at'] as String).compareTo(a['measured_at']));

/// Terapkan antrean ke profil (format GET /profile).
Map<String, dynamic> applyPendingToProfile(Map<String, dynamic> profile, List<PendingOp> ops) => {
      ...profile,
      for (final op in ops)
        if (op.path == '/profile') ...?op.body,
    };
