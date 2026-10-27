import express from 'express';
import { z } from 'zod';
import { clientForToken } from './supabase.js';
import { computeNutrition, sumNutrition, linearSlope } from './nutrition.js';
import { today, addDays, daysBetween, localDate, dayStart, dayEnd } from './dates.js';
import { estimateFood, isAiConfigured, AiEstimateError } from './aiNutrition.js';
import { estimateEnergy } from './energy.js';

export const MEAL_TYPES = ['sarapan', 'siang', 'sore', 'malam', 'camilan'];

const isoDate = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'format tanggal harus YYYY-MM-DD');
const positive = z.coerce.number().positive();

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

function check(result) {
  if (result.error) throw result.error;
  return result.data;
}

/** Ambil semua baris (Supabase membatasi 1000 baris per request). */
async function fetchAll(buildQuery) {
  const rows = [];
  for (let from = 0; ; from += 1000) {
    const page = check(await buildQuery().range(from, from + 999));
    rows.push(...page);
    if (page.length < 1000) return rows;
  }
}

/** Dari beberapa timbangan dalam sehari, pilih yang paling mewakili: timbangan pagi sebelum makan. */
function representativeWeight(weights) {
  if (!weights.length) return null;
  const sorted = [...weights].sort((a, b) => new Date(a.measured_at) - new Date(b.measured_at));
  return sorted.find((w) => w.condition === 'belum_makan') ?? sorted[0];
}

async function requireAuth(req, _res, next) {
  const token = /^Bearer (.+)$/.exec(req.headers.authorization || '')?.[1];
  if (!token) throw new HttpError(401, 'Belum login');
  const db = clientForToken(token);
  const { data, error } = await db.auth.getUser(token);
  if (error || !data?.user) throw new HttpError(401, 'Sesi login tidak valid, silakan login ulang');
  req.user = data.user;
  req.db = db;
  next();
}

export const app = express();
app.use(express.json());

app.get('/api/health', (_req, res) => res.json({ ok: true, app: 'NaikIn' }));

const api = express.Router();
api.use(requireAuth);

// ───────────────────────── Profil ─────────────────────────

api.get('/profile', async (req, res) => {
  const profile = check(await req.db.from('profiles').select('*').eq('id', req.user.id).maybeSingle());
  res.json(profile ?? check(await req.db.from('profiles').insert({ id: req.user.id }).select().single()));
});

const profileSchema = z.object({
  display_name: z.string().trim().max(60).nullable().optional(),
  daily_kcal_target: z.coerce.number().int().min(1000).max(10000).optional(),
  daily_protein_target: z.coerce.number().int().min(0).max(500).optional(),
  target_weight_kg: z.coerce.number().min(20).max(400).nullable().optional(),
});

api.put('/profile', async (req, res) => {
  const body = profileSchema.parse(req.body);
  res.json(check(await req.db.from('profiles').upsert({ id: req.user.id, ...body }).select().single()));
});

// ───────────────────────── Makanan ─────────────────────────

const foodSchema = z
  .object({
    name: z.string().trim().min(1).max(80),
    kcal_per_100g: positive.nullable().optional(),
    protein_per_100g: z.coerce.number().min(0).nullable().optional(),
    unit_name: z.string().trim().min(1).max(20).nullable().optional(),
    kcal_per_unit: positive.nullable().optional(),
    protein_per_unit: z.coerce.number().min(0).nullable().optional(),
  })
  .refine((f) => f.kcal_per_100g || f.kcal_per_unit, 'Isi kalori per 100 g atau per satuan')
  .refine((f) => !f.unit_name === !f.kcal_per_unit, 'Nama satuan dan kalori per satuan harus diisi berdua');

api.get('/foods', async (req, res) => {
  const foods = await fetchAll(() => req.db.from('foods').select('*').order('name'));
  // Kalau user sudah punya versi sendiri dari makanan bawaan, sembunyikan yang bawaan.
  const own = new Set(foods.filter((f) => f.user_id).map((f) => f.name.toLowerCase()));
  res.json(foods.filter((f) => f.user_id || !own.has(f.name.toLowerCase())));
});

api.post('/foods', async (req, res) => {
  const body = foodSchema.parse(req.body);
  res.status(201).json(check(await req.db.from('foods').insert({ ...body, user_id: req.user.id }).select().single()));
});

/** Tanya AI kalori sebuah makanan. Hasilnya belum disimpan — app menampilkan dulu, lalu menyimpan lewat POST /foods. */
api.post('/foods/estimate', async (req, res) => {
  if (!isAiConfigured()) throw new HttpError(503, 'Fitur AI belum diaktifkan (ANTHROPIC_API_KEY belum di-set di server)');
  const { name } = z.object({ name: z.string().trim().min(2, 'Isi nama makanan').max(80) }).parse(req.body);
  try {
    res.json(await estimateFood(name));
  } catch (err) {
    if (err instanceof AiEstimateError) throw new HttpError(422, err.message);
    throw err;
  }
});

