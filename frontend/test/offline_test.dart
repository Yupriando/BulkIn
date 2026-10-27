import 'package:flutter_test/flutter_test.dart';
import 'package:naikin/models.dart';
import 'package:naikin/offline.dart';

void main() {
  final foods = [
    {'id': 1, 'name': 'Nasi putih', 'kcal_per_100g': 130, 'protein_per_100g': 2.7},
    {'id': 2, 'name': 'Telur rebus', 'unit_name': 'butir', 'kcal_per_unit': 78, 'protein_per_unit': 6.3},
  ];
  final day = {
    'date': '2026-10-27',
    'target': {'kcal': 3000, 'protein': 120},
    'totals': {'kcal': 260, 'protein': 5.4},
    'meals': {
      'sarapan': [
        {'id': 10, 'eaten_on': '2026-10-27', 'meal_type': 'sarapan', 'food_id': 1, 'food_name': 'Nasi putih', 'grams': 200, 'kcal': 260, 'protein': 5.4},
      ],
    },
    'weights': [],
  };
  PendingOp op(int seq, String method, String path, [Map<String, dynamic>? body]) =>
      PendingOp(seq: seq, method: method, path: path, body: body);

  test('catatan offline dihitung kalorinya dan masuk total', () {
    final result = DaySummary.fromJson(applyPendingToDay(day, [
      op(1, 'POST', '/entries', {'eaten_on': '2026-10-27', 'meal_type': 'siang', 'food_id': 2, 'quantity': 2}),
      op(2, 'POST', '/entries', {'eaten_on': '2026-10-27', 'meal_type': 'malam', 'food_name': 'Bakso', 'kcal': 400, 'protein': 20}),
      op(3, 'POST', '/entries', {'eaten_on': '2026-10-28', 'meal_type': 'siang', 'food_id': 1, 'grams': 100}),
    ], foods));

    expect(result.meals['siang']!.single.foodName, 'Telur rebus');
    expect(result.meals['siang']!.single.kcal, 156);
    expect(result.meals['siang']!.single.isPending, isTrue);
    expect(result.meals['malam']!.single.kcal, 400);
    expect(result.totalKcal, 260 + 156 + 400); // catatan tanggal 28 tidak ikut
    expect(result.totalProtein, closeTo(5.4 + 12.6 + 20, 0.01));
  });

  test('edit & hapus catatan server saat offline', () {
    final edited = DaySummary.fromJson(applyPendingToDay(day, [
      op(1, 'PUT', '/entries/10', {'eaten_on': '2026-10-27', 'meal_type': 'sarapan', 'food_id': 1, 'grams': 100}),
    ], foods));
    expect(edited.meals['sarapan']!.single.kcal, 130);
    expect(edited.meals['sarapan']!.single.id, 10);

    final deleted = DaySummary.fromJson(applyPendingToDay(day, [op(1, 'DELETE', '/entries/10')], foods));
    expect(deleted.meals['sarapan'], isEmpty);
    expect(deleted.totalKcal, 0);
  });

  test('hari yang belum pernah dibuka + berat & target offline', () {
    final empty = emptyDay(DateTime(2026, 10, 29), {'daily_kcal_target': 2800, 'daily_protein_target': 110});
    final measured = DateTime(2026, 10, 29, 7, 30).toUtc().toIso8601String();
    final result = DaySummary.fromJson(applyPendingToDay(empty, [
      op(1, 'POST', '/weights', {'weight_kg': 67.2, 'measured_at': measured, 'condition': 'belum_makan'}),
      op(2, 'PUT', '/profile', {'daily_kcal_target': 3100}),
    ], foods));
    expect(result.weights.single.weightKg, 67.2);
    expect(result.weights.single.id, -1);
    expect(result.kcalTarget, 3100);
    expect(result.proteinTarget, 110);
  });

  test('daftar berat & profil ikut antrean', () {
    final weights = applyPendingToWeights([
      {'id': 5, 'weight_kg': 66, 'measured_at': '2026-10-26T00:00:00Z'},
      {'id': 4, 'weight_kg': 65.8, 'measured_at': '2026-10-25T00:00:00Z'},
    ], [
      op(1, 'POST', '/weights', {'weight_kg': 66.4, 'measured_at': '2026-10-27T00:00:00Z'}),
      op(2, 'DELETE', '/weights/4'),
      op(3, 'PUT', '/weights/5', {'weight_kg': 66.1, 'measured_at': '2026-10-26T00:00:00Z'}),
    ]);
    expect(weights.map((w) => w['weight_kg']), [66.4, 66.1]);

    final profile = applyPendingToProfile({'display_name': 'Yupri', 'daily_kcal_target': 3000}, [
      op(1, 'PUT', '/profile', {'daily_kcal_target': 3200}),
    ]);
    expect(profile, {'display_name': 'Yupri', 'daily_kcal_target': 3200});
  });
}
