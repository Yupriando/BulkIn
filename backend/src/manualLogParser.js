// Parser catatan manual format lama, contoh:
//   (Day 1) Minggu, 6 September 2026
//   BB : 61.4 kg (jam 09.19 pagi baru siap sarapan) , BB 61.9 kg (malam jam 23.15)
//   Sarapan : 340g nasi (438.6 kkal) + 106g ayam tepung (280 kkal) + 1 pisang (90 kkal)
// Hari tanpa tanggal dianggap tanggal hari sebelumnya + 1.

import { computeNutrition } from './nutrition.js';
import { addDays } from './dates.js';

const MONTHS = {
  januari: 1, februari: 2, maret: 3, april: 4, mei: 5, juni: 6,
  juli: 7, agustus: 8, september: 9, oktober: 10, november: 11, desember: 12,
};

const MEAL_TYPES = { sarapan: 'sarapan', siang: 'siang', sore: 'sore', malam: 'malam', camilan: 'camilan', ngemil: 'camilan' };

const UNIT_WORDS = 'sdt|sdm|bks|bungkus|pcs|buah|butir|porsi|potong|lembar|cup|gelas|serving';

const toNumber = (s) => Number(String(s).replace(',', '.'));

export const normalize = (s) =>
  s.toLowerCase().replace(/[^a-z0-9 ]+/g, ' ').replace(/\s+/g, ' ').trim();

const pad = (n) => String(n).padStart(2, '0');

/** Pecah "a + b (x + y) × c dengan d" jadi item, abaikan pemisah di dalam kurung. */
export function splitItems(text) {
  const items = [];
  let depth = 0;
  let current = '';
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (ch === '(') depth++;
    if (ch === ')') depth = Math.max(0, depth - 1);
    const rest = text.slice(i);
    const sepMatch = depth === 0 && (/^[+×]/.exec(rest) || /^\sdengan\s/i.exec(rest));
    if (sepMatch) {
      items.push(current);
      current = '';
      i += sepMatch[0].length - 1;
      continue;
    }
    current += ch;
  }
  items.push(current);
  return items.map((s) => s.trim()).filter(Boolean);
}

/** Cari makanan dengan nama/alias terpanjang yang muncul di teks item. */
export function matchFood(name, foods) {
  const target = ` ${normalize(name)} `;
  let best = null;
  let bestLen = 0;
  for (const food of foods) {
    for (const candidate of [food.name, ...(food.aliases || [])]) {
      const c = normalize(candidate);
      if (c && c.length > bestLen && target.includes(` ${c} `)) {
        best = food;
        bestLen = c.length;
      }
    }
  }
  return best;
}

/** Ubah satu item teks jadi entri makanan. */
export function parseItem(raw, foods) {
  let text = raw.replace(/=\s*[\d.,]+\s*k[a-z]*al\s*$/i, '').trim();

  let kcal = null;
  let protein = null;
  let gramsInParens = null;
  text = text.replace(/\(([^)]*)\)?/g, (_, inner) => {
    const k = /(\d+(?:[.,]\d+)?)\s*k[a-z]{0,3}al/i.exec(inner);
    if (k) kcal = toNumber(k[1]);
    const p = /(\d+(?:[.,]\d+)?)\s*protein/i.exec(inner);
    if (p) protein = toNumber(p[1]);
    const gr = /(\d+(?:[.,]\d+)?)\s*g\b/i.exec(inner);
    if (gr) gramsInParens = toNumber(gr[1]);
    return ' ';
  });
  text = text.replace(/\s+/g, ' ').trim();

  let grams = null;
  let quantity = null;

  // "35gEmpal" (tanpa spasi) dikenali lewat huruf kapital setelah "g"
  const leadingGrams =
    /^(\d+(?:[.,]\d+)?)\s*(?:g|gr|gram)\b\s*(.*)$/i.exec(text) || /^(\d+(?:[.,]\d+)?)g([A-Z].*)$/.exec(text);
  const leadingUnit = new RegExp(`^(\\d+(?:[.,]\\d+)?)\\s*(${UNIT_WORDS})\\b\\s*(.*)$`, 'i').exec(text);
  const leadingNumber = /^(\d+(?:[.,]\d+)?)\s+(.*)$/.exec(text);

  let name = text;
  let unitWord = null;
  if (leadingGrams) {
    grams = toNumber(leadingGrams[1]);
    name = leadingGrams[2];
  } else if (leadingUnit) {
    quantity = toNumber(leadingUnit[1]);
    unitWord = leadingUnit[2].toLowerCase();
    name = leadingUnit[3];
  } else if (leadingNumber) {
    const n = toNumber(leadingNumber[1]);
    // "55 Babi Goreng" = 55 gram, "2 Bakso Urat" = 2 buah
    if (n >= 10) grams = n;
    else quantity = n;
    name = leadingNumber[2];
  }

  // "1 telur rebus omega 53g" / "Empal 30g"
  const nameTrailing = /^(.*?)\s*(\d+(?:[.,]\d+)?)\s*g$/i.exec(name);
  if (nameTrailing && nameTrailing[1]) {
    grams = toNumber(nameTrailing[2]);
    name = nameTrailing[1];
  }

  if (grams === null && gramsInParens !== null && quantity === null) grams = gramsInParens;
  if (grams !== null) quantity = null;
  if (grams === null && quantity === null) quantity = 1;

  name = name.trim();
  if (!name && unitWord === 'sdt') name = 'gula';

  const food = matchFood(name, foods);
  const computed = food ? computeNutrition(food, { grams, quantity }) : null;

  return {
    food_id: food?.id ?? null,
    food_name: food ? food.name : name || raw.trim(),
    original_text: raw.trim(),
    grams,
    quantity,
    kcal: kcal ?? computed?.kcal ?? 0,
    protein: protein ?? computed?.protein ?? 0,
    // true jika kalori tidak tertulis dan tidak bisa dihitung — perlu dicek manual
    unresolved: kcal === null && computed === null,
  };
}