api.put('/foods/:id', async (req, res) => {
  const body = foodSchema.parse(req.body);
  const existing = check(await req.db.from('foods').select('*').eq('id', req.params.id).maybeSingle());
  if (!existing) throw new HttpError(404, 'Makanan tidak ditemukan');

  if (existing.user_id) {
    res.json(check(await req.db.from('foods').update(body).eq('id', existing.id).select().single()));
  } else {
    // Makanan bawaan tidak diubah langsung; buat salinan milik user dengan nilai baru.
    const copy = { ...body, aliases: existing.aliases, user_id: req.user.id };
    res.json(check(await req.db.from('foods').insert(copy).select().single()));
  }
});

api.delete('/foods/:id', async (req, res) => {
  const deleted = check(await req.db.from('foods').delete().eq('id', req.params.id).select());
  if (!deleted.length) throw new HttpError(403, 'Makanan bawaan tidak bisa dihapus');
  res.status(204).end();
});

// ───────────────────────── Catatan makan ─────────────────────────

const entrySchema = z
  .object({
    eaten_on: isoDate,
    meal_type: z.enum(MEAL_TYPES),
    food_id: z.coerce.number().int().positive().nullable().optional(),
    food_name: z.string().trim().min(1).max(80).optional(),
    grams: positive.nullable().optional(),
    quantity: positive.nullable().optional(),
    kcal: z.coerce.number().min(0).max(20000).nullable().optional(),
    protein: z.coerce.number().min(0).max(1000).nullable().optional(),
  })
  .refine((e) => e.food_id || (e.food_name && e.kcal != null), 'Pilih makanan, atau isi nama & kalori sendiri');

async function buildEntry(db, body) {
  if (!body.food_id) {
    return {
      eaten_on: body.eaten_on,
      meal_type: body.meal_type,
      food_id: null,
      food_name: body.food_name,
      grams: body.grams ?? null,
      quantity: body.quantity ?? null,
      kcal: body.kcal,
      protein: body.protein ?? 0,
    };
  }
  const food = check(await db.from('foods').select('*').eq('id', body.food_id).maybeSingle());
  if (!food) throw new HttpError(404, 'Makanan tidak ditemukan');
  const grams = body.grams ?? null;
  const quantity = grams ? null : body.quantity ?? null;
  const nutrition = computeNutrition(food, { grams, quantity });
  if (!nutrition) {
    throw new HttpError(400, food.kcal_per_100g ? `Isi berat ${food.name} dalam gram` : `Isi jumlah ${food.unit_name}`);
  }
  return { eaten_on: body.eaten_on, meal_type: body.meal_type, food_id: food.id, food_name: food.name, grams, quantity, ...nutrition };
}

api.post('/entries', async (req, res) => {
  const entry = await buildEntry(req.db, entrySchema.parse(req.body));
  res.status(201).json(check(await req.db.from('meal_entries').insert(entry).select().single()));
});

api.put('/entries/:id', async (req, res) => {
  const entry = await buildEntry(req.db, entrySchema.parse(req.body));
  const updated = check(await req.db.from('meal_entries').update(entry).eq('id', req.params.id).select());
  if (!updated.length) throw new HttpError(404, 'Catatan tidak ditemukan');
  res.json(updated[0]);
});

api.delete('/entries/:id', async (req, res) => {
  check(await req.db.from('meal_entries').delete().eq('id', req.params.id));
  res.status(204).end();
});

/** Ringkasan satu hari: makanan per waktu makan, total, target, dan timbangan hari itu. */
api.get('/days/:date', async (req, res) => {
  const date = isoDate.parse(req.params.date);
  const [profile, entries, weights] = await Promise.all([
    req.db.from('profiles').select('*').eq('id', req.user.id).maybeSingle().then(check),
    req.db.from('meal_entries').select('*').eq('eaten_on', date).order('created_at').then(check),
    req.db
      .from('weight_logs')
      .select('*')
      .gte('measured_at', dayStart(date))
      .lt('measured_at', dayEnd(date))
      .order('measured_at')
      .then(check),
  ]);

  const meals = Object.fromEntries(MEAL_TYPES.map((t) => [t, entries.filter((e) => e.meal_type === t)]));
  res.json({
    date,
    target: { kcal: profile?.daily_kcal_target ?? 3000, protein: profile?.daily_protein_target ?? 120 },
    totals: sumNutrition(entries),
    meals,
    weights,
  });
});

// ───────────────────────── Berat badan ─────────────────────────

const weightSchema = z.object({
  weight_kg: z.coerce.number().min(20).max(400),
  measured_at: z.string().datetime({ offset: true }).optional(),
  condition: z.enum(['belum_makan', 'sedang_makan', 'sudah_makan']).nullable().optional(),
  note: z.string().trim().max(200).nullable().optional(),
});

