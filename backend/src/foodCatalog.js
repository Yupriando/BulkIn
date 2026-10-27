// Makanan bawaan BulkIn. Angka per 100 g / per satuan.
// Yang bertanda "dari catatan" dihitung dari angka yang sudah kamu tulis di catatan manual;
// sisanya estimasi umum — silakan koreksi lewat menu Makanan di aplikasi.
//
// aliases dipakai untuk mencocokkan teks catatan lama saat import.

const g = (name, kcal, protein, extra = {}) => ({
  name,
  kcal_per_100g: kcal,
  protein_per_100g: protein,
  aliases: [],
  ...extra,
});

const unit = (name, unitName, kcal, protein, extra = {}) => ({
  name,
  unit_name: unitName,
  kcal_per_unit: kcal,
  protein_per_unit: protein,
  aliases: [],
  ...extra,
});

export const FOOD_CATALOG = [
  // ── Karbohidrat
  g('Nasi putih', 129, 2.7, { aliases: ['nasi'] }), // dari catatan: 438.6 kkal / 340 g
  g('Nasi goreng', 160, 3.5),
  g('Nasi McD', 129, 2.7, { unit_name: 'porsi', kcal_per_unit: 177, protein_per_unit: 3.7, aliases: ['nasi mcd'] }),
  g('Bubur nasi', 46, 1, { aliases: ['bubur'] }),
  g('Bubur nasi ayam', 70, 3.5, { aliases: ['bubur ayam'] }),
  g('Oatmeal', 389, 13.5, { aliases: ['oat', 'oatmeal'] }), // dari catatan: 389 kkal / 100 g
  unit('Overnight oatmeal', 'porsi', 515, 18, { aliases: ['overnight oatmeal', 'night over oatmeal'] }),
  g('Bihun goreng', 150, 3, { aliases: ['bihun'] }), // dari catatan: 230 kkal / 153 g
  unit('Kwetiau lapciong', 'porsi', 550, 15, { aliases: ['kwetiau'] }),
  unit('Roti tawar', 'lembar', 70, 2.5, { aliases: ['roti'] }),
  unit('Roti coklat', 'pcs', 280, 6),
  unit('Onigiri salmon mayo', 'pcs', 230, 6, { aliases: ['onigiri'] }),

  // ── Mie
  unit('Mie Gacoan', 'porsi', 620, 15, { aliases: ['gacoan'] }), // dari catatan
  unit('Mie goreng instan', 'bungkus', 380, 8, {
    aliases: ['mie goreng', 'mie goreng biasa', 'mie goreng ayam bawang', 'indomie goreng', 'indomie'],
  }),
  unit('Mie goreng rendang', 'bungkus', 550, 9, { aliases: ['indomie rendang', 'mie rendang'] }), // dari catatan
  unit('Mie goreng jumbo', 'bungkus', 560, 10, { aliases: ['mie goreng jumbo'] }), // dari catatan
  unit('Pop Mie', 'cup', 360, 7, { aliases: ['pop mie', 'popmie'] }), // dari catatan

  // ── Ayam
  g('Ayam goreng', 260, 25, { aliases: ['ayam'] }),
  g('Ayam tepung', 264, 18, { aliases: ['ayam goreng tepung'] }), // dari catatan: 280 kkal / 106 g
  g('Ayam kecap', 190, 18),
  g('Paha ayam', 230, 22),
  g('Dada ayam', 250, 28, { unit_name: 'pcs', kcal_per_unit: 320, protein_per_unit: 32 }),
  g('Ayam KFC', 290, 20, { unit_name: 'pcs', kcal_per_unit: 290, protein_per_unit: 20, aliases: ['kfc', 'ayam kfc paha'] }),
  g('Ayam McD', 280, 20, { unit_name: 'pcs', kcal_per_unit: 280, protein_per_unit: 20, aliases: ['ayam mcd'] }),
  g('Ayam hitam', 132, 20), // dari catatan: 75 kkal / 57 g
  g('Opor ayam', 190, 16, { aliases: ['opor'] }),
  g('Marry me chicken', 200, 20, { aliases: ['marryme chicken', 'marry me chicken'] }),
  g('Padakjeon', 206, 15, { aliases: ['ayam padakjeon'] }), // dari catatan: 220 kkal / 107 g

  // ── Daging lain
  g('Australian ribeye', 216, 20, { aliases: ['australia ribeye', 'ribeye'] }), // dari catatan: 110 kkal / 51 g
  g('Sirloin meltique steak', 250, 20, { aliases: ['sirloin meltique', 'sirloin', 'steak'] }),
  g('Daging sapi', 250, 26, { aliases: ['sapi'] }),
  g('Meatball sapi', 250, 14, { aliases: ['meatball'] }),
  g('Empal', 250, 25),
  g('Bakso urat', 200, 12, { unit_name: 'butir', kcal_per_unit: 60, protein_per_unit: 3.5 }),
  unit('Bakso (porsi)', 'porsi', 350, 18, { aliases: ['bakso', 'bakso daging urat'] }),
  g('Pork belly goreng', 518, 9, { aliases: ['pork belly'] }),
  g('Babi goreng has dalam', 250, 27, { aliases: ['babi goreng', 'has dalam', 'babi'] }),
  g('Ma Ling', 300, 13, { aliases: ['maling', 'ma ling'] }),
  g('Otak babi telur goreng', 200, 12, { aliases: ['otak babi telur', 'otak babi'] }),
  g('Kapsim goreng', 250, 15, { aliases: ['kapsim'] }),

  // ── Seafood
  g('Salmon', 208, 20),
  g('Cumi goreng', 175, 18, { aliases: ['cumi'] }),
  g('Kerang', 86, 14),

  // ── Telur, tahu, tempe
  g('Telur', 155, 13, { unit_name: 'butir', kcal_per_unit: 70, protein_per_unit: 6, aliases: ['telur rebus', 'telur rebus omega', 'telur goreng'] }),
  g('Telur jamur', 150, 10),
  g('Tahu', 90, 8, { aliases: ['tahu kuning'] }), // dari catatan: 180 kkal / 200 g
  g('Tahu goreng tepung', 220, 9, { aliases: ['tahu goreng tepung tipis', 'tahu goreng'] }),
  g('Tahu isi', 190, 6),
  g('Tempe goreng', 225, 17, { aliases: ['tempe'] }), // dari catatan: 126 kkal / 56 g

  // ── Gorengan & dimsum
  g('Ote-ote', 233, 5, { aliases: ['oteote', 'ote ote'] }), // dari catatan: 119 kkal / 51 g
  g('Swekiau', 200, 10, { aliases: ['sweekiau', 'seekiau', 'swikiau'] }),
  g('Cakwe isi', 300, 7, { aliases: ['chakwe isi', 'chakwe', 'cakwe'] }),
  unit('Pisang goreng', 'pcs', 110, 1.5), // dari catatan: 220 kkal / 2 pcs

  // ── Sayur & buah
  g('Buncis', 31, 1.8),
  g('Kimchi', 15, 1.1),
  g('Pisang', 89, 1.1, { unit_name: 'buah', kcal_per_unit: 105, protein_per_unit: 1.3 }),
  g('Blueberry', 57, 0.7),

  // ── Lain-lain
  unit('Gula pasir', 'sdt', 16, 0, { aliases: ['gula'] }), // dari catatan: 48 kkal / 3 sdt
  unit('Keju slice', 'lembar', 60, 3.5, { aliases: ['keju'] }),
  unit('Selai kacang', 'sdm', 95, 4, { aliases: ['peanut butter', 'peanut'] }),
  unit('Brownies', 'potong', 230, 3),
  unit('Kue', 'potong', 200, 3),
  unit('Jus pisang coklat', 'gelas', 355, 6), // dari catatan
  unit('Pro Gainer', 'serving', 1030, 55, { aliases: ['progainer', 'gainer'] }), // dari catatan
];
