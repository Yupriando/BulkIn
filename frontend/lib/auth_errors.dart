import 'package:supabase_flutter/supabase_flutter.dart';

/// Terjemahkan error Supabase Auth ke bahasa Indonesia.
String authErrorMessage(AuthException e) => switch (e.code) {
      'invalid_credentials' => 'Email atau password salah',
      'user_already_exists' || 'email_exists' => 'Email ini sudah terdaftar. Silakan masuk.',
      'weak_password' => 'Password terlalu lemah. Pakai minimal 8 karakter, campur huruf dan angka.',
      'email_not_confirmed' => 'Email belum dikonfirmasi. Cek kotak masuk email kamu.',
      'email_address_invalid' => 'Alamat email tidak valid',
      'signup_disabled' => 'Pendaftaran akun sedang ditutup',
      'over_request_rate_limit' || 'over_email_send_rate_limit' => 'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.',
      _ => e.message,
    };
