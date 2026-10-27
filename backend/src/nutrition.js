const round1 = (n) => Math.round(n * 10) / 10;
const num = (v) => (v === null || v === undefined || v === '' ? null : Number(v));

/**
 * Hitung kalori & protein dari satu makanan.
 * Pakai gram jika makanan punya nilai per 100 g, atau jumlah satuan jika punya nilai per satuan.
 * Mengembalikan null jika kombinasi input tidak bisa dihitung (mis. "1 porsi" untuk makanan yang hanya punya nilai per 100 g).
 */
export function computeNutrition(food, { grams, quantity }) {
  const g = num(grams);
  const q = num(quantity);
  const per100 = num(food.kcal_per_100g);
  const perUnit = num(food.kcal_per_unit);

  if (g && per100 !== null) {
    const factor = g / 100;
    return {
      kcal: round1(per100 * factor),
      protein: round1((num(food.protein_per_100g) ?? 0) * factor),
    };
  }
  if (q && perUnit !== null) {
    return {
      kcal: round1(perUnit * q),
      protein: round1((num(food.protein_per_unit) ?? 0) * q),
    };
  }
  return null;
}

export function sumNutrition(entries) {
  const total = entries.reduce(
    (acc, e) => ({ kcal: acc.kcal + Number(e.kcal || 0), protein: acc.protein + Number(e.protein || 0) }),
    { kcal: 0, protein: 0 },
  );
  return { kcal: round1(total.kcal), protein: round1(total.protein) };
}

/** Kemiringan regresi linear (kg per hari) dari titik [{x: hari ke-, y: berat}]. */
export function linearSlope(points) {
  if (points.length < 2) return null;
  const n = points.length;
  const mx = points.reduce((s, p) => s + p.x, 0) / n;
  const my = points.reduce((s, p) => s + p.y, 0) / n;
  let cov = 0;
  let varX = 0;
  for (const p of points) {
    cov += (p.x - mx) * (p.y - my);
    varX += (p.x - mx) ** 2;
  }
  return varX === 0 ? null : cov / varX;
}
