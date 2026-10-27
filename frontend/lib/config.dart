/// Nilai diisi saat build lewat `--dart-define-from-file=config.json` (lihat config.example.json).
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// URL backend di Vercel, tanpa garis miring di akhir. Contoh: https://bulkin-api.vercel.app
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static bool get isComplete =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty && apiBaseUrl.isNotEmpty;
}
