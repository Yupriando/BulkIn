// Perkiraan kebutuhan kalori harian (TDEE) dari data nyata:
//   kalori masuk rata-rata  −  perubahan berat × 7.700 kkal/kg
// Kalau berat stabil, berarti kalori yang dimakan ≈ kebutuhan. Kalau berat turun walau makan X kkal,
// berarti kebutuhan > X, dan sebaliknya.

import { linearSlope } from './nutrition.js';

export const KCAL_PER_KG = 7700;
const MIN_LOGGED_DAYS = 10;
const MIN_WEIGH_INS = 5;

const round = (n, step) => Math.round(n / step) * step;

function median(values) {
  const s = [...values].sort((a, b) => a - b);
  const mid = Math.floor(s.length / 2);
  return s.length % 2 ? s[mid] : (s[mid - 1] + s[mid]) / 2;
}

/**
 * @param {Array<{date: string, kcal: number, logged: boolean, weight_kg: number|null}>} days  urut tanggal
 * @param {number[]} weeklyGainOptions  target kenaikan kg/minggu
 */
export function estimateEnergy(days, weeklyGainOptions = [0.25, 0.5]) {
  const logged = days.filter((d) => d.logged);
  const weighed = days
    .map((d, i) => ({ x: i, y: d.weight_kg }))
    .filter((p) => p.y !== null);

  // Hari yang catatannya jauh di bawah biasanya (mis. cuma sarapan yang dicatat) dianggap tidak lengkap.
  const typical = logged.length ? median(logged.map((d) => d.kcal)) : 0;
  const complete = logged.filter((d) => d.kcal >= typical * 0.5);
  const incompleteDays = logged.length - complete.length;

  const base = {
    window_days: days.length,
    days_logged: complete.length,
    incomplete_days: incompleteDays,
    weigh_ins: weighed.length,
  };

  if (complete.length < MIN_LOGGED_DAYS || weighed.length < MIN_WEIGH_INS) {
    return {
      ...base,
      ok: false,
      reason: `Butuh minimal ${MIN_LOGGED_DAYS} hari catatan makan lengkap dan ${MIN_WEIGH_INS} kali timbang pagi dalam periode ini`,
    };
  }

  const avgIntake = complete.reduce((s, d) => s + d.kcal, 0) / complete.length;
  const slopePerDay = linearSlope(weighed);
  const tdee = avgIntake - slopePerDay * KCAL_PER_KG;

  const coverage = complete.length / days.length;
  const confidence = coverage >= 0.8 && weighed.length >= 14 ? 'tinggi' : coverage >= 0.6 && weighed.length >= 8 ? 'sedang' : 'rendah';

  return {
    ...base,
    ok: true,
    avg_intake_kcal: Math.round(avgIntake),
    weekly_change_kg: Math.round(slopePerDay * 7 * 100) / 100,
    tdee_kcal: round(tdee, 10),
    targets: weeklyGainOptions.map((rate) => ({
      weekly_gain_kg: rate,
      kcal: round(tdee + (rate * KCAL_PER_KG) / 7, 50),
    })),
    confidence,
  };
}