function parseWeights(line, date, tzOffset) {
  const weights = [];
  const re = /(\d+(?:[.,]\d+)?)\s*kg\s*(?:\(([^)]*)\))?/gi;
  let m;
  while ((m = re.exec(line))) {
    const note = (m[2] || '').trim();
    const time = /jam\s*(\d{1,2})[.:](\d{2})/i.exec(note);
    let hour = time ? Number(time[1]) : 7;
    const minute = time ? Number(time[2]) : 0;
    if (/malam|sore/i.test(note) && hour < 12) hour += 12;

    let condition = null;
    if (/belum/i.test(note)) condition = 'belum_makan';
    else if (/lagi|sambil|sedang/i.test(note)) condition = 'sedang_makan';
    else if (/udah|sudah|siap|habis/i.test(note)) condition = 'sudah_makan';

    weights.push({
      weight_kg: toNumber(m[1]),
      measured_at: `${date}T${pad(hour)}:${pad(minute)}:00${tzOffset}`,
      condition,
      note: note || null,
    });
  }
  return weights;
}

/**
 * @returns {{ dailyKcalTarget: number|null, days: Array<{date, weights, entries}> }}
 */
export function parseManualLog(text, foods, { tzOffset = '+07:00' } = {}) {
  const days = [];
  let dailyKcalTarget = null;
  let day = null;
  let lastMeal = null;

  for (const rawLine of text.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line) continue;

    const target = /butuh\s*([\d.,]+)\s*k?kal/i.exec(line);
    if (target) {
      dailyKcalTarget = Number(target[1].replace(/[.,]/g, ''));
      continue;
    }

    const header = /^\(day\s*\d+\)\s*(.*)$/i.exec(line);
    if (header) {
      const dm = /(\d{1,2})\s+([a-z]+)\s+(\d{4})/i.exec(header[1]);
      let date;
      if (dm && MONTHS[dm[2].toLowerCase()]) {
        date = `${dm[3]}-${pad(MONTHS[dm[2].toLowerCase()])}-${pad(Number(dm[1]))}`;
      } else if (day) {
        date = addDays(day.date, 1);
      } else {
        throw new Error(`Tidak bisa menentukan tanggal untuk: "${line}"`);
      }
      day = { date, weights: [], entries: [] };
      days.push(day);
      lastMeal = null;
      continue;
    }

    if (!day) continue;

    if (/^bb\b/i.test(line)) {
      day.weights.push(...parseWeights(line, day.date, tzOffset));
      continue;
    }

    const meal = /^(sarapan|siang|sore|malam|camilan|ngemil)\s*:?\s*(.*)$/i.exec(line);
    let mealType;
    let body;
    if (meal) {
      mealType = MEAL_TYPES[meal[1].toLowerCase()];
      body = meal[2];
      lastMeal = mealType;
    } else if (lastMeal && line.length > 2) {
      // baris lanjutan dari waktu makan sebelumnya
      mealType = lastMeal;
      body = line;
    } else {
      continue;
    }

    for (const item of splitItems(body)) {
      day.entries.push({ meal_type: mealType, ...parseItem(item, foods) });
    }
  }

  return { dailyKcalTarget, days };
}
