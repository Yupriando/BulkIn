// Import catatan manual lama ke database.
//
// Pakai:
//   npm run import -- --email kamu@email.com                 (cek dulu, belum menyimpan apa-apa)
//   npm run import -- --email kamu@email.com --save          (simpan ke database)
//   npm run import -- --email kamu@email.com --file data/lain.txt --save
//
// Hari yang sudah punya data di database akan dilewati, jadi aman dijalankan ulang.
import { readFile } from 'node:fs/promises';
import { parseArgs } from 'node:util';
import { adminClient } from '../src/supabase.js';
import { parseManualLog } from '../src/manualLogParser.js';
import { sumNutrition } from '../src/nutrition.js';
import { TZ_OFFSET, dayStart, dayEnd } from '../src/dates.js';

const { values: args } = parseArgs({
  options: {
    email: { type: 'string' },
    file: { type: 'string', default: 'data/catatan-manual.txt' },
    save: { type: 'boolean', default: false },
  },
});
if (!args.email) {
  console.error('Wajib isi --email (email akun NaikIn kamu). Daftar dulu lewat aplikasi.');
  process.exit(1);
}

const db = adminClient();

async function findUser(email) {
  for (let page = 1; ; page++) {
    const { data, error } = await db.auth.admin.listUsers({ page, perPage: 200 });
    if (error) throw error;
    const user = data.users.find((u) => u.email?.toLowerCase() === email.toLowerCase());
    if (user) return user;
    if (data.users.length < 200) return null;
  }
}

const user = await findUser(args.email);
if (!user) {
  console.error(`User dengan email ${args.email} tidak ditemukan. Daftar dulu lewat aplikasi.`);
  process.exit(1);
}

const { data: foods, error: foodsError } = await db.from('foods').select('*').or(`user_id.is.null,user_id.eq.${user.id}`);
if (foodsError) throw foodsError;

const text = await readFile(args.file, 'utf8');
const { dailyKcalTarget, days } = parseManualLog(text, foods, { tzOffset: TZ_OFFSET });

const unresolved = [];
for (const day of days) {
  const total = sumNutrition(day.entries);
  const weight = day.weights.map((w) => `${w.weight_kg} kg`).join(', ') || '-';
  console.log(`${day.date}  BB ${weight.padEnd(16)} ${String(day.entries.length).padStart(2)} item  ±${Math.round(total.kcal)} kkal`);
  for (const e of day.entries.filter((x) => x.unresolved)) unresolved.push(`${day.date} [${e.meal_type}] ${e.original_text}`);
}

if (dailyKcalTarget) console.log(`\nTarget kalori dari catatan: ${dailyKcalTarget} kkal/hari`);
if (unresolved.length) {
  console.log(`\n${unresolved.length} item belum bisa dihitung kalorinya (disimpan 0 kkal, bisa diedit di app):`);
  for (const line of unresolved) console.log(`  - ${line}`);
}

if (!args.save) {
  console.log('\nIni baru pratinjau. Tambahkan --save untuk menyimpan.');
  process.exit(0);
}

if (dailyKcalTarget) {
  const { error } = await db.from('profiles').upsert({ id: user.id, daily_kcal_target: dailyKcalTarget });
  if (error) throw error;
}

let savedDays = 0;
let skippedDays = 0;
for (const day of days) {
  const [{ count: entryCount }, { count: weightCount }] = await Promise.all([
    db.from('meal_entries').select('id', { count: 'exact', head: true }).eq('user_id', user.id).eq('eaten_on', day.date),
    db
      .from('weight_logs')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .gte('measured_at', dayStart(day.date))
      .lt('measured_at', dayEnd(day.date)),
  ]);
  if (entryCount || weightCount) {
    skippedDays++;
    continue;
  }

  if (day.entries.length) {
    const rows = day.entries.map(({ original_text, unresolved: _u, ...e }) => ({ ...e, user_id: user.id, eaten_on: day.date }));
    const { error } = await db.from('meal_entries').insert(rows);
    if (error) throw new Error(`${day.date}: ${error.message}`);
  }
  if (day.weights.length) {
    const { error } = await db.from('weight_logs').insert(day.weights.map((w) => ({ ...w, user_id: user.id })));
    if (error) throw new Error(`${day.date}: ${error.message}`);
  }
  savedDays++;
}

console.log(`\nTersimpan ${savedDays} hari. ${skippedDays} hari dilewati karena sudah ada datanya.`);
