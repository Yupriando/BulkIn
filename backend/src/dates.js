// Semua "tanggal" di NaikIn mengikuti zona waktu user (default WIB, +07:00).

export const TZ_OFFSET = process.env.APP_TZ_OFFSET || '+07:00';

function offsetMinutes(offset = TZ_OFFSET) {
  const m = /^([+-])(\d{2}):(\d{2})$/.exec(offset);
  if (!m) throw new Error(`APP_TZ_OFFSET tidak valid: ${offset}`);
  const sign = m[1] === '-' ? -1 : 1;
  return sign * (Number(m[2]) * 60 + Number(m[3]));
}

/** Tanggal lokal (YYYY-MM-DD) dari sebuah timestamp. */
export function localDate(timestamp) {
  const shifted = new Date(new Date(timestamp).getTime() + offsetMinutes() * 60_000);
  return shifted.toISOString().slice(0, 10);
}

export const today = () => localDate(Date.now());

export function addDays(isoDate, days) {
  const d = new Date(`${isoDate}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

export function daysBetween(fromIso, toIso) {
  return Math.round((new Date(`${toIso}T00:00:00Z`) - new Date(`${fromIso}T00:00:00Z`)) / 86_400_000);
}

/** Awal & akhir hari lokal dalam bentuk timestamp, untuk filter kolom timestamptz. */
export const dayStart = (isoDate) => `${isoDate}T00:00:00${TZ_OFFSET}`;
export const dayEnd = (isoDate) => `${addDays(isoDate, 1)}T00:00:00${TZ_OFFSET}`;
