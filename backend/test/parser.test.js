import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { FOOD_CATALOG } from '../src/foodCatalog.js';
import { parseItem, parseManualLog, splitItems } from '../src/manualLogParser.js';
import { computeNutrition, linearSlope } from '../src/nutrition.js';

const foods = FOOD_CATALOG.map((f, i) => ({ id: i + 1, ...f }));
const item = (text) => parseItem(text, foods);

test('hitung kalori dari gram dan dari satuan', () => {
  assert.deepEqual(computeNutrition({ kcal_per_100g: 129, protein_per_100g: 2.7 }, { grams: 400 }), { kcal: 516, protein: 10.8 });
  assert.deepEqual(computeNutrition({ kcal_per_unit: 1030, protein_per_unit: 55 }, { quantity: 1 }), { kcal: 1030, protein: 55 });
  assert.equal(computeNutrition({ kcal_per_100g: 129 }, { quantity: 1 }), null);
});

test('pemisah di dalam kurung tidak memecah item', () => {
  assert.deepEqual(splitItems('400g Nasi + Pro Gainer (55 Protein + 1030 kkal)'), ['400g Nasi', 'Pro Gainer (55 Protein + 1030 kkal)']);
  assert.deepEqual(splitItems('153g Bihun Goreng × 45g Oatmeal dengan 2sdt Gula'), ['153g Bihun Goreng', '45g Oatmeal', '2sdt Gula']);
});

test('item dengan gram dicocokkan ke makanan paling spesifik', () => {
  const nasi = item('400g Nasi');
  assert.equal(nasi.food_name, 'Nasi putih');
  assert.equal(nasi.grams, 400);
  assert.equal(nasi.kcal, 516);

  assert.equal(item('106g ayam tepung').food_name, 'Ayam tepung');
  assert.equal(item('402g Nasi Goreng').food_name, 'Nasi goreng');
  assert.equal(item('55 Babi Goreng has dalam').grams, 55);
  assert.equal(item('54,3g Sirloin Meltique Steak').grams, 54.3);
  assert.equal(item('Empal 30g').grams, 30);
  assert.equal(item('35gEmpal').food_name, 'Empal');
});

test('kalori yang ditulis di catatan diutamakan', () => {
  const e = item('1 pisang 125g (111 kkal)');
  assert.equal(e.kcal, 111);
  assert.equal(e.grams, 125);
  assert.equal(item('2 pisang goreng (220 klal)').kcal, 220);
  assert.equal(item('1 pop Mie (360 kkal').kcal, 360);

  const gainer = item('Pro Gainer (55 Protein + 1030 kkal)');
  assert.equal(gainer.kcal, 1030);
  assert.equal(gainer.protein, 55);
});

test('satuan: sdt, bungkus, pcs', () => {
  const gula = item('6sdt Gula');
  assert.equal(gula.food_name, 'Gula pasir');
  assert.equal(gula.kcal, 96);
  assert.equal(item('2sdt').food_name, 'Gula pasir');
  assert.equal(item('1bks mie goreng rendang').kcal, 550);
  assert.equal(item('1 bks mie goreng ayam bawang').food_name, 'Mie goreng instan');
  assert.equal(item('2 mie gacoan').kcal, 1240);
  assert.equal(item('2 Bakso Urat').food_name, 'Bakso urat');
});

test('item yang tidak bisa dihitung ditandai', () => {
  assert.equal(item('Ngemil').unresolved, true);
  assert.equal(item('Kerang dll').unresolved, true);
});

test('regresi berat badan per hari', () => {
  assert.equal(linearSlope([{ x: 0, y: 60 }, { x: 7, y: 61 }]).toFixed(4), (1 / 7).toFixed(4));
});

test('parse seluruh catatan manual', async () => {
  const text = await readFile(new URL('../data/catatan-manual.txt', import.meta.url), 'utf8');
  const { dailyKcalTarget, days } = parseManualLog(text, foods);

  assert.equal(dailyKcalTarget, 3000);
  assert.equal(days.length, 51); // ada dua "Day 24"
  assert.equal(days[0].date, '2026-09-06');
  assert.equal(days.at(-1).date, '2026-10-26'); // Day 45-50 tanpa tanggal → lanjut dari 20 Oktober

  const [pagi, malam] = days[0].weights;
  assert.equal(pagi.weight_kg, 61.4);
  assert.equal(pagi.measured_at, '2026-09-06T09:19:00+07:00');
  assert.equal(pagi.condition, 'sudah_makan');
  assert.equal(malam.measured_at, '2026-09-06T23:15:00+07:00');
  assert.equal(days[1].weights[0].condition, 'belum_makan');

  // Baris lanjutan "Pro Gainer ... + 1 Mie Gacoan" masuk ke makan malam Day 2
  const day2Malam = days[1].entries.filter((e) => e.meal_type === 'malam');
  assert.ok(day2Malam.some((e) => e.food_name === 'Mie Gacoan'));
  assert.ok(day2Malam.some((e) => e.food_name === 'Pro Gainer'));
});
