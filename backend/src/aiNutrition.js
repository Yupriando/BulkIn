// Estimasi kalori & protein makanan memakai AI.
// Gemini (ada paket gratis) dipakai kalau GEMINI_API_KEY diisi; kalau tidak, Claude (ANTHROPIC_API_KEY).
import Anthropic from '@anthropic-ai/sdk';
import { z } from 'zod';

const geminiKey = () => process.env.GEMINI_API_KEY?.trim() ?? '';
const useGemini = () => geminiKey().length > 20;

export const AI_PROVIDER = useGemini() ? 'gemini' : 'claude';
export const AI_MODEL = useGemini()
  ? process.env.GEMINI_MODEL || 'gemini-flash-latest'
  : process.env.ANTHROPIC_MODEL || 'claude-opus-5-5';

const nullableNumber = { anyOf: [{ type: 'number' }, { type: 'null' }] };
const nullableString = { anyOf: [{ type: 'string' }, { type: 'null' }] };

const SCHEMA = {
  type: 'object',
  properties: {
    is_food: { type: 'boolean' },
    name: { type: 'string' },
    kcal_per_100g: nullableNumber,
    protein_per_100g: nullableNumber,
    unit_name: nullableString,
    kcal_per_unit: nullableNumber,
    protein_per_unit: nullableNumber,
    assumption: { type: 'string' },
  },
  required: ['is_food', 'name', 'kcal_per_100g', 'protein_per_100g', 'unit_name', 'kcal_per_unit', 'protein_per_unit', 'assumption'],
  additionalProperties: false,
};

// Validasi ulang hasil model sebelum dipakai (batas angka masuk akal).
const resultSchema = z.object({
  is_food: z.boolean(),
  name: z.string().trim().min(1).max(80),
  kcal_per_100g: z.number().min(0).max(950).nullable(),
  protein_per_100g: z.number().min(0).max(100).nullable(),
  unit_name: z.string().trim().min(1).max(20).nullable(),
  kcal_per_unit: z.number().positive().max(5000).nullable(),
  protein_per_unit: z.number().min(0).max(300).nullable(),
  assumption: z.string().max(400),
});

// Skema yang sama dalam format Gemini (subset OpenAPI).
const geminiNumber = { type: 'NUMBER', nullable: true };
const GEMINI_SCHEMA = {
  type: 'OBJECT',
  properties: {
    is_food: { type: 'BOOLEAN' },
    name: { type: 'STRING' },
    kcal_per_100g: geminiNumber,
    protein_per_100g: geminiNumber,
    unit_name: { type: 'STRING', nullable: true },
    kcal_per_unit: geminiNumber,
    protein_per_unit: geminiNumber,
    assumption: { type: 'STRING' },
  },
  required: SCHEMA.required,
  propertyOrdering: SCHEMA.required,
};

const SYSTEM = `Kamu ahli gizi yang memperkirakan kandungan kalori dan protein makanan, khususnya makanan Indonesia dan makanan yang umum dijual di Indonesia (warung, restoran, minimarket, merek kemasan).

Untuk nama makanan yang diberikan user:
- name: nama makanan yang rapi dalam bahasa Indonesia (huruf kapital di awal).
- kcal_per_100g dan protein_per_100g: nilai untuk makanan dalam kondisi siap makan (sudah dimasak, sesuai cara penyajian yang paling umum, termasuk minyak goreng jika digoreng). Gunakan acuan seperti TKPI (Tabel Komposisi Pangan Indonesia), USDA, atau label gizi merek.
- unit_name, kcal_per_unit, protein_per_unit: isi hanya jika makanan ini biasanya dihitung per satuan (misal produk kemasan per "bungkus", menu restoran per "porsi", telur per "butir"). Jika tidak, isi null.
- assumption: satu kalimat singkat bahasa Indonesia tentang asumsi yang dipakai (cara masak, ukuran porsi, merek).
- Jika input bukan makanan atau minuman, set is_food=false dan isi angka dengan null.

Berikan perkiraan terbaikmu walau tidak pasti; user akan menimbang makanannya dalam gram.`;

let client;

export function isAiConfigured() {
  if (useGemini()) return true;
  // Abaikan nilai contoh dari .env.example ("sk-ant-...")
  const key = process.env.ANTHROPIC_API_KEY ?? '';
  return key.startsWith('sk-ant-') && !key.endsWith('...') && key.length > 30;
}

