# BulkIn 💪

Aplikasi Android untuk mencatat makanan, kalori, dan berat badan harian — dibuat untuk program **bulking** (naik berat badan).
Kamu cukup pilih makanan dan ketik beratnya (gram) atau jumlahnya (bungkus/porsi), kalori & protein dihitung otomatis.

```
frontend/  Aplikasi Flutter (Android)
backend/   API Node.js + Express → deploy ke Vercel
           Database: Supabase (Postgres + Auth)
```

## Fitur

- **Harian** — catat makanan per waktu makan (sarapan, siang, sore, malam, camilan), lihat progres kalori vs target 3.000 kkal, dan timbangan hari itu (bisa lebih dari sekali sehari, lengkap dengan jam & kondisi belum/sudah makan).
- **Progres** — grafik berat badan pagi & kalori harian (7/30/90 hari), tren kg/minggu, rata-rata kalori, dan saran singkat.
- **Makanan** — ±65 makanan bawaan (nasi, oatmeal, ayam tepung, Mie Gacoan, Pro Gainer, dst). Bisa tambah sendiri atau koreksi angkanya.
- **Tanya AI** — makanan belum ada di daftar? Ketik namanya (mis. "bubur ayam"), AI (Gemini, gratis) memperkirakan kalori & protein per 100 g, lalu tersimpan ke daftar. Kamu tinggal isi gram.
- **Kebutuhan kalori** — dihitung dari data kamu sendiri: rata-rata kalori yang dimakan dikurangi perubahan berat pagi × 7.700 kkal/kg (28 hari terakhir). Ada tombol untuk langsung menjadikannya target (naik 0,25 atau 0,5 kg/minggu).
- **Import catatan lama** — 50 hari catatan manual kamu bisa langsung dimasukkan.

---

## 1. Siapkan Supabase

1. Buat project di <https://supabase.com>.
2. Buka **SQL Editor → New query**, tempel isi [backend/supabase/schema.sql](backend/supabase/schema.sql), klik **Run**.
3. Buka **Project Settings → API**, catat:
   - Project URL
   - `anon` / publishable key
   - `service_role` / secret key (rahasia, hanya untuk script lokal)
4. (Opsional, biar praktis) **Authentication → Sign In / Providers → Email**: matikan *Confirm email* supaya bisa langsung login setelah daftar.

## 2. Jalankan backend di komputer

```bash
cd backend
npm install
cp .env.example .env      # lalu isi SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY, GEMINI_API_KEY
npm run seed              # isi daftar makanan bawaan
npm test                  # opsional
npm run dev               # API jalan di http://localhost:3000
```

## 3. Deploy backend ke Vercel

```bash
cd backend
npx vercel                # login & ikuti petunjuk (root directory: backend)
```

Di dashboard Vercel → project → **Settings → Environment Variables**, tambahkan:

| Nama | Nilai |
|---|---|
| `SUPABASE_URL` | Project URL |
| `SUPABASE_ANON_KEY` | anon / publishable key |
| `APP_TZ_OFFSET` | `+07:00` (WIB) |
| `GEMINI_API_KEY` | API key Gemini (gratis, dari <https://aistudio.google.com/apikey>), untuk fitur "Tanya AI" |

> **Jangan** masukkan `SUPABASE_SERVICE_ROLE_KEY` ke Vercel — API memakai token login user sehingga Row Level Security Supabase tetap melindungi data.

Lalu `npx vercel --prod`. Cek: buka `https://<nama-project>.vercel.app/api/health` → harus muncul `{"ok":true,"app":"BulkIn"}`.

Kalau project-nya di GitHub, bisa juga import repo di Vercel dan set **Root Directory = `backend`**.

## 4. Jalankan aplikasi Flutter

```bash
cd frontend
cp config.example.json config.json   # isi SUPABASE_URL, SUPABASE_ANON_KEY, API_BASE_URL (URL Vercel)
flutter run --dart-define-from-file=config.json
```

Build APK untuk dipasang di HP:

```bash
flutter build apk --release --dart-define-from-file=config.json
# hasil: frontend/build/app/outputs/flutter-apk/app-release.apk
```

> Untuk tes dengan backend lokal di emulator Android, pakai `"API_BASE_URL": "http://10.0.2.2:3000"`.

## 5. Import catatan manual lama

Daftar akun dulu lewat aplikasi, lalu:

```bash
cd backend
npm run import -- --email kamu@email.com          # pratinjau dulu
npm run import -- --email kamu@email.com --save   # simpan
```

Catatan disimpan di [backend/data/catatan-manual.txt](backend/data/catatan-manual.txt) (format sama seperti yang biasa kamu tulis).
Kalori yang kamu tulis sendiri di catatan diutamakan; sisanya dihitung dari daftar makanan.
Item yang tidak bisa dihitung (mis. "Ngemil", "Kerang dll") disimpan 0 kkal dan ditandai merah di aplikasi — tinggal diedit.

Hari yang sudah punya data akan dilewati, jadi aman dijalankan berulang.

---

## API

Dokumentasi interaktif (Swagger): buka `/docs`. Login lewat `POST /api/auth/login` di sana, token otomatis terpasang.
Cek kesehatan server: `/health` (koneksi Supabase + status AI).

Semua endpoint (kecuali `/health`, `/docs`, `/api/auth/login`) butuh header `Authorization: Bearer <access token Supabase>`.

| Method | Path | Keterangan |
|---|---|---|
| GET | `/api/health` | cek server |
| GET/PUT | `/api/profile` | target kalori, protein, berat |
| GET/POST | `/api/foods` | daftar / tambah makanan |
| POST | `/api/foods/estimate` | `{name}` → perkiraan kalori dari AI (belum disimpan) |
| PUT/DELETE | `/api/foods/:id` | edit (makanan bawaan → disalin jadi milik user) / hapus |
| GET | `/api/days/:date` | ringkasan satu hari |
| POST | `/api/entries` | `{eaten_on, meal_type, food_id, grams \| quantity}` atau `{…, food_name, kcal}` |
| PUT/DELETE | `/api/entries/:id` | edit / hapus catatan makan |
| GET/POST | `/api/weights` | riwayat / catat berat |
| PUT/DELETE | `/api/weights/:id` | edit / hapus berat |
| GET | `/api/stats?from=&to=` | total harian, berat pagi, tren mingguan |
| GET | `/api/energy?from=&to=` | perkiraan kebutuhan kalori (default 28 hari terakhir) |

Nilai kalori makanan bawaan sebagian diambil dari angka di catatanmu sendiri, sisanya estimasi umum — silakan koreksi di menu **Makanan**.
