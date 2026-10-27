import { test } from 'node:test';
import assert from 'node:assert/strict';
import { estimateEnergy } from '../src/energy.js';

const series = (n, { kcal, startKg, kgPerDay, every = 1 }) =>
  Array.from({ length: n }, (_, i) => ({
    date: `d${i}`,
    kcal,
    logged: true,
    weight_kg: i % every === 0 ? startKg + kgPerDay * i : null,
  }));

test('berat stabil → kebutuhan = kalori yang dimakan', () => {
  const r = estimateEnergy(series(28, { kcal: 2500, startKg: 65, kgPerDay: 0 }));
  assert.equal(r.ok, true);
  assert.equal(r.tdee_kcal, 2500);
  assert.deepEqual(r.targets.map((t) => t.kcal), [2800, 3050]);
});

test('berat turun 0,5 kg/minggu sambil makan 2000 → kebutuhan ±2550', () => {
  const r = estimateEnergy(series(28, { kcal: 2000, startKg: 66, kgPerDay: -0.5 / 7 }));
  assert.equal(r.tdee_kcal, 2550);
  assert.equal(r.weekly_change_kg, -0.5);
});

test('hari yang tercatat sebagian tidak dihitung', () => {
  const days = series(28, { kcal: 2500, startKg: 65, kgPerDay: 0 });
  days[3].kcal = 380; // cuma sarapan yang dicatat
  const r = estimateEnergy(days);
  assert.equal(r.incomplete_days, 1);
  assert.equal(r.avg_intake_kcal, 2500);
});

test('data kurang → tidak dihitung', () => {
  const r = estimateEnergy(series(7, { kcal: 2500, startKg: 65, kgPerDay: 0 }));
  assert.equal(r.ok, false);
});