export class AiEstimateError extends Error {}

/** @returns {Promise<string>} teks JSON dari model */
async function askClaude(foodName) {
  client ??= new Anthropic();

  let response;
  try {
    response = await client.beta.messages.create({
      model: AI_MODEL,
      max_tokens: 4000,
      betas: ['server-side-fallback-2026-07-01'],
      fallbacks: 'default',
      output_config: { effort: 'low', format: { type: 'json_schema', schema: SCHEMA } },
      system: SYSTEM,
      messages: [{ role: 'user', content: foodName }],
    });
  } catch (err) {
    if (err instanceof Anthropic.RateLimitError) throw new AiEstimateError('AI sedang sibuk, coba lagi sebentar lagi');
    if (err instanceof Anthropic.AuthenticationError) throw new AiEstimateError('API key AI tidak valid');
    if (err instanceof Anthropic.APIConnectionError) throw new AiEstimateError('Tidak bisa terhubung ke layanan AI');
    throw err;
  }

  if (response.stop_reason === 'refusal') throw new AiEstimateError('AI tidak bisa memperkirakan makanan ini');
  if (response.stop_reason === 'max_tokens') throw new AiEstimateError('Jawaban AI terpotong, coba lagi');
  return response.content.find((b) => b.type === 'text')?.text;
}

/** @returns {Promise<string>} teks JSON dari model */
async function askGemini(foodName) {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(AI_MODEL)}:generateContent`;
  let res;
  try {
    res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': geminiKey() },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: SYSTEM }] },
        contents: [{ role: 'user', parts: [{ text: foodName }] }],
        generationConfig: {
          temperature: 0.2,
          responseMimeType: 'application/json',
          responseSchema: GEMINI_SCHEMA,
        },
      }),
      signal: AbortSignal.timeout(25000),
    });
  } catch (err) {
    if (err.name === 'TimeoutError') throw new AiEstimateError('AI terlalu lama menjawab, coba lagi');
    throw new AiEstimateError('Tidak bisa terhubung ke layanan AI');
  }

  const body = await res.json().catch(() => ({}));
  if (!res.ok) {
    const message = body.error?.message ?? `HTTP ${res.status}`;
    if (res.status === 429) throw new AiEstimateError('Kuota AI gratis sedang habis, coba lagi sebentar lagi');
    if (res.status === 400 && /api key/i.test(message)) throw new AiEstimateError('API key AI tidak valid');
    if (res.status === 403) throw new AiEstimateError('API key AI tidak valid atau tidak punya akses');
    if (res.status === 404) throw new AiEstimateError(`Model AI "${AI_MODEL}" tidak ditemukan`);
    throw new Error(`Gemini: ${message}`);
  }

  if (body.promptFeedback?.blockReason) throw new AiEstimateError('AI tidak bisa memperkirakan makanan ini');
  const candidate = body.candidates?.[0];
  if (candidate?.finishReason === 'MAX_TOKENS') throw new AiEstimateError('Jawaban AI terpotong, coba lagi');
  if (candidate?.finishReason && candidate.finishReason !== 'STOP') {
    throw new AiEstimateError('AI tidak bisa memperkirakan makanan ini');
  }
  return candidate?.content?.parts?.map((p) => p.text ?? '').join('');
}

/**
 * @param {string} foodName contoh: "bubur ayam", "rendang", "Indomie goreng"
 */
export async function estimateFood(foodName) {
  const text = useGemini() ? await askGemini(foodName) : await askClaude(foodName);
  let parsed;
  try {
    parsed = resultSchema.parse(JSON.parse(text ?? ''));
  } catch {
    throw new AiEstimateError('Jawaban AI tidak bisa dibaca, coba lagi');
  }

  if (!parsed.is_food) throw new AiEstimateError(`"${foodName}" sepertinya bukan makanan`);
  if (parsed.kcal_per_100g === null && parsed.kcal_per_unit === null) {
    throw new AiEstimateError('AI tidak menemukan nilai kalori untuk makanan ini');
  }
  // Satuan harus lengkap berdua, sama seperti aturan tabel foods.
  if (!parsed.unit_name || parsed.kcal_per_unit === null) {
    parsed.unit_name = null;
    parsed.kcal_per_unit = null;
    parsed.protein_per_unit = null;
  }

  const { is_food: _isFood, ...food } = parsed;
  return food;
}
