import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final _kcal = NumberFormat.decimalPattern('id_ID');
final _decimal = NumberFormat('#,##0.#', 'id_ID');

String fmtKcal(num v) => '${_kcal.format(v.round())} kkal';
String fmtNum(num v) => _decimal.format(v);
String fmtKg(num v) => '${NumberFormat('0.0#', 'id_ID').format(v)} kg';

/// Parse angka yang diketik user, terima koma atau titik sebagai desimal.
double? parseNum(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

void showMessage(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
}
