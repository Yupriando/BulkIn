double? _toDouble(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

const mealTypes = ['sarapan', 'siang', 'sore', 'malam', 'camilan'];

const mealLabels = {
  'sarapan': 'Sarapan',
  'siang': 'Makan Siang',
  'sore': 'Sore',
  'malam': 'Makan Malam',
  'camilan': 'Camilan',
};

const conditionLabels = {
  'belum_makan': 'Belum makan',
  'sedang_makan': 'Sedang makan',
  'sudah_makan': 'Sudah makan',
};

class Profile {
  final String? displayName;
  final int dailyKcalTarget;
  final int dailyProteinTarget;
  final double? targetWeightKg;

  Profile({this.displayName, required this.dailyKcalTarget, required this.dailyProteinTarget, this.targetWeightKg});

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        displayName: j['display_name'],
        dailyKcalTarget: (j['daily_kcal_target'] as num?)?.toInt() ?? 3000,
        dailyProteinTarget: (j['daily_protein_target'] as num?)?.toInt() ?? 120,
        targetWeightKg: _toDouble(j['target_weight_kg']),
      );
}

class Food {
  final int id;
  final String name;
  final bool isBuiltIn;
  final double? kcalPer100g;
  final double? proteinPer100g;
  final String? unitName;
  final double? kcalPerUnit;
  final double? proteinPerUnit;

  Food({
    required this.id,
    required this.name,
    required this.isBuiltIn,
    this.kcalPer100g,
    this.proteinPer100g,
    this.unitName,
    this.kcalPerUnit,
    this.proteinPerUnit,
  });

  factory Food.fromJson(Map<String, dynamic> j) => Food(
        id: j['id'],
        name: j['name'],
        isBuiltIn: j['user_id'] == null,
        kcalPer100g: _toDouble(j['kcal_per_100g']),
        proteinPer100g: _toDouble(j['protein_per_100g']),
        unitName: j['unit_name'],
        kcalPerUnit: _toDouble(j['kcal_per_unit']),
        proteinPerUnit: _toDouble(j['protein_per_unit']),
      );

  bool get hasPer100g => kcalPer100g != null;
  bool get hasUnit => kcalPerUnit != null && unitName != null;

  /// Sama dengan perhitungan di backend — hanya untuk pratinjau di layar.
  double? previewKcal({double? grams, double? quantity}) {
    if (grams != null && grams > 0 && hasPer100g) return kcalPer100g! * grams / 100;
    if (quantity != null && quantity > 0 && hasUnit) return kcalPerUnit! * quantity;
    return null;
  }

  String get description {
    final parts = <String>[];
    if (hasPer100g) parts.add('${kcalPer100g!.round()} kkal/100 g');
    if (hasUnit) parts.add('${kcalPerUnit!.round()} kkal/$unitName');
    return parts.join(' · ');
  }
}

class MealEntry {
  final int id;
  final String eatenOn;
  final String mealType;
  final int? foodId;
  final String foodName;
  final double? grams;
  final double? quantity;
  final double kcal;
  final double protein;

  MealEntry({
    required this.id,
    required this.eatenOn,
    required this.mealType,
    this.foodId,
    required this.foodName,
    this.grams,
    this.quantity,
    required this.kcal,
    required this.protein,
  });

  factory MealEntry.fromJson(Map<String, dynamic> j) => MealEntry(
        id: j['id'],
        eatenOn: j['eaten_on'],
        mealType: j['meal_type'],
        foodId: j['food_id'],
        foodName: j['food_name'],
        grams: _toDouble(j['grams']),
        quantity: _toDouble(j['quantity']),
        kcal: _toDouble(j['kcal']) ?? 0,
        protein: _toDouble(j['protein']) ?? 0,
      );

  /// Dicatat saat offline dan belum terkirim ke server.
  bool get isPending => id < 0;
}

class WeightLog {
  final int id;
  final double weightKg;
  final DateTime measuredAt;
  final String? condition;
  final String? note;

  WeightLog({required this.id, required this.weightKg, required this.measuredAt, this.condition, this.note});

  factory WeightLog.fromJson(Map<String, dynamic> j) => WeightLog(
        id: j['id'],
        weightKg: _toDouble(j['weight_kg'])!,
        measuredAt: DateTime.parse(j['measured_at']).toLocal(),
        condition: j['condition'],
        note: j['note'],
      );
}

class DaySummary {
  final String date;
  final int kcalTarget;
  final int proteinTarget;
  final double totalKcal;
  final double totalProtein;
  final Map<String, List<MealEntry>> meals;
  final List<WeightLog> weights;

  DaySummary({
    required this.date,
    required this.kcalTarget,
    required this.proteinTarget,
    required this.totalKcal,
    required this.totalProtein,
    required this.meals,
    required this.weights,
  });

  factory DaySummary.fromJson(Map<String, dynamic> j) => DaySummary(
        date: j['date'],
        kcalTarget: (j['target']['kcal'] as num).toInt(),
        proteinTarget: (j['target']['protein'] as num).toInt(),
        totalKcal: _toDouble(j['totals']['kcal']) ?? 0,
        totalProtein: _toDouble(j['totals']['protein']) ?? 0,
        meals: {
          for (final type in mealTypes)
            type: ((j['meals'][type] as List?) ?? []).map((e) => MealEntry.fromJson(e)).toList(),
        },
        weights: (j['weights'] as List).map((e) => WeightLog.fromJson(e)).toList(),
      );
}

