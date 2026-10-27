// Spesifikasi OpenAPI untuk Swagger UI (/docs).

const id = { name: 'id', in: 'path', required: true, schema: { type: 'integer' } };
const dateParam = (name, description) => ({ name, in: 'query', required: false, description, schema: { type: 'string', format: 'date' } });
const json = (schema) => ({ content: { 'application/json': { schema } } });
const ref = (name) => ({ $ref: `#/components/schemas/${name}` });
const ok = (description, schema) => ({ description, ...(schema ? json(schema) : {}) });

const errors = {
  400: ok('Input tidak valid', ref('Error')),
  401: ok('Belum login / token tidak valid', ref('Error')),
};

export const openapiSpec = {
  openapi: '3.0.3',
  info: {
    title: 'NaikIn API',
    version: '1.0.0',
    description:
      'Backend pencatat kalori & berat badan.\n\n' +
      '**Cara coba endpoint yang butuh login:** buka `POST /api/auth/login`, isi email & password akun aplikasi, klik Execute. ' +
      'Token otomatis dipasang — semua endpoint lain langsung bisa dicoba.',
  },
  tags: [
    { name: 'Sistem' },
    { name: 'Auth' },
    { name: 'Profil' },
    { name: 'Makanan' },
    { name: 'Catatan makan' },
    { name: 'Berat badan' },
    { name: 'Statistik' },
  ],
  components: {
    securitySchemes: { bearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' } },
    schemas: {
      Error: { type: 'object', properties: { error: { type: 'string' } } },
      Health: {
        type: 'object',
        properties: {
          ok: { type: 'boolean' },
          app: { type: 'string', example: 'NaikIn' },
          version: { type: 'string' },
          time: { type: 'string', format: 'date-time' },
          checks: {
            type: 'object',
            properties: {
              env: { type: 'object', properties: { ok: { type: 'boolean' }, missing: { type: 'array', items: { type: 'string' } } } },
              database: { type: 'object', properties: { ok: { type: 'boolean' }, latency_ms: { type: 'integer' }, error: { type: 'string' } } },
              ai: { type: 'object', properties: { configured: { type: 'boolean' }, model: { type: 'string' } } },
            },
          },
        },
      },
      Profile: {
        type: 'object',
        properties: {
          display_name: { type: 'string', nullable: true },
          daily_kcal_target: { type: 'integer', example: 3000 },
          daily_protein_target: { type: 'integer', example: 120 },
          target_weight_kg: { type: 'number', nullable: true, example: 70 },
        },
      },
      FoodInput: {
        type: 'object',
        required: ['name'],
        properties: {
          name: { type: 'string', example: 'Bubur ayam' },
          kcal_per_100g: { type: 'number', nullable: true, example: 70 },
          protein_per_100g: { type: 'number', nullable: true, example: 3.5 },
          unit_name: { type: 'string', nullable: true, example: 'porsi' },
          kcal_per_unit: { type: 'number', nullable: true, example: 350 },
          protein_per_unit: { type: 'number', nullable: true, example: 15 },
        },
      },
      Food: {
        allOf: [
          { type: 'object', properties: { id: { type: 'integer' }, user_id: { type: 'string', nullable: true, description: 'null = makanan bawaan' } } },
          ref('FoodInput'),
        ],
      },
      FoodEstimate: {
        allOf: [ref('FoodInput'), { type: 'object', properties: { assumption: { type: 'string' } } }],
      },
      EntryInput: {
        type: 'object',
        required: ['eaten_on', 'meal_type'],
        description: 'Isi `food_id` + `grams`/`quantity`, ATAU `food_name` + `kcal` untuk input manual.',
        properties: {
          eaten_on: { type: 'string', format: 'date', example: '2026-10-27' },
          meal_type: { type: 'string', enum: ['sarapan', 'siang', 'sore', 'malam', 'camilan'] },
          food_id: { type: 'integer', nullable: true, example: 1 },
          grams: { type: 'number', nullable: true, example: 400 },
          quantity: { type: 'number', nullable: true },
          food_name: { type: 'string' },
          kcal: { type: 'number', nullable: true },
          protein: { type: 'number', nullable: true },
        },
      },
      Entry: {
        type: 'object',
        properties: {
          id: { type: 'integer' },
          eaten_on: { type: 'string', format: 'date' },
          meal_type: { type: 'string' },
          food_id: { type: 'integer', nullable: true },
          food_name: { type: 'string' },
          grams: { type: 'number', nullable: true },
          quantity: { type: 'number', nullable: true },
          kcal: { type: 'number' },
          protein: { type: 'number' },
        },
      },
      WeightInput: {
        type: 'object',
        required: ['weight_kg'],
        properties: {
          weight_kg: { type: 'number', example: 66.2 },
          measured_at: { type: 'string', format: 'date-time', example: '2026-10-27T00:30:00Z' },
          condition: { type: 'string', nullable: true, enum: ['belum_makan', 'sedang_makan', 'sudah_makan'] },
          note: { type: 'string', nullable: true },
        },
      },
      Weight: { allOf: [{ type: 'object', properties: { id: { type: 'integer' } } }, ref('WeightInput')] },
    },
  },
  paths: {
    '/health': {
      get: {
        tags: ['Sistem'],
        summary: 'Cek server, koneksi database & AI',
        responses: { 200: ok('Semua sehat', ref('Health')), 503: ok('Ada yang bermasalah', ref('Health')) },
      },
    },
    '/api/auth/login': {
      post: {
        tags: ['Auth'],
        summary: 'Login (untuk mencoba API di Swagger)',
        description: 'Pakai email & password akun aplikasi. Token otomatis dipasang ke tombol Authorize.',
        requestBody: json({
          type: 'object',
          required: ['email', 'password'],
          properties: { email: { type: 'string', format: 'email' }, password: { type: 'string', format: 'password' } },
        }),
        responses: {
          200: ok('Berhasil', { type: 'object', properties: { access_token: { type: 'string' }, expires_at: { type: 'integer' } } }),
          401: ok('Email/password salah', ref('Error')),
        },
      },
    },
    '/api/profile': {
      get: { tags: ['Profil'], summary: 'Ambil profil & target', security: [{ bearerAuth: [] }], responses: { 200: ok('OK', ref('Profile')), ...errors } },
      put: {
        tags: ['Profil'],
        summary: 'Ubah profil & target',
        security: [{ bearerAuth: [] }],
        requestBody: json(ref('Profile')),
        responses: { 200: ok('OK', ref('Profile')), ...errors },
      },
    },
    '/api/foods': {
      get: { tags: ['Makanan'], summary: 'Daftar makanan', security: [{ bearerAuth: [] }], responses: { 200: ok('OK', { type: 'array', items: ref('Food') }), ...errors } },
      post: {
        tags: ['Makanan'],
        summary: 'Tambah makanan sendiri',
        security: [{ bearerAuth: [] }],
        requestBody: json(ref('FoodInput')),
        responses: { 201: ok('Dibuat', ref('Food')), 409: ok('Nama sudah ada', ref('Error')), ...errors },
      },
    },
    '/api/foods/estimate': {
      post: {
        tags: ['Makanan'],
        summary: 'Tanya AI kalori sebuah makanan',
        description: 'Hasil belum disimpan. Simpan dengan `POST /api/foods`.',
        security: [{ bearerAuth: [] }],
        requestBody: json({ type: 'object', required: ['name'], properties: { name: { type: 'string', example: 'bubur ayam' } } }),
        responses: {
          200: ok('Perkiraan AI', ref('FoodEstimate')),
          422: ok('AI tidak bisa memperkirakan', ref('Error')),
          503: ok('AI belum diaktifkan', ref('Error')),
          ...errors,
        },
      },
    },
    '/api/foods/{id}': {
      put: {
        tags: ['Makanan'],
        summary: 'Edit makanan (bawaan → disalin jadi milikmu)',
        security: [{ bearerAuth: [] }],
        parameters: [id],
        requestBody: json(ref('FoodInput')),
        responses: { 200: ok('OK', ref('Food')), 404: ok('Tidak ditemukan', ref('Error')), ...errors },
      },
      delete: {
        tags: ['Makanan'],
        summary: 'Hapus makanan milikmu',
        security: [{ bearerAuth: [] }],
        parameters: [id],
        responses: { 204: ok('Terhapus'), 403: ok('Makanan bawaan tidak bisa dihapus', ref('Error')), ...errors },
      },
    },
    '/api/days/{date}': {
      get: {
        tags: ['Catatan makan'],
        summary: 'Ringkasan satu hari',
        security: [{ bearerAuth: [] }],
        parameters: [{ name: 'date', in: 'path', required: true, schema: { type: 'string', format: 'date', example: '2026-10-27' } }],
        responses: {
          200: ok('OK', {
            type: 'object',
            properties: {
              date: { type: 'string', format: 'date' },
              target: { type: 'object', properties: { kcal: { type: 'integer' }, protein: { type: 'integer' } } },
              totals: { type: 'object', properties: { kcal: { type: 'number' }, protein: { type: 'number' } } },
              meals: { type: 'object', additionalProperties: { type: 'array', items: ref('Entry') } },
              weights: { type: 'array', items: ref('Weight') },
            },
          }),
          ...errors,
        },
      },
    },
    '/api/entries': {
      post: {
        tags: ['Catatan makan'],
        summary: 'Catat makanan (kalori dihitung otomatis)',
        security: [{ bearerAuth: [] }],
        requestBody: json(ref('EntryInput')),
        responses: { 201: ok('Dibuat', ref('Entry')), ...errors },
      },
    },
    '/api/entries/{id}': {
      put: {
        tags: ['Catatan makan'],
        summary: 'Edit catatan makan',
        security: [{ bearerAuth: [] }],
        parameters: [id],
        requestBody: json(ref('EntryInput')),
        responses: { 200: ok('OK', ref('Entry')), 404: ok('Tidak ditemukan', ref('Error')), ...errors },
      },
      delete: { tags: ['Catatan makan'], summary: 'Hapus catatan makan', security: [{ bearerAuth: [] }], parameters: [id], responses: { 204: ok('Terhapus'), ...errors } },
    },
    '/api/weights': {
      get: {
        tags: ['Berat badan'],
        summary: 'Riwayat berat (terbaru dulu)',
        security: [{ bearerAuth: [] }],
        parameters: [dateParam('from', 'default: 365 hari lalu'), dateParam('to', 'default: hari ini')],
        responses: { 200: ok('OK', { type: 'array', items: ref('Weight') }), ...errors },
      },
      post: {
        tags: ['Berat badan'],
        summary: 'Catat berat badan',
        security: [{ bearerAuth: [] }],
        requestBody: json(ref('WeightInput')),
        responses: { 201: ok('Dibuat', ref('Weight')), ...errors },
      },
    },
    '/api/weights/{id}': {
      put: {
        tags: ['Berat badan'],
        summary: 'Edit berat badan',
        security: [{ bearerAuth: [] }],
        parameters: [id],
        requestBody: json(ref('WeightInput')),
        responses: { 200: ok('OK', ref('Weight')), 404: ok('Tidak ditemukan', ref('Error')), ...errors },
      },
      delete: { tags: ['Berat badan'], summary: 'Hapus berat badan', security: [{ bearerAuth: [] }], parameters: [id], responses: { 204: ok('Terhapus'), ...errors } },
    },
    '/api/stats': {
      get: {
        tags: ['Statistik'],
        summary: 'Total harian, berat pagi, tren mingguan',
        security: [{ bearerAuth: [] }],
        parameters: [dateParam('from', 'default: 30 hari lalu'), dateParam('to', 'default: hari ini')],
        responses: { 200: ok('OK', { type: 'object' }), ...errors },
      },
    },
    '/api/energy': {
      get: {
        tags: ['Statistik'],
        summary: 'Perkiraan kebutuhan kalori harian',
        description: 'Rata-rata kalori dimakan − perubahan berat pagi × 7.700 kkal/kg.',
        security: [{ bearerAuth: [] }],
        parameters: [dateParam('from', 'default: 28 hari lalu'), dateParam('to', 'default: hari ini')],
        responses: {
          200: ok('OK', {
            type: 'object',
            properties: {
              ok: { type: 'boolean' },
              reason: { type: 'string' },
              avg_intake_kcal: { type: 'integer' },
              weekly_change_kg: { type: 'number' },
              tdee_kcal: { type: 'integer' },
              targets: { type: 'array', items: { type: 'object', properties: { weekly_gain_kg: { type: 'number' }, kcal: { type: 'integer' } } } },
              confidence: { type: 'string', enum: ['rendah', 'sedang', 'tinggi'] },
            },
          }),
          ...errors,
        },
      },
    },
  },
};

// Halaman Swagger UI. Aset dimuat dari CDN supaya tidak bermasalah di serverless Vercel.
// Setelah login sukses, token otomatis dipasang ke tombol Authorize.
export const swaggerHtml = `<!doctype html>
<html lang="id">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>NaikIn API Docs</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.17.14/swagger-ui.css" />
</head>
<body>
  <div id="swagger-ui"></div>
  <script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.17.14/swagger-ui-bundle.js"></script>
  <script>
    const ui = SwaggerUIBundle({
      url: '/api/openapi.json',
      dom_id: '#swagger-ui',
      persistAuthorization: true,
      tryItOutEnabled: true,
      responseInterceptor: (res) => {
        if (res.url.endsWith('/api/auth/login') && res.ok && res.body && res.body.access_token) {
          ui.preauthorizeApiKey('bearerAuth', res.body.access_token);
        }
        return res;
      },
    });
  </script>
</body>
</html>`;