api.get('/weights', async (req, res) => {
  const to = req.query.to ? isoDate.parse(req.query.to) : today();
  const from = req.query.from ? isoDate.parse(req.query.from) : addDays(to, -365);
  res.json(
    await fetchAll(() =>
      req.db
        .from('weight_logs')
        .select('*')
        .gte('measured_at', dayStart(from))
        .lt('measured_at', dayEnd(to))
        .order('measured_at', { ascending: false }),
    ),
  );
});

api.post('/weights', async (req, res) => {
  const body = weightSchema.parse(req.body);
  res.status(201).json(check(await req.db.from('weight_logs').insert(body).select().single()));
});

api.put('/weights/:id', async (req, res) => {
  const body = weightSchema.parse(req.body);
  const updated = check(await req.db.from('weight_logs').update(body).eq('id', req.params.id).select());
  if (!updated.length) throw new HttpError(404, 'Data berat tidak ditemukan');
  res.json(updated[0]);
});

api.delete('/weights/:id', async (req, res) => {
  check(await req.db.from('weight_logs').delete().eq('id', req.params.id));
  res.status(204).end();
});

// ───────────────────────── Statistik ─────────────────────────

function parseRange(query, defaultDays) {
  const to = query.to ? isoDate.parse(query.to) : today();
  const from = query.from ? isoDate.parse(query.from) : addDays(to, -(defaultDays - 1));
  if (daysBetween(from, to) < 0 || daysBetween(from, to) > 730) throw new HttpError(400, 'Rentang tanggal tidak valid');
  return { from, to };
}

/** Total kalori/protein dan berat pagi untuk setiap tanggal dalam rentang. */
async function buildDailySeries(req, from, to) {
  const [profile, entries, weights] = await Promise.all([
    req.db.from('profiles').select('*').eq('id', req.user.id).maybeSingle().then(check),
    fetchAll(() => req.db.from('meal_entries').select('eaten_on, kcal, protein').gte('eaten_on', from).lte('eaten_on', to)),
    fetchAll(() =>
      req.db.from('weight_logs').select('*').gte('measured_at', dayStart(from)).lt('measured_at', dayEnd(to)),
    ),
  ]);

  const days = [];
  for (let date = from; date <= to; date = addDays(date, 1)) {
    const dayEntries = entries.filter((e) => e.eaten_on === date);
    const weight = representativeWeight(weights.filter((w) => localDate(w.measured_at) === date));
    const totals = sumNutrition(dayEntries);
    days.push({
      date,
      kcal: totals.kcal,
      protein: totals.protein,
      logged: dayEntries.length > 0,
      weight_kg: weight ? Number(weight.weight_kg) : null,
    });
  }
  return { profile, days };
}

api.get('/stats', async (req, res) => {
  const { from, to } = parseRange(req.query, 30);
  const { profile, days } = await buildDailySeries(req, from, to);
  const kcalTarget = profile?.daily_kcal_target ?? 3000;

  const logged = days.filter((d) => d.logged);
  const weighed = days.filter((d) => d.weight_kg !== null);
  const slope = linearSlope(weighed.map((d) => ({ x: daysBetween(from, d.date), y: d.weight_kg })));

  res.json({
    from,
    to,
    target: { kcal: kcalTarget, protein: profile?.daily_protein_target ?? 120, weight_kg: profile?.target_weight_kg ?? null },
    days,
    summary: {
      days_logged: logged.length,
      avg_kcal: logged.length ? Math.round(logged.reduce((s, d) => s + d.kcal, 0) / logged.length) : null,
      avg_protein: logged.length ? Math.round(logged.reduce((s, d) => s + d.protein, 0) / logged.length) : null,
      days_on_target: logged.filter((d) => d.kcal >= kcalTarget).length,
      weight_start: weighed[0]?.weight_kg ?? null,
      weight_end: weighed.at(-1)?.weight_kg ?? null,
      weekly_change_kg: slope === null ? null : Math.round(slope * 7 * 100) / 100,
    },
  });
});

/** Perkiraan kebutuhan kalori harian dari catatan makan + timbangan pagi (default 28 hari terakhir). */
api.get('/energy', async (req, res) => {
  const { from, to } = parseRange(req.query, 28);
  const { days } = await buildDailySeries(req, from, to);
  res.json({ from, to, ...estimateEnergy(days) });
});

app.use('/api', api);

app.use((_req, _res, next) => next(new HttpError(404, 'Endpoint tidak ditemukan')));

// eslint-disable-next-line no-unused-vars
app.use((err, _req, res, _next) => {
  if (err instanceof z.ZodError) {
    return res.status(400).json({ error: err.issues.map((i) => i.message).join(', ') });
  }
  if (err instanceof HttpError) return res.status(err.status).json({ error: err.message });
  if (err?.type === 'entity.parse.failed') return res.status(400).json({ error: 'Body JSON tidak valid' });
  if (err?.code === '23505') return res.status(409).json({ error: 'Nama makanan itu sudah ada' });
  console.error(err);
  res.status(500).json({ error: 'Terjadi kesalahan di server' });
});

export default app;