class StatsDay {
  final DateTime date;
  final double kcal;
  final double protein;
  final bool logged;
  final double? weightKg;

  StatsDay({required this.date, required this.kcal, required this.protein, required this.logged, this.weightKg});

  factory StatsDay.fromJson(Map<String, dynamic> j) => StatsDay(
        date: DateTime.parse(j['date']),
        kcal: _toDouble(j['kcal']) ?? 0,
        protein: _toDouble(j['protein']) ?? 0,
        logged: j['logged'] == true,
        weightKg: _toDouble(j['weight_kg']),
      );
}

class Stats {
  final int kcalTarget;
  final double? targetWeightKg;
  final List<StatsDay> days;
  final int daysLogged;
  final int? avgKcal;
  final int? avgProtein;
  final int daysOnTarget;
  final double? weightStart;
  final double? weightEnd;
  final double? weeklyChangeKg;

  Stats({
    required this.kcalTarget,
    this.targetWeightKg,
    required this.days,
    required this.daysLogged,
    this.avgKcal,
    this.avgProtein,
    required this.daysOnTarget,
    this.weightStart,
    this.weightEnd,
    this.weeklyChangeKg,
  });

  factory Stats.fromJson(Map<String, dynamic> j) {
    final s = j['summary'];
    return Stats(
      kcalTarget: (j['target']['kcal'] as num).toInt(),
      targetWeightKg: _toDouble(j['target']['weight_kg']),
      days: (j['days'] as List).map((e) => StatsDay.fromJson(e)).toList(),
      daysLogged: s['days_logged'],
      avgKcal: s['avg_kcal'],
      avgProtein: s['avg_protein'],
      daysOnTarget: s['days_on_target'],
      weightStart: _toDouble(s['weight_start']),
      weightEnd: _toDouble(s['weight_end']),
      weeklyChangeKg: _toDouble(s['weekly_change_kg']),
    );
  }
}

/// Hasil tebakan AI untuk satu makanan (belum tersimpan di daftar makanan).
class FoodEstimate {
  final String name;
  final double? kcalPer100g;
  final double? proteinPer100g;
  final String? unitName;
  final double? kcalPerUnit;
  final double? proteinPerUnit;
  final String assumption;

  FoodEstimate({
    required this.name,
    this.kcalPer100g,
    this.proteinPer100g,
    this.unitName,
    this.kcalPerUnit,
    this.proteinPerUnit,
    required this.assumption,
  });

  factory FoodEstimate.fromJson(Map<String, dynamic> j) => FoodEstimate(
        name: j['name'],
        kcalPer100g: _toDouble(j['kcal_per_100g']),
        proteinPer100g: _toDouble(j['protein_per_100g']),
        unitName: j['unit_name'],
        kcalPerUnit: _toDouble(j['kcal_per_unit']),
        proteinPerUnit: _toDouble(j['protein_per_unit']),
        assumption: j['assumption'] ?? '',
      );

  Map<String, dynamic> toFoodBody() => {
        'name': name,
        'kcal_per_100g': kcalPer100g,
        'protein_per_100g': proteinPer100g,
        'unit_name': unitName,
        'kcal_per_unit': kcalPerUnit,
        'protein_per_unit': proteinPerUnit,
      };
}

class EnergyTarget {
  final double weeklyGainKg;
  final int kcal;
  EnergyTarget(this.weeklyGainKg, this.kcal);
}

/// Perkiraan kebutuhan kalori dari catatan makan + timbangan pagi.
class EnergyEstimate {
  final bool ok;
  final String? reason;
  final int windowDays;
  final int daysLogged;
  final int weighIns;
  final int? avgIntakeKcal;
  final double? weeklyChangeKg;
  final int? tdeeKcal;
  final List<EnergyTarget> targets;
  final String? confidence;

  EnergyEstimate({
    required this.ok,
    this.reason,
    required this.windowDays,
    required this.daysLogged,
    required this.weighIns,
    this.avgIntakeKcal,
    this.weeklyChangeKg,
    this.tdeeKcal,
    required this.targets,
    this.confidence,
  });

  factory EnergyEstimate.fromJson(Map<String, dynamic> j) => EnergyEstimate(
        ok: j['ok'] == true,
        reason: j['reason'],
        windowDays: j['window_days'],
        daysLogged: j['days_logged'],
        weighIns: j['weigh_ins'],
        avgIntakeKcal: (j['avg_intake_kcal'] as num?)?.toInt(),
        weeklyChangeKg: _toDouble(j['weekly_change_kg']),
        tdeeKcal: (j['tdee_kcal'] as num?)?.toInt(),
        targets: ((j['targets'] as List?) ?? [])
            .map((t) => EnergyTarget(_toDouble(t['weekly_gain_kg'])!, (t['kcal'] as num).toInt()))
            .toList(),
        confidence: j['confidence'],
      );
}
