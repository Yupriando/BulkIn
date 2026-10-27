// Isi tabel foods dengan makanan bawaan. Aman dijalankan berulang (yang sudah ada di-update).
// Pakai: npm run seed
import { adminClient } from '../src/supabase.js';
import { FOOD_CATALOG } from '../src/foodCatalog.js';

const db = adminClient();

const { data: existing, error } = await db.from('foods').select('id, name').is('user_id', null);
if (error) throw error;
const idByName = new Map(existing.map((f) => [f.name.toLowerCase(), f.id]));

const blank = { kcal_per_100g: null, protein_per_100g: null, unit_name: null, kcal_per_unit: null, protein_per_unit: null };
let inserted = 0;
let updated = 0;

for (const food of FOOD_CATALOG) {
  const row = { ...blank, ...food, user_id: null };
  const id = idByName.get(food.name.toLowerCase());
  const result = id ? await db.from('foods').update(row).eq('id', id) : await db.from('foods').insert(row);
  if (result.error) throw new Error(`${food.name}: ${result.error.message}`);
  id ? updated++ : inserted++;
}

console.log(`Selesai: ${inserted} makanan baru, ${updated} diperbarui.`);
