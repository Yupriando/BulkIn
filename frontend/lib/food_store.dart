import 'api.dart';
import 'models.dart';

/// Cache daftar makanan supaya form tambah makan langsung terbuka tanpa loading.
class FoodStore {
  static List<Food>? _foods;

  static Future<List<Food>> load({bool force = false}) async {
    if (_foods == null || force) _foods = await Api.instance.getFoods();
    return _foods!;
  }

  static void invalidate() => _foods = null;
}
